function plot_cgm_policy(opts)
%PLOT_CGM_POLICY  Policy functions of the CGM core (ablation rung 0).
%
%   plot_cgm_policy()
%
%   Rung 0 has no DC balance and no housing, so A = H = 0 for life and the cube
%   collapses to its first axis: the state is just lambda = Y/W. That makes the
%   policy a clean one-dimensional function of wealth at each age, which is the
%   form CGM plot in their Figure 2. The grid is therefore sized to put the
%   resolution on lambda and almost none on the two degenerate axes.
%
%   Plotted against LIQUID WEALTH IN YEARS OF INCOME, X/Y = (1-lambda)/lambda,
%   rather than lambda, so the axis has the same meaning as CGM's cash-on-hand:
%   0 is a household with nothing but its income, larger is wealthier.
%
%   What to look for, from CGM section 4.1:
%     - the share is pinned at 1 for the poor, because labour income is an
%       implicit bond holding that dominates a small financial portfolio;
%     - it falls as wealth rises, since the portfolio outgrows that implicit
%       bond;
%     - the whole rule shifts down with age through working life as human
%       capital is used up, then shifts back in during retirement.

if nargin < 1 || isempty(opts), opts = struct(); end
if ~isfield(opts, 'dims'), opts.dims = [40 8 6]; end   % resolution on lambda
if ~isfield(opts, 'gh_n'), opts.gh_n = 5; end
if ~isfield(opts, 'ages'), opts.ages = [25 35 45 55 66 70 80 90]; end

here = fileparts(mfilename('fullpath'));
addpath(fileparts(here), here);
cd(fileparts(here));
if isempty(gcp('nocreate'))
    try, parpool('Threads'); catch, warning('plot_cgm_policy:pool', 'no pool'); end
end

[p, meta] = ablation_config(0, struct('dims', opts.dims, 'gh_n', opts.gh_n));
[~, mg, sl] = config.income_profile(p);
profile = struct('mu_growth', mg, 'sigma_l_log', sl, 'p_surv', config.survival(p));
sh  = grids.shock_grid(p);
ap  = pension.annuity_price(p, profile, sh);
sol = solver.solve(p, profile, sh, ap);
sim = simulate.forward(p, profile, sol, ap, 4000, 12345, p.b0);

lam = p.u1_grid(:);
XY  = (1 - lam) ./ lam;          % liquid wealth in years of income
ok  = XY <= 30;                  % clip the far tail so the interesting range is visible

fig = figure('Position', [60 60 1500 860], 'Color', 'w');
tl = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
cmap = turbo(numel(opts.ages));

% --- (a) equity share policy -------------------------------------------------
ax = nexttile(tl, 1); hold(ax, 'on');
for k = 1:numel(opts.ages)
    t = opts.ages(k) - p.age0 + 1;
    if t < 1 || t > p.T, continue; end
    plot(ax, XY(ok), squeeze(sol.pi_pol(ok, 1, 1, t)), '-', ...
        'Color', cmap(k,:), 'LineWidth', 1.5, ...
        'DisplayName', sprintf('age %d', opts.ages(k)));
end
xlabel(ax, 'liquid wealth X/Y (years of income)');
ylabel(ax, '\pi  (equity share of savings)');
title(ax, '(a) Portfolio rule by age');
ylim(ax, [-0.02 1.02]); grid(ax, 'on'); box(ax, 'on');
legend(ax, 'Location', 'northeast', 'FontSize', 7);

% --- (b) consumption rule ----------------------------------------------------
ax = nexttile(tl, 2); hold(ax, 'on');
for k = 1:numel(opts.ages)
    t = opts.ages(k) - p.age0 + 1;
    if t < 1 || t > p.T, continue; end
    plot(ax, XY(ok), squeeze(sol.c_pol(ok, 1, 1, t)), '-', ...
        'Color', cmap(k,:), 'LineWidth', 1.5);
end
xlabel(ax, 'liquid wealth X/Y (years of income)');
ylabel(ax, 'c  (consumed fraction of liquid resources)');
title(ax, '(b) Consumption rule by age');
grid(ax, 'on'); box(ax, 'on');

% --- (c) equity share vs age, at fixed wealth --------------------------------
% Holding the STATE fixed and varying only age isolates the age effect from the
% moving wealth distribution that the simulated mean confounds it with.
ax = nexttile(tl, 3); hold(ax, 'on');
targets = [0.5 2 5 10];
ages_all = p.age0 : p.age0 + p.T - 1;
for j = 1:numel(targets)
    [~, i1] = min(abs(XY - targets(j)));
    pj = squeeze(sol.pi_pol(i1, 1, 1, :));
    plot(ax, ages_all, pj, '-', 'LineWidth', 1.4, ...
        'DisplayName', sprintf('X/Y = %.1f', targets(j)));
end
xline(ax, p.retirement_age, '--', 'Color', [.5 .5 .5]);
xlabel(ax, 'age'); ylabel(ax, '\pi at fixed wealth');
title(ax, '(c) Age effect at fixed state');
ylim(ax, [-0.02 1.02]); grid(ax, 'on'); box(ax, 'on');
legend(ax, 'Location', 'best', 'FontSize', 7);

% --- (d) simulated mean pi ---------------------------------------------------
ax = nexttile(tl, 4); hold(ax, 'on');
n = min(size(sim.pi, 2), p.T - 1);
a = sim.ages(1:n);
plot(ax, a, mean(sim.pi(:,1:n), 1), '-', 'Color', [0.20 0.35 0.70], 'LineWidth', 1.6);
plot(ax, a, prctile(sim.pi(:,1:n), 5, 1),  ':', 'Color', [0.20 0.35 0.70]);
plot(ax, a, prctile(sim.pi(:,1:n), 95, 1), ':', 'Color', [0.20 0.35 0.70]);
xline(ax, p.retirement_age, '--', 'Color', [.5 .5 .5]);
xlabel(ax, 'age'); ylabel(ax, 'simulated \pi');
title(ax, '(d) Simulated share: mean with 5th/95th pct');
ylim(ax, [0 1.02]); grid(ax, 'on'); box(ax, 'on');

% --- (e) consumption, income, wealth -----------------------------------------
ax = nexttile(tl, 5); hold(ax, 'on');
plot(ax, sim.ages, mean(sim.C, 1), '-',  'LineWidth', 1.6, 'DisplayName', 'consumption');
plot(ax, sim.ages, mean(sim.Y, 1), '--', 'LineWidth', 1.4, 'DisplayName', 'income');
plot(ax, sim.ages, mean(sim.X, 1), '-.', 'LineWidth', 1.4, 'DisplayName', 'liquid wealth');
xline(ax, p.retirement_age, '--', 'Color', [.5 .5 .5], 'HandleVisibility', 'off');
xlabel(ax, 'age'); ylabel(ax, 'model units (not EUR)');
title(ax, '(e) Consumption / income / wealth');
legend(ax, 'Location', 'northwest', 'FontSize', 7);
grid(ax, 'on'); box(ax, 'on');

% --- (f) wealth-to-income ratio ----------------------------------------------
ax = nexttile(tl, 6); hold(ax, 'on');
plot(ax, sim.ages, mean(sim.X ./ max(sim.Y, eps), 1), '-', 'LineWidth', 1.6);
xline(ax, p.retirement_age, '--', 'Color', [.5 .5 .5]);
xlabel(ax, 'age'); ylabel(ax, 'X / Y (years of income)');
title(ax, '(f) Liquid wealth in years of income');
grid(ax, 'on'); box(ax, 'on');

title(tl, sprintf(['CGM core (ablation rung 0): policy functions   ' ...
    '[grid %d-%d-%d, gh_n %d, \\gamma=%g]'], meta.dims, p.gh_n, p.gamma), ...
    'FontWeight', 'bold');

out = fullfile(here, 'fig_cgm_policy.png');
exportgraphics(fig, out, 'Resolution', 140);
fprintf('Wrote %s\n', out);

fprintf('\npi policy at selected states (rows = X/Y, cols = age):\n');
fprintf('%8s', 'X/Y');
for k = 1:numel(opts.ages), fprintf('%8d', opts.ages(k)); end
fprintf('\n');
for j = 1:numel(targets)
    [~, i1] = min(abs(XY - targets(j)));
    fprintf('%8.1f', XY(i1));
    for k = 1:numel(opts.ages)
        t = opts.ages(k) - p.age0 + 1;
        fprintf('%8.3f', sol.pi_pol(i1, 1, 1, t));
    end
    fprintf('\n');
end
end
