% Step 24 renters, the 20,000 test households (seed 202): the grid policies of
% the quick and the standard grid and the 1,000-step network, by age, and
% where their lifetime utility comes from. Lifetime utility is the Julia
% year's (neural/scripts/net_panel.jl), the bequest term included.
% Run from the repository root after the step-24 solves (keep_solve), the
% network's export and net_panel.jl on both test sets.
d = fullfile(pwd, 'neural', 'data');
rq = load(fullfile(d, 'solve_24_renter_quick.mat')).r;
rs = load(fullfile(d, 'solve_24_renter_standard.mat')).r;
net = load(fullfile(d, 'net_step24_renter_run1.mat'));
Jq = load(fullfile(d, 'netpanel_step24_renter_run1_24_renter_quick.mat'));
Js = load(fullfile(d, 'netpanel_step24_renter_run1_24_renter_standard.mat'));
N = 20000; seed = 202;
sq = simulate.paths_lna(rq.p, rq.profile, rq.sol, rq.ann_price, N, seed, rq.p.b0);
ss = simulate.paths_lna(rs.p, rs.profile, rs.sol, rs.ann_price, N, seed, rs.p.b0);
sol_n = struct('policy_fn', @(t, u1, u2, u3, q) neural.net_policy(net, rq.p, t, u1, u2, u3, q));
sn = simulate.paths_lna(rq.p, rq.profile, sol_n, rq.ann_price, N, seed, rq.p.b0);

% MATLAB's simulator with the network against the Julia year
Y0 = sn.Y(1, 1);
gap = @(a, b) max(abs(a(:) - b(:)) ./ max(abs(b(:)), Y0));
fprintf('network, MATLAB against Julia: C %.2e, X %.2e; defaulted MATLAB %d, Julia %d, disagreeing household-years %d\n', ...
    gap(sn.C, Jq.C), gap(sn.X, Jq.X), nnz(any(sn.absorbed, 2)), nnz(any(Jq.absorbed > 0.5, 2)), nnz(sn.absorbed ~= (Jq.absorbed > 0.5)));

g = rq.p.gamma;
ce = @(U, p) ((1 - g) * mean(U) / p.D_abs(1)) ^ (1 / (1 - g));
w = struct('grid_q', ce(Jq.U_grid, rq.p), 'grid_s', ce(Js.U_grid, rs.p), 'net', ce(Jq.U, rq.p));
fprintf('welfare: grid quick %.5f (value function %.4f), grid standard %.5f (value function %.4f), network %.5f\n', ...
    w.grid_q, rq.checks.ce_entry, w.grid_s, rs.checks.ce_entry, w.net);

runs = {sprintf('grid policy, quick grid: welfare %.4f (its value function %.3f)', w.grid_q, rq.checks.ce_entry), neural.panel_profiles(sq, rq.p), 'grid_std';
        sprintf('grid policy, standard grid: welfare %.4f (its value function %.3f)', w.grid_s, rs.checks.ce_entry), neural.panel_profiles(ss, rs.p), 'grid_fine';
        sprintf('network, 1,000 steps: welfare %.4f', w.net), neural.panel_profiles(sn, rq.p), 'net1'};
neural.plot_lifecycles(runs, title='Step 24 renters (default as a choice, bequest at b = 2), 20,000 test households', ...
    file='step24_renter_lifecycles.png');

% Where lifetime utility comes from: the share of the total in the k worst households
fig = figure('Color', [252 252 251] / 255, 'Position', [100 100 1100 560], 'Visible', 'off');
ax = axes(fig); hold(ax, 'on');
cols = {[0.55 0.55 0.55], [0.05 0.05 0.05], [42 120 214] / 255};
sty = {'--', '-', '-'};
Us = {Jq.U_grid, Js.U_grid, Jq.U};
lab = {'grid policy, quick grid', 'grid policy, standard grid', 'network, 1,000 steps'};
k = unique(round(logspace(0, log10(N), 200)));
for i = 1:3
    u = sort(Us{i}(:));
    sh = cumsum(u) / sum(u);
    plot(ax, k, sh(k), sty{i}, 'Color', cols{i}, 'LineWidth', 1.8, 'DisplayName', ...
        sprintf('%s: worst 10 households %.2f%% of the total', lab{i}, 100 * sh(10)));
end
xline(ax, 10, ':', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off');
set(ax, 'XScale', 'log', 'XLim', [1 N], 'YLim', [0 1.02], 'FontSize', 10, 'XGrid', 'on', 'YGrid', 'on', ...
    'GridColor', [0.88 0.88 0.87], 'GridAlpha', 1, 'Box', 'off');
xlabel(ax, 'the k households with the lowest lifetime utility (of 20,000)');
ylabel(ax, 'share of total lifetime utility');
title(ax, 'Step 24 renters: how much of mean lifetime utility the worst households carry', 'FontWeight', 'normal');
legend(ax, 'Location', 'southeast', 'Box', 'off', 'FontSize', 10);
exportgraphics(fig, fullfile(d, 'figures', 'step24_renter_tail.png'), 'Resolution', 140);
