function out = tail_states(r, opts)
%TAIL_STATES  The solvent years of very low consumption, and what the solver
%   would have done there.
%
%   out = tail_states(r)                      % r = model.run output with r.sol
%   out = tail_states(r, N=20000, seed=303, cut=0.05)
%
%   With default as a choice and phi_floor near zero, a household that keeps
%   going with almost no resources consumes almost nothing, and with gamma = 5
%   one such year can outweigh the rest of the panel. This simulates r's grid
%   policy, takes every solvent year with C / Y below cut, and solves the
%   Bellman problem at that state (point_solve, against the solver's V_next):
%   does the exact problem default there (V_cont at the state no more than
%   the default value), and what share of all realised utility do these years
%   hold? The simulator's own rule (V_cont interpolated in z) continued in
%   every such year, by construction.
%
%   out.T: one row per flagged year (age, resources / Y, the consumption
%   share, C / Y, the wealth carried on / Y, the year's realised utility as a
%   panel mean, the exact continuation and default values as certainty
%   equivalents per unit of W, and the exact decision). out.share: the
%   flagged years' share of the panel's realised utility (realised_utility),
%   their bequest terms included.

arguments
    r struct
    opts.N (1,1) double = 20000
    opts.seed (1,1) double = 303
    opts.cut (1,1) double = 0.05
end
p = r.p; g = p.gamma; T = p.T;
assert(p.floor_absorbing && p.default_choice, 'tail_states:choice', 'needs default as a choice.');
[~, r.shocks] = config.model_inputs(p);
sim = simulate.paths_lna(p, r.profile, r.sol, r.ann_price, opts.N, opts.seed, p.b0);
Y0 = sim.Y(1, 1);
ps = r.profile.p_surv(:);
disc = ones(1, T); for tt = 2:T, disc(tt) = disc(tt - 1) * p.beta * ps(tt - 1); end
uf = @(x) (x / Y0) .^ (1 - g) / (1 - g);
% each solvent year's realised utility as realised_utility counts it:
% consumption and, with chi > 0, the bequest term of what is carried on
hb = p.is_owner * (1 - p.sell_cost);
rt = nan(opts.N, T); b = nan(opts.N, T);
for tt = 1:T
    if tt < T, b(:, tt) = sim.X(:, tt + 1) + hb * sim.H(:, tt + 1); else, b(:, tt) = sim.bequest; end
    b(:, tt) = max(b(:, tt), 1e-12 * sim.W(:, tt));
    rt(:, tt) = uf(sim.C(:, tt));
    if p.chi > 0, rt(:, tt) = rt(:, tt) + p.beta * (1 - ps(tt)) * p.chi * uf(b(:, tt)); end
end
solvent = ~sim.absorbed;
U = realised_utility(p, r.profile, sim);
flag = solvent & sim.C ./ sim.Y < opts.cut;
D = repmat(disc, opts.N, 1);
share = sum(rt(flag) .* D(flag)) / sum(U);
[i, t] = find(flag);
rows = cell(0, 10);
ce = @(v) ((1 - g) * v) .^ (1 / (1 - g));
for tt = unique(t).'
    k = i(t == tt);
    lam = sim.lambda(k, tt); sA = sim.sA(k, tt); sH = sim.sH(k, tt); q = sim.q(k, tt);
    [~, ~, ~, Vc] = point_solve(r, tt, lam, sA, sH, q);
    vdef = (p.phi_path(tt) * lam) .^ (1 - g) / (1 - g) * p.D_beq(tt);
    for j = 1:numel(k)
        rows(end + 1, :) = {p.age0 + tt - 1, sim.LW(k(j), tt) / sim.Y(k(j), tt), sim.c_frac(k(j), tt), ...
            sim.C(k(j), tt) / sim.Y(k(j), tt), b(k(j), tt) / sim.Y(k(j), tt), rt(k(j), tt) * disc(tt) / opts.N, ...
            ce(Vc(j)), ce(vdef(j)), Vc(j) <= vdef(j), k(j)}; %#ok<AGROW>
    end
end
out.T = cell2table(rows, 'VariableNames', {'age', 'LW_Y', 'c_frac', 'C_Y', 'b_Y', 'u_contrib', 'ce_cont', 'ce_default', 'exact_defaults', 'hh'});
out.share = share; out.U_mean = mean(U);
out.n_years = sum(flag(:)); out.n_hh = numel(unique(i));
ten = 'renter'; if p.is_owner, ten = 'owner'; end
fprintf('tail_states %s_%s: %d solvent years with C/Y < %.3g in %d of %d households; they hold %.4f of realised utility (bequest term included)\n', ...
    num2str(p.ladder.number), ten, out.n_years, opts.cut, out.n_hh, opts.N, share);
if out.n_years > 0
    fprintf('  exact problem defaults in %d of them (%.1f%%); median age %g, median LW/Y %.4g, min C/Y %.3g\n', ...
        sum(out.T.exact_defaults), 100 * mean(out.T.exact_defaults), median(out.T.age), median(out.T.LW_Y), min(out.T.C_Y));
    [~, o] = sort(out.T.u_contrib);
    disp(out.T(o(1:min(15, end)), :));
end
end
