% ANALYZE_DC_STRATEGIES_TIMING  Runtime report across the DC-strategy sweep.
%
%   Loads only the lightweight `timing` struct from each dc_{strategy}_
%   {housing}.mat file produced by run_dc_strategies.m (not the full sol/sim
%   arrays, so this is fast even once all 20 runs are ~60MB+ each) and
%   reports three things:
%     1. Per-strategy / per-run solve time (total_sec), with variability
%        across strategies and across housing.
%     2. Per-period solve time variability WITHIN each run (period_sec) --
%        i.e. how much backward-induction time varies period to period for
%        a given strategy.
%     3. Total solve time across the whole sweep so far.
%
%   Safe to run on a partially-completed sweep -- only reports on files that
%   exist at the time it's run.

out_dir = utility.output_dir();
files = dir(fullfile(out_dir, 'dc_*.mat'));
if isempty(files)
    error('analyze_dc_strategies_timing:none', ...
        'No dc_*.mat files found in %s -- run run_dc_strategies.m first.', out_dir);
end

n = numel(files);
strategy    = strings(n,1);
housing     = strings(n,1);
total_sec   = nan(n,1);
sim_sec     = nan(n,1);
period_mean = nan(n,1);
period_std  = nan(n,1);
period_min  = nan(n,1);
period_max  = nan(n,1);
period_cv   = nan(n,1);
n_periods   = nan(n,1);

for k = 1:n
    S = load(fullfile(files(k).folder, files(k).name), 'timing');
    if ~isfield(S, 'timing')
        warning('%s has no timing struct -- skipped', files(k).name);
        continue
    end
    tm = S.timing;
    strategy(k)  = string(tm.strategy);
    housing(k)   = string(tm.housing);
    total_sec(k) = tm.total_sec;
    if isfield(tm, 'sim_sec'), sim_sec(k) = tm.sim_sec; end
    ps = tm.period_sec(:);
    ps = ps(ps > 0);              % guard against any unset/zero placeholder entries
    period_mean(k) = mean(ps);
    period_std(k)  = std(ps);
    period_min(k)  = min(ps);
    period_max(k)  = max(ps);
    period_cv(k)   = period_std(k) / period_mean(k);
    n_periods(k)   = numel(ps);
end

T = table(strategy, housing, total_sec, sim_sec, period_mean, period_std, ...
          period_cv, period_min, period_max, n_periods);
T = sortrows(T, 'total_sec', 'descend');

fprintf('\n=== 1. Per-run solve time (sorted slowest first) ===\n');
disp(T)

fprintf('\n=== 1a. Per-strategy solve time (renter+owner combined) ===\n');
disp(groupsummary(T, 'strategy', {'mean','std','min','max'}, 'total_sec'))

fprintf('\n=== 1b. Per-housing solve time (across all strategies) ===\n');
disp(groupsummary(T, 'housing', {'mean','std','min','max'}, 'total_sec'))

fprintf('\n=== 2. Per-period solve time variability, within each run ===\n');
fprintf('  mean of per-run mean period time : %.3f s\n', mean(T.period_mean, 'omitnan'));
fprintf('  mean of per-run coeff. of variation (std/mean): %.3f\n', mean(T.period_cv, 'omitnan'));
[~, cv_idx] = max(T.period_cv);
fprintf('  most variable run (highest CV): %s / %s  (CV=%.3f, min=%.2fs, max=%.2fs)\n', ...
    T.strategy(cv_idx), T.housing(cv_idx), T.period_cv(cv_idx), T.period_min(cv_idx), T.period_max(cv_idx));
[~, cv_idx_lo] = min(T.period_cv);
fprintf('  least variable run (lowest CV):  %s / %s  (CV=%.3f, min=%.2fs, max=%.2fs)\n', ...
    T.strategy(cv_idx_lo), T.housing(cv_idx_lo), T.period_cv(cv_idx_lo), T.period_min(cv_idx_lo), T.period_max(cv_idx_lo));

fprintf('\n=== 3. Total solve time across the whole sweep ===\n');
n_done = sum(~isnan(T.total_sec));
fprintf('  Runs completed so far: %d\n', n_done);
fprintf('  Sum of solver total_sec: %.1f min (%.2f h)\n', ...
    sum(T.total_sec,'omitnan')/60, sum(T.total_sec,'omitnan')/3600);
if any(~isnan(T.sim_sec))
    fprintf('  Sum of simulation sim_sec: %.1f min\n', sum(T.sim_sec,'omitnan')/60);
    fprintf('  Grand total (solve + simulate): %.1f min (%.2f h)\n', ...
        sum(T.total_sec + T.sim_sec, 'omitnan')/60, sum(T.total_sec + T.sim_sec, 'omitnan')/3600);
end

%% -----------------------------------------------------------------------
%% Quick visualization
%% -----------------------------------------------------------------------
[~, ord]  = sort(strcat(T.strategy, "_", T.housing));
run_names = categorical(strcat(T.strategy(ord), " (", T.housing(ord), ")"));
run_names = reordercats(run_names, string(run_names));

fig = figure('Position',[60 60 1500 500],'Color','w');
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');

nexttile; hold on; grid on; box on;
bar(run_names, T.total_sec(ord)/60, 'FaceColor',[0.30 0.50 0.75]);
ylabel('Solve time (min)'); title('Solver time by strategy \times housing');
set(gca, 'XTickLabelRotation', 60, 'FontSize', 8);

nexttile; hold on; grid on; box on;
bar(run_names, T.period_cv(ord), 'FaceColor',[0.80 0.45 0.25]);
ylabel('Coefficient of variation'); title('Per-period solve-time variability within each run');
set(gca, 'XTickLabelRotation', 60, 'FontSize', 8);

out_png = fullfile(out_dir, 'fig_dc_strategies_timing.png');
exportgraphics(fig, out_png, 'Resolution', 130);
fprintf('\nWrote %s\n', out_png);
