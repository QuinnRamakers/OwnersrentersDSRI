function F = pi_flatness(rung, ages_want, opts)
%PI_FLATNESS  What does choosing pi badly actually cost, by age?
%
%   F = pi_flatness(rung)
%   F = pi_flatness(rung, ages_want, opts)
%
%   Roughness statistics say pi MOVES; they cannot say whether the movement
%   matters. Nor can the size of the balance being allocated -- a small stake
%   can still carry a real cost if the premium is large. The decisive quantity
%   is the certainty-equivalent loss from choosing pi badly at a given age:
%
%       CE loss = 1 - CE(V at the worst pi) / CE(V at the best pi)
%
%   with CE = ((1-gamma) V)^(1/(1-gamma)). If that number is a rounding error,
%   the household is indifferent and a jagged pi is the model reporting an
%   indeterminate choice, not a solver failure. If it is material, jaggedness
%   is a real problem.
%
%   The Bellman right-hand side is rebuilt here rather than read off the
%   solution, so it is validated first: the reconstructed maximum must
%   reproduce the solver's stored V, c* and pi* at the same node. The
%   validation columns are printed and should be checked before the CE numbers
%   are believed.
%
%   Reports the stake in YEARS OF CONTEMPORANEOUS INCOME, not in currency.
%   The 'poly' income source carries an arbitrary level (its constant differs
%   from CGM's Table 2 by a factor of ~15, and the repo rescales again), so
%   absolute amounts are not comparable across rungs and are not euros.

if nargin < 2 || isempty(ages_want), ages_want = [35 50 66 70 80 90 95 98]; end
if nargin < 3 || isempty(opts), opts = struct(); end
if ~isfield(opts, 'dims'),  opts.dims  = [16 12 10]; end
if ~isfield(opts, 'gh_n'),  opts.gh_n  = 5; end
if ~isfield(opts, 'N_sim'), opts.N_sim = 4000; end
if ~isfield(opts, 'seed'),  opts.seed  = 12345; end

here = fileparts(mfilename('fullpath'));
addpath(fileparts(here), here);
cd(fileparts(here));

[p, meta] = ablation_config(rung, rmfield_if(opts, {'N_sim', 'seed', 'XY'}));
[~, mg, sl] = config.income_profile(p);
profile = struct('mu_growth', mg, 'sigma_l_log', sl, 'p_surv', config.survival(p));
sh  = grids.shock_grid(p);
ap  = pension.annuity_price(p, profile, sh);
sol = solver.solve(p, profile, sh, ap);
sim = simulate.forward(p, profile, sol, ap, opts.N_sim, opts.seed, p.b0);

gamma = p.gamma; omg = 1 - gamma;
R_S = sh.joint.R_S(:); R_H = sh.joint.R_H(:); R_RE = sh.joint.R_REIT(:);
epsY = sh.joint.eps_Y_unit(:); w = sh.joint.w(:);
net  = 1 - p.tau_inc;
Rf_at  = (1 + p.r * (1 - p.tau_cg_bond)) * (1 - p.tau_wealth);
R_S_at = config.after_tax_stock(p, R_S);
tauP = config.tau_effective(p); reP = config.reit_effective(p);

fprintf('\n=== pi flatness, rung %d (%s), grid [%d %d %d] ===\n', ...
    meta.level, meta.name, meta.dims);
fprintf('%5s %7s %9s %9s | %9s %9s | %9s %9s\n', ...
    'age', 'stake_y', 'pi*_solv', 'pi*_recon', 'V_solver', 'V_recon', 'CEloss_%', 'pi_range');
fprintf('%s\n', repmat('-', 1, 92));

F = struct([]);
for k = 1:numel(ages_want)
    t = ages_want(k) - p.age0 + 1;
    if t < 1 || t >= p.T, continue; end

    % Which state to interrogate. By default the median simulated household at
    % this age; opts.XY pins a liquid-wealth-to-income ratio instead, which is
    % how to reach a corner of the state space the median has already left.
    if isfield(opts, 'XY') && ~isempty(opts.XY)
        lam = 1 / (1 + opts.XY); sA = 0; sH = 0;
    else
        lam = median(sim.lambda(:, t)); sA = median(sim.sA(:, t)); sH = median(sim.sH(:, t));
    end
    u1 = lam;
    denAH = sA + sH;
    u2 = denAH / max(1 - lam, 1e-12);
    u3 = sA / max(denAH, 1e-12);
    [~, i1] = min(abs(p.u1_grid - u1));
    [~, i2] = min(abs(p.u2_grid - min(max(u2, 0), 1)));
    [~, i3] = min(abs(p.u3_grid - min(max(u3, 0), 1)));
    u1 = p.u1_grid(i1); u2 = p.u2_grid(i2); u3 = p.u3_grid(i3);
    lam = u1; sA = u2 * (1 - u1) * u3; sH = u2 * (1 - u1) * (1 - u3);
    sX = 1 - lam - sA - sH;

    is_ret = t >= p.t_ret;
    kap = p.kappa(min(t, numel(p.kappa)));
    if p.is_owner
        mr = 0; if t <= numel(p.m_rate_path), mr = p.m_rate_path(t); end
        hcr = p.theta + mr;
    else
        hcr = p.alpha;
    end
    pt = profile.p_surv(t); beta_eff = p.beta * pt;
    if is_ret
        cf = (1 - p.delta) * net;
        LW = sX + cf * lam + net * sA / ap(t) - hcr * sH;
        Apre = sA * (1 - 1 / ap(t));
    else
        cf = (1 - p.delta) * (1 - kap) * net;
        LW = sX + cf * lam - hcr * sH;
        Apre = sA + kap * lam;
    end
    if LW <= 0, continue; end

    G = exp(profile.mu_growth(t) + profile.sigma_l_log(t) .* epsY);
    Ynext = G * lam; Hnext = sH * R_H;
    R_A = ((1 - tauP(t) - reP(t)) * p.Rf + tauP(t) .* R_S + reP(t) .* R_RE) / pt;
    Anext = R_A * Apre;

    Vn = sol.V(:,:,:,t+1); arg = omg * Vn; arg(arg <= 0) = NaN;
    z = arg .^ (1/omg);
    z(isnan(z)) = min(z(isfinite(z)));
    ppz = griddedInterpolant({p.u1_grid, p.u2_grid, p.u3_grid}, z, 'linear', 'nearest');

    rhs = @(c, pig) rhs_val(c, pig, LW, Rf_at, R_S_at, Anext, Hnext, Ynext, ...
                            ppz, w, omg, beta_eff);

    cg = linspace(max(1e-4, 1e-3), 1 - 1e-6, 200);
    pg = linspace(0, 1, 201);
    M = nan(numel(cg), numel(pg));
    for a = 1:numel(cg)
        for b = 1:numel(pg)
            M(a, b) = rhs(cg(a), pg(b));
        end
    end
    [Vmax, li] = max(M(:)); [ia, ib] = ind2sub(size(M), li);

    % At the reconstructed optimal c, how much does pi matter?
    slice = M(ia, :);
    Vbest = max(slice); Vworst = min(slice);
    ce_loss = 100 * (1 - ce(Vworst, omg) / ce(Vbest, omg));

    % Range of pi within 0.01% CE of the best: the indeterminacy band.
    tol = 1e-4;
    ok = (1 - ce(slice, omg) ./ ce(Vbest, omg)) < tol;
    band = [min(pg(ok)), max(pg(ok))];

    stake_y = mean(max(sim.X(:, t), 0) .* (1 - sim.c_frac(:, t))) / mean(sim.Y(:, t));

    fprintf('%5d %7.2f %9.3f %9.3f | %9.4g %9.4g | %9.4f  [%.2f %.2f]\n', ...
        ages_want(k), stake_y, sol.pi_pol(i1,i2,i3,t), pg(ib), ...
        sol.V(i1,i2,i3,t), Vmax, ce_loss, band(1), band(2));

    e = struct('age', ages_want(k), 'stake_y', stake_y, ...
               'pi_solver', sol.pi_pol(i1,i2,i3,t), 'pi_recon', pg(ib), ...
               'V_solver', sol.V(i1,i2,i3,t), 'V_recon', Vmax, ...
               'ce_loss_pct', ce_loss, 'band', band, 'pi_grid', pg, 'slice', slice);
    if isempty(F), F = e; else, F(end+1) = e; end %#ok<AGROW>
end

fprintf(['\nCEloss_%% = cost of the WORST pi vs the best, at the optimal c.\n' ...
         'pi_range = every pi within 0.01%% CE of the best: the indeterminacy band.\n' ...
         'Check pi*_solv vs pi*_recon and V_solver vs V_recon first -- if those\n' ...
         'disagree the reconstruction is wrong and the CE numbers mean nothing.\n']);
end

% =============================================================================
function v = rhs_val(c, pig, LW, Rf_at, R_S_at, Anext, Hnext, Ynext, ppz, w, omg, beta_eff)
RX = (1 - pig) * Rf_at + pig .* R_S_at;
Xn = RX * ((1 - c) * LW);
denAH = Anext + Hnext;
Wg = Xn + denAH + Ynext;
u1n = max(min(Ynext ./ Wg, 1), 0);
u2n = max(min(denAH ./ max(Xn + denAH, 1e-12), 1), 0);
u3n = max(min(Anext ./ max(denAH, 1e-12), 1), 0);
zn = ppz(u1n, u2n, u3n);
Vv = (Wg .* zn) .^ omg / omg;
v = (c * LW)^omg / omg + beta_eff * sum(w .* Vv);
end

function x = ce(V, omg)
% Certainty equivalent of a CRRA value. omg = 1 - gamma < 0 for gamma > 1, so
% V < 0 and (omg*V) > 0.
x = (omg .* V) .^ (1 / omg);
end

function s = rmfield_if(s, f)
for k = 1:numel(f)
    if isfield(s, f{k}), s = rmfield(s, f{k}); end
end
end
