function L = late_life_check(opts)
%LATE_LIFE_CHECK  Diagnose the late-life dip in the CGM core against theory.
%
%   L = late_life_check()
%
%   The simulated mean equity share of ablation rung 0 dips around age 94 and
%   its 5th percentile collapses to near zero, neither of which appears in CGM
%   (2005) Figure 3C, where the retirement rise is smooth and monotone to 97.
%   This isolates the cause by putting three numbers side by side at each late
%   age and wealth level:
%
%     pi_solver   what the solver stored at that node
%     pi_recon    the argmax of the Bellman right-hand side rebuilt here
%     pi_merton   CGM Equation (12): the share of TOTAL wealth in equity is
%                 mu/(gamma sigma^2), so with financial wealth X and human
%                 capital PDV,
%                     pi = min(1, [mu/(gamma sigma^2)] (X + PDV) / X).
%
%   Equation (12) is exact when labour income is constant and riskless. Rung 0
%   in retirement is exactly that case -- config.income_profile zeroes the
%   income shock from t_ret-1 onward -- so it is a genuine analytic benchmark
%   here, not an approximation, up to the discrete-time and mortality terms
%   carried in PDV.
%
%   Reading the result:
%     recon == solver, both != merton  -> the model's answer really is this;
%                                         the discrepancy is economics to explain.
%     recon != solver                  -> the optimiser is not finding its own
%                                         argmax: a solver defect.

if nargin < 1 || isempty(opts), opts = struct(); end
if ~isfield(opts, 'dims'),  opts.dims  = [30 10 8]; end
if ~isfield(opts, 'gh_n'),  opts.gh_n  = 5; end
if ~isfield(opts, 'ages'),  opts.ages  = [85 90 92 94 96 98 99]; end
if ~isfield(opts, 'XY'),    opts.XY    = [0.5 1 2 5 10]; end

here = fileparts(mfilename('fullpath'));
addpath(fileparts(here), here);
cd(fileparts(here));
if isempty(gcp('nocreate'))
    try, parpool('Threads'); catch, warning('late_life_check:pool', 'no pool'); end
end

[p, meta] = ablation_config(0, struct('dims', opts.dims, 'gh_n', opts.gh_n));
[~, mg, sl] = config.income_profile(p);
profile = struct('mu_growth', mg, 'sigma_l_log', sl, 'p_surv', config.survival(p));
sh  = grids.shock_grid(p);
ap  = pension.annuity_price(p, profile, sh);
sol = solver.solve(p, profile, sh, ap);

gamma = p.gamma; omg = 1 - gamma;
R_S = sh.joint.R_S(:);
epsY = sh.joint.eps_Y_unit(:); w = sh.joint.w(:);
net = 1 - p.tau_inc;
Rf_at  = (1 + p.r * (1 - p.tau_cg_bond)) * (1 - p.tau_wealth);
R_S_at = config.after_tax_stock(p, R_S);
merton = p.mu_S_level / (p.gamma * p.sigma_S_level^2);

% PDV of future income in years of current income, with survival and the
% riskless discount. Retirement income is flat at rung 0, so this is a pure
% annuity factor over remaining life.
Ylev = exp(config.income_profile(p));
pdv = zeros(p.T, 1);
for t = 1:p.T
    s = 1; acc = 0;
    for k = 1:(p.T - t)
        s = s * profile.p_surv(t + k - 1);
        acc = acc + s * Ylev(t + k) / (p.Rf^k);
    end
    pdv(t) = acc / Ylev(t);          % in years of CURRENT income
end

fprintf('\n=== late-life check, rung 0, grid [%d %d %d], gamma=%g, Merton=%.4f ===\n', ...
    meta.dims, p.gamma, merton);
fprintf('%5s %6s %8s | %9s %9s %9s | %8s\n', ...
    'age', 'X/Y', 'PDV/Y', 'pi_solver', 'pi_recon', 'pi_merton', 'CEloss_%');
fprintf('%s\n', repmat('-', 1, 74));

L = struct([]);
for ia = 1:numel(opts.ages)
    t = opts.ages(ia) - p.age0 + 1;
    if t < 1 || t >= p.T, continue; end
    for ix = 1:numel(opts.XY)
        XY = opts.XY(ix);
        lam = 1 / (1 + XY);
        [~, i1] = min(abs(p.u1_grid - lam));
        lam_n = p.u1_grid(i1);
        sX = 1 - lam_n;                       % A = H = 0 at rung 0

        is_ret = t >= p.t_ret;
        kap = p.kappa(min(t, numel(p.kappa)));
        pt = profile.p_surv(t); beta_eff = p.beta * pt;
        if is_ret
            LW = sX + (1 - p.delta) * net * lam_n;
        else
            LW = sX + (1 - p.delta) * (1 - kap) * net * lam_n;
        end
        if LW <= 0, continue; end

        % A = H = 0 for life at rung 0, so the next state has only X and Y.
        G = exp(profile.mu_growth(t) + profile.sigma_l_log(t) .* epsY);
        Ynext = G * lam_n;

        Vn = sol.V(:,:,:,t+1); arg = omg * Vn; arg(arg <= 0) = NaN;
        z = arg .^ (1/omg); z(isnan(z)) = min(z(isfinite(z)));
        ppz = griddedInterpolant({p.u1_grid, p.u2_grid, p.u3_grid}, z, 'linear', 'nearest');

        cg = linspace(1e-3, 1 - 1e-6, 160); pg = linspace(0, 1, 201);
        M = nan(numel(cg), numel(pg));
        for a = 1:numel(cg)
            for b = 1:numel(pg)
                RX = (1 - pg(b)) * Rf_at + pg(b) .* R_S_at;
                Xn = RX * ((1 - cg(a)) * LW);
                Wg = Xn + Ynext;
                u1n = max(min(Ynext ./ Wg, 1), 0);
                u2n = zeros(size(Wg)); u3n = zeros(size(Wg));
                zn = ppz(u1n, u2n, u3n);
                M(a, b) = (cg(a) * LW)^omg / omg + beta_eff * sum(w .* ((Wg .* zn) .^ omg / omg));
            end
        end
        [~, li] = max(M(:)); [ia_c, ib_p] = ind2sub(size(M), li);
        slice = M(ia_c, :);
        ceb = (omg * max(slice))^(1/omg);
        cew = (omg * min(slice))^(1/omg);
        ce_loss = 100 * (1 - cew / ceb);

        pim = min(1, merton * (XY + pdv(t)) / XY);

        fprintf('%5d %6.1f %8.2f | %9.3f %9.3f %9.3f | %8.3f\n', ...
            opts.ages(ia), XY, pdv(t), sol.pi_pol(i1,1,1,t), pg(ib_p), pim, ce_loss);

        e = struct('age', opts.ages(ia), 'XY', XY, 'pdv', pdv(t), ...
                   'pi_solver', sol.pi_pol(i1,1,1,t), 'pi_recon', pg(ib_p), ...
                   'pi_merton', pim, 'ce_loss', ce_loss);
        if isempty(L), L = e; else, L(end+1) = e; end %#ok<AGROW>
    end
    fprintf('\n');
end

d = abs([L.pi_solver] - [L.pi_recon]);
fprintf(['max |pi_solver - pi_recon| = %.4f\n' ...
         'If that is small the solver is finding its own argmax and any gap to\n' ...
         'pi_merton is the model, not the optimiser.\n'], max(d));
save(fullfile(here, 'late_life_check.mat'), 'L', 'opts', '-v7.3');
end
