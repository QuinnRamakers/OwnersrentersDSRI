function R = run_ablation(rungs, opts)
%RUN_ABLATION  Solve the CGM-anchored ablation ladder and measure pi(age).
%
%   R = run_ablation()                 % all seven rungs, default grid
%   R = run_ablation(0)                % rung 0 only
%   R = run_ablation([0 5 6])          % a subset
%   R = run_ablation(rungs, opts)      % opts passed on to ablation_config,
%                                      % plus N_sim / seed / tag / save_mat
%
%   For each rung it solves, simulates, and reports the two things CGM (2005)
%   pins down: consumption should be hump-shaped, and the liquid equity share
%   pi(age) should fall SMOOTHLY once human capital starts running out. The
%   headline number is the roughness of mean pi(age),
%
%       roughness = mean( |second difference of mean pi over age| )
%
%   which is the same statistic the grid-resolution sweep used, so values are
%   comparable to it (0.087 at a 10^3 grid, 0.042 at 14^3, 0.039 at 18^3).
%   It is reported for the whole life and split at retirement, because the two
%   halves were found to have different causes: accumulation roughness is grid
%   resolution, retirement roughness is the flat-objective floor.
%
%   opts (all optional) adds to the ablation_config fields:
%     N_sim     simulated households                 (default 4000)
%     seed      RNG seed for the simulation          (default 12345)
%     tag       suffix for the saved .mat            (default 'default')
%     save_mat  write diagnostics/ablation_<tag>.mat (default true)
%
%   RUN THE WHOLE LADDER ON ONE GRID. The roughness statistic is sensitive to
%   grid resolution, so a ladder whose rungs differ in dims measures the grid,
%   not the economics. opts.dims is deliberately a single value applied to all.

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(root, here);
cd(root);

if nargin < 1 || isempty(rungs), rungs = 0:6; end
if nargin < 2 || isempty(opts), opts = struct(); end
if ~isfield(opts, 'N_sim')    || isempty(opts.N_sim),    opts.N_sim = 4000; end
if ~isfield(opts, 'seed')     || isempty(opts.seed),     opts.seed = 12345; end
if ~isfield(opts, 'tag')      || isempty(opts.tag),      opts.tag = 'default'; end
if ~isfield(opts, 'save_mat') || isempty(opts.save_mat), opts.save_mat = true; end

cfg_opts = rmfield_if(opts, {'N_sim', 'seed', 'tag', 'save_mat'});

if isempty(gcp('nocreate'))
    try, parpool('Threads'); catch, warning('run_ablation:pool', 'no parallel pool'); end
end

R = struct([]);
for k = 1:numel(rungs)
    [p, meta] = ablation_config(rungs(k), cfg_opts);

    fprintf('\n=== rung %d (%s) ===\n', meta.level, meta.name);
    fprintf('  on: income=%d housing=%d dc=%d inctax=%d cgt=%d reit=%d\n', ...
        meta.on.income, meta.on.housing, meta.on.dc, meta.on.inctax, ...
        meta.on.cgt, meta.on.reit);
    fprintf('  grid [%d %d %d] gh_n=%d/%d | gamma=%g | lambda in [%.3g %.3g] | reit_active=%d\n', ...
        meta.dims, meta.gh_n, meta.gh_n_reit, meta.gamma, ...
        meta.lambda_range, meta.reit_active);

    [~, mu_growth, sigma_l_log] = config.income_profile(p);
    profile = struct('mu_growth', mu_growth, 'sigma_l_log', sigma_l_log, ...
                     'p_surv', config.survival(p));
    shocks    = grids.shock_grid(p);
    ann_price = pension.annuity_price(p, profile, shocks);

    t_rung = tic;
    sol = solver.solve(p, profile, shocks, ann_price);
    sim = simulate.forward(p, profile, sol, ann_price, opts.N_sim, opts.seed, p.b0);
    el = toc(t_rung);

    d = diagnose(p, sol, sim, meta);
    fprintf('  [rung %d done in %.1f s (solve %.1f s)]\n', meta.level, el, sol.elapsed);
    print_row(d);

    entry = struct('meta', meta, 'diag', d, 'p', p, 'sol_elapsed', sol.elapsed, ...
                   'rung_elapsed', el);
    if isempty(R), R = entry; else, R(end + 1) = entry; end %#ok<AGROW>

    % Save after every rung: a long ladder should not lose finished work if a
    % later rung fails or the run is stopped.
    if opts.save_mat
        save(fullfile(here, sprintf('ablation_%s.mat', opts.tag)), 'R', 'opts', '-v7.3');
    end
end

fprintf('\n');
print_table(R);

if opts.save_mat
    fname = fullfile(here, sprintf('ablation_%s.mat', opts.tag));
    save(fname, 'R', 'opts', '-v7.3');
    fprintf('\nSaved %s\n', fname);
end
end

% =============================================================================
function d = diagnose(p, sol, sim, meta)
%DIAGNOSE  Reduce one solved rung to the handful of numbers the ladder compares.

ages   = sim.ages;
t_ret  = p.t_ret;

% Mean liquid equity share by age, indexed by the age the choice is made at.
%
% The terminal column is DROPPED. sim.pi is N x T, but at t = T the household
% consumes everything (c_star = 1) and bellman_step_lna sets pi = 0 because
% nothing is saved -- it is a constant, not a choice. Leaving it in puts a
% spurious step of up to 0.9 into any second-difference statistic, which is
% large enough to dominate the whole retirement half of the metric.
n_pi     = min(size(sim.pi, 2), p.T - 1);
pi_mean  = mean(sim.pi(:, 1:n_pi), 1, 'omitnan');
c_mean   = mean(sim.C,  1, 'omitnan');
pi_ages  = ages(1:n_pi);

% Roughness over age. Splitting only at retirement mixes three different
% things: a legitimate KINK where income drops (a kink scores high on a second
% difference no matter how well behaved the policy is), retirement proper, and
% the last years where the balance being allocated has largely been spent. They
% are reported separately because they have different causes and only one of
% them is about the equity choice being indeterminate.
ret       = p.retirement_age;
ph_accum  = pi_ages <  ret - 3;
ph_trans  = pi_ages >= ret - 3 & pi_ages <= ret + 3;
ph_ret    = pi_ages >  ret + 3 & pi_ages < 90;
ph_late   = pi_ages >= 90;
work_idx  = pi_ages < ret;
ret_idx   = ~work_idx;

% Liquid-wealth-weighted pi. An equal-weighted mean counts a household with
% almost no liquid wealth as much as a wealthy one, and pi is economically
% meaningless when it is a share of nothing -- so an equal-weighted mean can be
% jagged purely from households for whom the choice does not matter. Weighting
% by the liquid balance being allocated is the like-for-like question: how is
% the money actually invested. Negative balances get zero weight.
Xw = max(sim.X(:, 1:n_pi), 0);
wsum = sum(Xw, 1);
pi_wmean = sum(sim.pi(:, 1:n_pi) .* Xw, 1) ./ max(wsum, realmin);
pi_wmean(wsum <= 0) = NaN;

% How much of the population is at a liquid balance where pi is nearly moot.
tiny = sim.X(:, 1:n_pi) < 0.05 * sim.Y(:, 1:n_pi);
frac_tiny = mean(tiny, 1);

d = struct();
d.label          = meta.label;
d.ages           = pi_ages;
d.pi_mean        = pi_mean;
d.pi_wmean       = pi_wmean;
d.frac_tiny      = frac_tiny;
d.c_mean         = c_mean;
d.roughness      = rough(pi_mean);
d.roughness_work = rough(pi_mean(work_idx));
d.roughness_ret  = rough(pi_mean(ret_idx));
d.r_accum        = rough(pi_mean(ph_accum));
d.r_transition   = rough(pi_mean(ph_trans));
d.r_retired      = rough(pi_mean(ph_ret));
d.r_late         = rough(pi_mean(ph_late));
d.roughness_w      = rough(pi_wmean);
d.roughness_w_work = rough(pi_wmean(work_idx));
d.roughness_w_ret  = rough(pi_wmean(ret_idx));
d.piw_early = mean(pi_wmean(pi_ages >= 25 & pi_ages < 35), 'omitnan');
d.piw_mid   = mean(pi_wmean(pi_ages >= 45 & pi_ages < 55), 'omitnan');
d.piw_late  = mean(pi_wmean(pi_ages >= 70 & pi_ages < 85), 'omitnan');
d.tiny_work = mean(frac_tiny(work_idx));
d.tiny_ret  = mean(frac_tiny(ret_idx));
d.pi_early       = mean(pi_mean(pi_ages >= 25 & pi_ages < 35));
d.pi_mid         = mean(pi_mean(pi_ages >= 45 & pi_ages < 55));
d.pi_late        = mean(pi_mean(pi_ages >= 70 & pi_ages < 85));

% Is pi declining with age at all? CGM's signature is a fall from the 1.0
% constraint. Slope over working life, in share points per year.
pw = pi_mean(work_idx); aw = pi_ages(work_idx);
cf = polyfit(aw(:), pw(:), 1);
d.pi_slope_work = cf(1);

% Consumption hump: peak of mean C over the working life.
cw = c_mean(1:min(numel(c_mean), t_ret - 1));
[~, imax]   = max(cw);
d.c_peak_age = ages(imax);
d.c_hump     = max(cw) / max(c_mean(1), eps);

% Health checks. A rung that floors or goes non-finite is not measuring
% anything about pi.
V0 = sol.V(:,:,:,1);
d.nonfinite_V0 = sum(~isfinite(V0(:)));
d.n_floored    = sim.diagnostics.n_floored;
d.n_negLW      = sim.diagnostics.n_negLW;
d.n_clamp_pi   = sim.diagnostics.n_clamp_pi;
d.n_obs        = numel(sim.pi);
d.floor_pct    = 100 * d.n_floored / max(numel(sim.C), 1);
end

% =============================================================================
function r = rough(v)
v = v(isfinite(v));
if numel(v) < 3, r = NaN; return; end
r = mean(abs(diff(v, 2)));
end

function print_row(d)
fprintf(['  pi  equal-wt: early %.3f  mid %.3f  late %.3f | slope %+.4f/yr\n' ...
         '  pi wealth-wt: early %.3f  mid %.3f  late %.3f\n' ...
         '  roughness by phase: accum %.4f | transition %.4f | retired %.4f | late %.4f\n' ...
         '  roughness equal-wt: all %.4f | work %.4f | retired %.4f\n' ...
         '  roughness wealth-wt:          work %.4f | retired %.4f\n' ...
         '  liquid X < 5%% of Y: %.1f%% of working, %.1f%% of retired household-years\n' ...
         '  C peak age %d (x%.2f entry) | floored %.2f%% | nonfinite V0 %d | negLW %d\n'], ...
    d.pi_early, d.pi_mid, d.pi_late, d.pi_slope_work, ...
    d.piw_early, d.piw_mid, d.piw_late, ...
    d.r_accum, d.r_transition, d.r_retired, d.r_late, ...
    d.roughness, d.roughness_work, d.roughness_ret, ...
    d.roughness_w_work, d.roughness_w_ret, ...
    100 * d.tiny_work, 100 * d.tiny_ret, ...
    d.c_peak_age, d.c_hump, d.floor_pct, d.nonfinite_V0, d.n_negLW);
end

function print_table(R)
fprintf('%-12s | %7s %7s | %7s %7s | %6s %6s %6s | %6s %6s %6s | %6s\n', ...
    'rung', 'rgh_wrk', 'rgh_ret', 'rghW_wk', 'rghW_rt', ...
    'pi_ely', 'pi_mid', 'pi_lat', 'piW_ely', 'piW_mid', 'piW_lat', 'tiny_rt');
fprintf('%s\n', repmat('-', 1, 108));
for k = 1:numel(R)
    d = R(k).diag;
    fprintf('%-12s | %7.4f %7.4f | %7.4f %7.4f | %6.3f %6.3f %6.3f | %6.3f %6.3f %6.3f | %5.1f%%\n', ...
        d.label, d.roughness_work, d.roughness_ret, ...
        d.roughness_w_work, d.roughness_w_ret, ...
        d.pi_early, d.pi_mid, d.pi_late, ...
        d.piw_early, d.piw_mid, d.piw_late, 100 * d.tiny_ret);
end
end

function s = rmfield_if(s, fields)
for k = 1:numel(fields)
    if isfield(s, fields{k}), s = rmfield(s, fields{k}); end
end
end
