function out = decompose_gap(r, opts)
%DECOMPOSE_GAP  Where the solver's value and the simulated welfare part, by age.
%
%   out = decompose_gap(r)                       % r = model.run output with r.sol
%   out = decompose_gap(r, N=100000, seed=303, n_rest=5000)
%
%   Simulates r's grid policy (simulate.paths_lna) and follows each household.
%   V_int(t) is the solver's value at its state, interpolated in z as the
%   solver does (the default or bankrupt value u(F) D_beq(t) once bankrupt).
%   B(t) = u_t + beta p_t V_int(t+1) is what the year realises plus the
%   solver's value of where it lands (with chi > 0, the bequest term too).
%   Summed with discounting and survival, V_int(t) - B(t) telescopes: its sum
%   over the years from entry is V_int(1) minus the realised lifetime utility,
%   household by household. Each year's gap splits in three, with the point
%   solves of point_solve at the household's own state against the same V_next:
%     interp  V_int(t) - V_opt(t)   the value between nodes against the
%                                   Bellman problem solved at the state
%     policy  V_opt(t) - V_pol(t)   the optimum at the state against the
%                                   interpolated grid policy for one year
%                                   (with default as a choice, also the
%                                   simulator's default decision)
%     quad    V_pol(t) - B(t)       the quadrature's expectation against the
%                                   draw the household got: zero in mean but
%                                   for sampling, unless the quadrature misses
%                                   something the draws find
%   The households who ever go bankrupt (default) are all kept; n_rest of the
%   others are drawn at random and reweighted, so the means are those of the
%   whole panel. Utility is in units of entry income (C / Y0), as
%   neural.sim_utility.
%
%   out.by_age: per age, the weighted mean discounted contribution of each
%   part (utility units at entry), for all and for the ever bankrupt.
%   out.total: V_int(1) and the realised utility, as certainty equivalents.

arguments
    r struct
    opts.N (1,1) double = 100000
    opts.seed (1,1) double = 303
    opts.n_rest (1,1) double = 5000
    opts.sample_seed (1,1) double = 1
    opts.ages double = []                  % empty: every age
end
p = r.p; sol = r.sol; g = p.gamma; T = p.T;
[~, shocks] = config.model_inputs(p); r.shocks = shocks;
sim = simulate.paths_lna(p, r.profile, sol, r.ann_price, opts.N, opts.seed, p.b0);
N = opts.N; Y0 = sim.Y(1, 1);
u = @(x) (x / Y0) .^ (1 - g) / (1 - g);
ps = r.profile.p_surv(:);
ab = sim.absorbed;
ever = any(ab, 2);
t_ab = T - sum(ab, 2) + 1;  t_ab(~ever) = T + 1;           % first bankrupt year
Cbar = zeros(N, 1); Cbar(ever) = sim.C(sub2ind([N T], find(ever), t_ab(ever)));
hb = p.is_owner * (1 - p.sell_cost);

% Realised utility of each year (solvent), with the bequest term
rt = u(sim.C);
if p.chi > 0
    for t = 1:T
        if t < T, b = sim.X(:, t + 1) + hb * sim.H(:, t + 1); else, b = sim.bequest; end
        b = max(b, 1e-12 * sim.W(:, t));
        rt(:, t) = rt(:, t) + p.beta * (1 - ps(t)) * p.chi * u(b);
    end
end

% The sample: every ever-bankrupt household, n_rest of the others
rng(opts.sample_seed);
kn = find(~ever); kn = kn(randperm(numel(kn), min(opts.n_rest, numel(kn))));
idx = [find(ever); kn];
wt  = [ones(sum(ever), 1); sum(~ever) / numel(kn) * ones(numel(kn), 1)] / N;
ns = numel(idx);

% The solver's value at the states, interpolated in z
Vint = zeros(ns, T); Vopt = zeros(ns, T); Vpol = zeros(ns, T);
gpol = neural.grid_policy_fn(r);
q_grid = p.q_grid(:);
choice = p.floor_absorbing && isfield(p, 'default_choice') && p.default_choice;
ages = opts.ages; if isempty(ages), ages = 1:T; end
sec = zeros(T, 1);
for t = 1:T
    [g1, g2] = utility.grid_at(p, t);
    lam = sim.lambda(idx, t); sA = sim.sA(idx, t); sH = sim.sH(idx, t); qq = sim.q(idx, t);
    sAH = sA + sH; u2 = sAH ./ max(1 - lam, 1e-12); u3 = min(max(sA ./ max(sAH, 1e-12), 0), 1);
    if isfield(p, 'u2_coord') && strcmp(p.u2_coord, 'edge')
        u2 = u2 ./ utility.u2_max(p, t, lam, u3, qq, r.ann_price);   % the grid's v
    end
    % V_int is the value the solver's continuation gives the state: the
    % bankrupt value where the state is bankrupt (forced rule) or has no
    % resources (default as a choice), else the interpolant, and with default
    % as a choice never below the default value (bankrupt_nodes).
    Vint(:, t) = (sim.W(idx, t) / Y0 .* zlook(sol.V(:, :, :, :, t), g, g1, g2, p.u3_grid, q_grid, lam, u2, u3, qq)) .^ (1 - g) / (1 - g);
    before = ab(idx, t) & t_ab(idx) < t;                  % bankrupt in an earlier year
    enter  = t_ab(idx) == t;
    vdef   = u(p.phi_path(t) * sim.Y(idx, t)) * p.D_beq(t);
    if choice
        noRes = sim.LW(idx, t) <= max(p.phi_floor * sim.Y(idx, t), 1e-12 * sim.W(idx, t));
        Vint(:, t) = max(Vint(:, t), vdef);
        Vint(noRes, t) = vdef(noRes);
        live = ~before & ~noRes;
    else
        Vint(enter, t) = vdef(enter);
        live = ~ab(idx, t);
    end
    Vint(before, t) = u(Cbar(idx(before))) * p.D_beq(t);
    if ~ismember(t, ages), Vopt(:, t) = NaN; Vpol(:, t) = NaN; continue, end
    t0 = tic;
    sc = (sim.W(idx(live), t) / Y0) .^ (1 - g);           % per unit of W^(1-g) to entry-income units
    vo = point_solve(r, t, lam(live), sA(live), sH(live), qq(live), ...
        seed_c = sim.c_frac(idx(live), t), seed_pi = sim.pi(idx(live), t));
    [vp, ~, ~, vcp] = point_solve(r, t, lam(live), sA(live), sH(live), qq(live), fixed = gpol);
    Vopt(:, t) = Vint(:, t); Vpol(:, t) = Vint(:, t);
    Vopt(live, t) = vo .* sc;
    if choice
        % the simulator continued with the grid policy, or defaulted
        Vpol(live, t) = vcp .* sc;
        Vpol(enter, t) = vdef(enter);
    else
        Vpol(live, t) = vp .* sc;
    end
    sec(t) = toc(t0);
    if mod(t, 10) == 1, fprintf('  t=%d (age %d): %d states, %.1f s\n', t, p.age0 + t - 1, sum(live), sec(t)); end
end

% B(t) and the discounted parts
disc = ones(1, T); for t = 2:T, disc(t) = disc(t - 1) * p.beta * ps(t - 1); end
B = zeros(ns, T);
for t = 1:T
    if t < T, B(:, t) = rt(idx, t) + p.beta * ps(t) * Vint(:, t + 1); else, B(:, t) = rt(idx, t); end
    bk = ab(idx, t); B(bk, t) = u(Cbar(idx(bk))) * p.D_beq(t);   % the bankrupt value, realised
end
% A household bankrupt from t_ab on realises the bankrupt value there; the
% years before telescope to it, so its realised utility at entry is the sum
% of rt before t_ab plus that value. After t_ab, V_int = B and nothing is added.
D = (Vint - B) .* disc;
Di = (Vint - Vopt) .* disc; Dp = (Vopt - Vpol) .* disc; Dq = (Vpol - B) .* disc;
R1 = sum(D, 2);                                            % V_int(1) - realised, by household
realised = Vint(:, 1) - R1;
% The same realised utility summed directly, as a check of the telescoping
direct = zeros(ns, 1);
for t = 1:T
    s = t < t_ab(idx); direct(s) = direct(s) + disc(t) * rt(idx(s), t);
    e = t_ab(idx) == t; direct(e) = direct(e) + disc(t) * u(Cbar(idx(e))) * p.D_beq(t);
end
fprintf('telescoping check: max |realised - direct| / mean |direct| = %.3g\n', max(abs(realised - direct)) / mean(abs(direct)));
ce = @(v) ((1 - g) * v / p.D_abs(1)) ^ (1 / (1 - g));
eb = ever(idx);
out = struct();
out.total = struct('ce_Vint', ce(sum(wt .* Vint(:, 1))), 'ce_realised', ce(sum(wt .* realised)), ...
    'EU_Vint', sum(wt .* Vint(:, 1)), 'EU_realised', sum(wt .* realised), 'share_ever', mean(ever), ...
    'n_sample', ns, 'ce_entry', r.checks.ce_entry);
[~, ce_sim] = neural_sim_utility_safe(p, r.profile, sim);
out.total.ce_sim_utility = ce_sim;
nanz = @(x) sum(x, 'omitnan');
out.by_age = table((p.age0:p.age0 + T - 1).', ...
    nanz(wt .* D).', nanz(wt .* Di).', nanz(wt .* Dp).', nanz(wt .* Dq).', ...
    nanz(wt(eb) .* D(eb, :)).', nanz(wt(eb) .* Di(eb, :)).', nanz(wt(eb) .* Dp(eb, :)).', nanz(wt(eb) .* Dq(eb, :)).', sec, ...
    'VariableNames', {'age', 'gap', 'interp', 'policy', 'quad', 'gap_bk', 'interp_bk', 'policy_bk', 'quad_bk', 'sec'});
out.sum = varfun(@(x) sum(x, 'omitnan'), out.by_age(:, 2:9));
out.idx = idx; out.wt = wt; out.ever = eb; out.t_ab = t_ab(idx);
out.Vint = Vint; out.Vopt = Vopt; out.Vpol = Vpol; out.B = B;
out.c_opt_note = 'Vopt seeded by the simulated policy at the state';
fprintf('ce: V_int at entry %.4f (ce_entry %.4f), realised %.4f (sim_utility %.4f); ever bankrupt %.4f\n', ...
    out.total.ce_Vint, r.checks.ce_entry, out.total.ce_realised, ce_sim, mean(ever));
s = out.sum{1, :};
fprintf('utility gap %.4g = interp %.4g + policy %.4g + quad %.4g; of which ever bankrupt %.4g = %.4g + %.4g + %.4g\n', s);
end

function z = zlook(V, g, g1, g2, g3, q_grid, u1, u2, u3, q)
z = zeros(size(V)); m = isfinite(V); z(m) = ((1 - g) * V(m)) .^ (1 / (1 - g));
if numel(q_grid) > 1
    F = griddedInterpolant({g1, g2, g3, q_grid}, z, 'linear', 'nearest');
    z = F(u1, u2, u3, q);
else
    F = griddedInterpolant({g1, g2, g3}, z(:, :, :, 1), 'linear', 'nearest');
    z = F(u1, u2, u3);
end
end

function [U, ce] = neural_sim_utility_safe(p, profile, sim)
% neural.sim_utility refuses chi > 0; then NaN (the realised sum above covers it).
U = []; ce = NaN;
if p.chi <= 0, [U, ce] = neural.sim_utility(p, profile, sim); end
end
