function fig = plot_reit_impact(p_base, out_png)
%PLOT_REIT_IMPACT  Dashboard of the DC REIT's impact: with vs without the REIT.
%
%   fig = plot_reit_impact()                 % default owner calibration
%   fig = plot_reit_impact(p_base)           % supply your own p
%   fig = plot_reit_impact(p_base, out_png)  % also save a PNG
%
%   Solves the model twice on the SAME shocks -- once with the REIT switched
%   off (tau_REIT = 0, the pre-REIT model) and once with the calibrated REIT
%   sleeve -- and contrasts the two. Four panels:
%     (a) DC fund allocation over the lifecycle: stock / REIT / bond shares.
%     (b) Mean DC fund balance by age, with the REIT run's 10-90 band.
%     (c) Mean annual pension payout in retirement.
%     (d) Distribution of the DC fund at retirement.
%
%   DC-fund accumulation is policy-independent (contributions are mandatory),
%   so a fast grid is used; the fund and income panels are unaffected by it.

if nargin < 1 || isempty(p_base)
    p_base = config.params();
    p_base.is_owner = true;
end
if nargin < 2, out_png = ''; end

% ---- fast, policy-independent-accurate configuration --------------------
p_base.grid_type = 'lna';
p_base.u1_grid = linspace(0,1,14).'; p_base.N_u1 = 14;
p_base.u2_grid = linspace(0,1,10).'; p_base.N_u2 = 10;
p_base.u3_grid = linspace(0,1,10).'; p_base.N_u3 = 10;
p_base.gh_n = 5; p_base.gh_n_reit = 3;
p_base.N_c = 15; p_base.N_pi = 15;
p_base.skip_polish = true;
N_sim = 4000; seed = 20260511;

p_off = p_base; p_off.tau_REIT = 0;      % pre-REIT baseline
p_on  = p_base;                          % calibrated REIT sleeve
assert(config.reit_active(p_on), 'plot_reit_impact:reit_off', ...
    'p_base has no active REIT (tau_REIT and correlations are all zero).');

[sim_off, ~]       = run_case(p_off, N_sim, seed);
[sim_on,  ann_on]  = run_case(p_on,  N_sim, seed);
[~,       ann_off] = run_case(p_off, N_sim, seed);

ages   = sim_on.ages;                 % 1 x T
ages_tr= ages(1:end-1);               % transitions (shares are T-1)
tr     = p_base.t_ret;                % retirement period index
reit_share = mean(p_on.tau_REIT);     % scalar summary for titles

% Allocation shares over the lifecycle (deterministic, from the run's p).
stock_sh = config.tau_effective(p_on).';   % 1 x T-1
reit_sh  = config.reit_effective(p_on).';
bond_sh  = 1 - stock_sh - reit_sh;

% ---- colours ------------------------------------------------------------
C.stock = [0.20 0.40 0.75];
C.reit  = [0.85 0.45 0.15];
C.bond  = [0.55 0.60 0.65];
C.on    = [0.80 0.30 0.10];
C.off   = [0.25 0.45 0.70];

fig = figure('Position', [40 40 1500 950], 'Color', 'w');
tl = tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
tenure = ternary(p_base.is_owner, 'owner', 'renter');
title(tl, sprintf('Impact of the DC REIT sleeve (share = %.0f%%, \\mu^{excess}=%.1f%%, \\sigma=%.0f%%) — %s', ...
      100*reit_share, 100*p_on.mu_REIT_level, 100*p_on.sigma_REIT_level, tenure), ...
      'FontSize', 14, 'FontWeight', 'bold');

% ===== (a) DC allocation composition =====================================
nexttile;
Aarea = area(ages_tr, [bond_sh(:), stock_sh(:), reit_sh(:)]);
Aarea(1).FaceColor = C.bond;  Aarea(2).FaceColor = C.stock;  Aarea(3).FaceColor = C.reit;
for a = Aarea, a.EdgeColor = 'none'; a.FaceAlpha = 0.9; end
xline(ages(tr), 'k--', 'retirement', 'LabelVerticalAlignment','bottom', 'FontSize',8);
grid on; box on; ylim([0 1]); xlim([ages(1) ages(end-1)]);
xlabel('Age'); ylabel('Share of DC fund [0–1]');
legend({'Bond','Stock (glide \tau_S)','REIT (\tau_{REIT})'}, 'Location','east', 'FontSize',9);
title('(a)  DC fund allocation over the lifecycle');

% ===== (b) mean DC fund balance, on vs off ===============================
nexttile; hold on; grid on; box on;
qlo = prctile(sim_on.A, 10, 1); qhi = prctile(sim_on.A, 90, 1);
hB = fill([ages, fliplr(ages)], [qlo, fliplr(qhi)], C.on, ...
     'FaceAlpha', 0.15, 'EdgeColor', 'none');
hOff = plot(ages, mean(sim_off.A,1), '-',  'Color', C.off, 'LineWidth', 2);
hOn  = plot(ages, mean(sim_on.A,1),  '-',  'Color', C.on,  'LineWidth', 2);
xline(ages(tr), 'k--', 'HandleVisibility','off');
xlabel('Age'); ylabel('DC fund balance (€)');
legend([hOff, hOn, hB], {'no REIT (baseline)', 'with REIT', 'with REIT: 10–90%'}, ...
       'Location','northwest', 'FontSize',9);
title(sprintf('(b)  Mean DC fund balance  (age %d: %+.1f%%)', ...
      ages(tr), 100*(mean(sim_on.A(:,tr))/mean(sim_off.A(:,tr))-1)));

% ===== (c) mean annual pension payout in retirement ======================
nexttile; hold on; grid on; box on;
mp_off = mean(sim_off.ann_pay, 1); mp_on = mean(sim_on.ann_pay, 1);
plot(ages(tr:end), mp_off(tr:end), '-', 'Color', C.off, 'LineWidth', 2);
plot(ages(tr:end), mp_on(tr:end),  '-', 'Color', C.on,  'LineWidth', 2);
xlabel('Age'); ylabel('Gross annual pension payout (€)');
legend({'no REIT (baseline)', 'with REIT'}, 'Location','best', 'FontSize',9);
title(sprintf('(c)  Mean pension payout  (a(t\\_ret): %.2f → %.2f)', ann_off(tr), ann_on(tr)));

% ===== (d) DC-fund distribution at retirement ============================
nexttile; hold on; grid on; box on;
edges = linspace(0, prctile([sim_off.A(:,tr); sim_on.A(:,tr)], 99), 40);
histogram(sim_off.A(:,tr), edges, 'FaceColor', C.off, 'FaceAlpha', 0.5, 'EdgeColor','none', 'Normalization','probability');
histogram(sim_on.A(:,tr),  edges, 'FaceColor', C.on,  'FaceAlpha', 0.5, 'EdgeColor','none', 'Normalization','probability');
xline(mean(sim_off.A(:,tr)), '--', 'Color', C.off, 'LineWidth', 1.5, 'HandleVisibility','off');
xline(mean(sim_on.A(:,tr)),  '--', 'Color', C.on,  'LineWidth', 1.5, 'HandleVisibility','off');
xlabel(sprintf('DC fund at age %d (€)', ages(tr))); ylabel('Probability');
legend({'no REIT', 'with REIT'}, 'Location','northeast', 'FontSize',9);
title(sprintf('(d)  DC fund at retirement  (std %+.1f%%)', ...
      100*(std(sim_on.A(:,tr))/std(sim_off.A(:,tr))-1)));

if ~isempty(out_png)
    exportgraphics(fig, out_png, 'Resolution', 130);
    fprintf('saved %s\n', out_png);
end
end

% ------------------------------------------------------------------------
function [sim, ann_price] = run_case(p, N_sim, seed)
    [~, mu_growth, sigma_l_log] = config.income_profile(p);
    profile.mu_growth   = mu_growth;
    profile.sigma_l_log = sigma_l_log;
    profile.p_surv      = config.survival(p);
    shocks    = grids.shock_grid(p);
    ann_price = pension.annuity_price(p, profile, shocks);
    evalc('sol = solver.solve_lifecycle_lna(p, profile, shocks, ann_price);');
    sim = simulate.forward(p, profile, sol, ann_price, N_sim, seed);
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end
