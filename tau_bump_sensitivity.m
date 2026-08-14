function tau_bump_sensitivity(opts)
%TAU_BUMP_SENSITIVITY  Re-solve a glide path with tau moved at a single age.
%
%   tau_bump_sensitivity
%   tau_bump_sensitivity(baseline="spl_000_000_000")
%   tau_bump_sensitivity(ages=[30 45 60], delta=0.15)
%   tau_bump_sensitivity(ages=25:2:45, housing="owner")
%
%   Solves a baseline glide path, then re-solves it once per (age, sign) with
%   tau_S moved by +/- delta at that age alone. report_tau_sensitivity turns the
%   output into the welfare gradient by age.
%
%   Both directions are solved by default because a one-sided run cannot
%   separate "the baseline is optimal here" from "the baseline is wrong here".
%   Only the sign pair distinguishes a local optimum from a slope.
%
%   Each job is one solve, so slice `ages` across cluster instances the way
%   run_spline_strategies slices the menu. Any job whose file already exists is
%   skipped, so instances may restart or overlap.
%
%   Output files carry p, welfare0 and bump_info only; the gradient needs
%   nothing else and sol would dominate the file size. Pass save_sol=true to
%   keep the policies. The reporter finds files by glob and reads bump_info
%   from inside them, so filenames are not parsed.
%
%   Ages default to the working life. With p.tau_decum empty, tau_S also sets
%   the retirement fund's equity share, so bumping a retired age changes the
%   decumulation portfolio and reprices the annuity rather than altering the
%   accumulation glide. That is allowed but warns.
%
%   Options:
%     baseline    strategy name resolved against strategy.menu() (default
%                 "spl_100_050_000"), or "flat" for a constant path
%     base_tau    explicit length T-1 tau path; overrides `baseline`
%     flat_level  level for baseline="flat" (default 0.5)
%     ages        ages to bump (default p.age0 : 5 : p.retirement_age-1)
%     delta       bump size in equity share (default 0.10)
%     signs       which directions (default [+1 -1])
%     width       half-width in years of the bumped window (default 0 = one age)
%     housing     "renter" | "owner" | "both" (default "both")
%     gh_n, state_grid   MUST match whatever you compare against (defaults
%                 match run_spline_strategies: 5 and [25 15 15])
%     save_sol    keep sol/sim in the output (default false)
%     tag         filename tag (default: the baseline name)

arguments
    opts.baseline (1,1) string = "spl_100_050_000"
    opts.base_tau (1,:) double = []
    opts.flat_level (1,1) double {mustBeInRange(opts.flat_level,0,1)} = 0.5
    opts.ages     (1,:) double = []
    opts.delta    (1,1) double {mustBePositive} = 0.10
    opts.signs    (1,:) double = [1 -1]
    opts.width    (1,1) double {mustBeNonnegative, mustBeInteger} = 0
    opts.housing  (1,1) string {mustBeMember(opts.housing,["renter","owner","both"])} = "both"
    opts.gh_n     (1,1) double {mustBeInteger, mustBePositive} = 5
    opts.state_grid (1,3) double {mustBeInteger, mustBePositive} = [25 15 15]
    opts.save_sol (1,1) logical = false
    opts.tag      (1,1) string = ""
end

assert(all(ismember(opts.signs, [1 -1])), 'tau_bump_sensitivity:signs', ...
    'signs must be drawn from [+1 -1].');

if opts.housing == "both", HOUSING = {'renter','owner'};
else,                      HOUSING = {char(opts.housing)};
end

p_probe = config.params();
% Pinned to the simplex: this file drives the simplex solver/simulator
% directly, and config.params now defaults to the cube (utility.active_grid).
p_probe.grid_type = 'simplex';
ages    = opts.ages;
if isempty(ages), ages = p_probe.age0 : 5 : p_probe.retirement_age - 1; end
age_max = p_probe.age0 + p_probe.T - 2;
assert(all(ages >= p_probe.age0 & ages <= age_max), 'tau_bump_sensitivity:ages', ...
    'ages must lie in [%d, %d].', p_probe.age0, age_max);
late = ages(ages >= p_probe.retirement_age);
if ~isempty(late)
    warning('tau_bump_sensitivity:decumulation', ...
        ['Ages %s are at/after retirement (%d). With p.tau_decum = [] those bumps ' ...
         'change the DECUMULATION fund and reprice the annuity, which is a ' ...
         'different experiment from the accumulation glide.'], ...
        mat2str(late), p_probe.retirement_age);
end

tag = char(opts.tag);
if isempty(tag)
    if isempty(opts.base_tau), tag = char(opts.baseline);
    else,                      tag = 'custom'; end
end

LOG_FILE = fullfile(utility.output_dir(), 'tau_bump_log.txt');
start_pool();

% Job list: baseline first (the reporter needs it), then every (age, sign).
jobs = struct('age', {}, 'sgn', {}, 'housing', {});
for hi = 1:numel(HOUSING)
    jobs(end+1) = struct('age', NaN, 'sgn', 0, 'housing', HOUSING{hi}); %#ok<AGROW>
    for a = ages
        for s = opts.signs
            jobs(end+1) = struct('age', a, 'sgn', s, 'housing', HOUSING{hi}); %#ok<AGROW>
        end
    end
end

lprintf(LOG_FILE, '\n%s\ntau_bump_sensitivity start: %s\n', repmat('=',1,70), ...
    datestr(now, 'yyyy-mm-dd HH:MM:SS'));
lprintf(LOG_FILE, 'baseline "%s"  delta %.3f  width %d  ages [%s]\n', ...
    tag, opts.delta, opts.width, strjoin(compose('%d', ages), ' '));
lprintf(LOG_FILE, 'grid %dx%dx%d gh_n=%d   %d jobs\n%s\n', opts.state_grid, ...
    opts.gh_n, numel(jobs), repmat('-',1,70));

t_wall = tic; n_done = 0;

for j = 1:numel(jobs)
    job      = jobs(j);
    out_file = fullfile(utility.output_dir(), bump_filename(tag, job, opts.delta));
    if isfile(out_file)
        lprintf(LOG_FILE, 'SKIP  %s\n', out_file); continue
    end

    p = config.params();
    % Pinned to the simplex: this file drives the simplex solver/simulator
    % directly, and config.params now defaults to the cube (utility.active_grid).
    p.grid_type = 'simplex';
    p.is_owner = strcmp(job.housing, 'owner');

    tau_base = baseline_path(p, opts);
    [tau_use, d_center, d_total, idx] = apply_bump(p, tau_base, job, opts);
    p.tau_S = tau_use;

    p = utility.build_state_grids(p, opts.state_grid, opts.gh_n);
    p = assert_production_fill(p);

    if isnan(job.age)
        lprintf(LOG_FILE, '\n--- [%d/%d] BASELINE | %s\n', j, numel(jobs), job.housing);
    else
        lprintf(LOG_FILE, '\n--- [%d/%d] age %d  %+.3f | %s\n', j, numel(jobs), ...
            job.age, opts.delta*job.sgn, job.housing);
        lprintf(LOG_FILE, '    tau at age %d: %.4f -> %.4f  (realised %+.4f, total %+.4f)\n', ...
            job.age, tau_base(idx(1)), tau_use(idx(1)), d_center, d_total);
        if abs(d_total) < 1e-12
            lprintf(LOG_FILE, '    clamped to no change (tau already at the bound); the reporter\n');
            lprintf(LOG_FILE, '    drops this run rather than dividing by zero.\n');
        end
    end

    [~, mu_growth, sigma_l_log] = config.income_profile(p);
    profile.mu_growth   = mu_growth;
    profile.sigma_l_log = sigma_l_log;
    profile.p_surv      = config.survival(p);
    shocks    = grids.shock_grid(p);
    ann_price = pension.annuity_price(p, profile, shocks);

    t_sc = tic;
    sol  = solver.solve_lifecycle(p, profile, shocks, ann_price);
    welfare0 = utility.welfare_summary(p, sol.V(:,:,:,1));

    bump_info = struct('tag', tag, 'age', job.age, 'sign', job.sgn, ...
        'delta', opts.delta, 'width', opts.width, 'housing', job.housing, ...
        'delta_center', d_center, 'delta_total', d_total, ...
        'bumped_idx', idx, 'tau_base', tau_base, 'tau_used', tau_use, ...
        'is_baseline', isnan(job.age));

    if opts.save_sol
        sim = simulate.paths(p, profile, sol, ann_price, 5000);
        save(out_file, 'p','welfare0','bump_info','sol','sim','profile', ...
             'shocks','ann_price', '-v7.3');
    else
        save(out_file, 'p','welfare0','bump_info', '-v7.3');
    end

    lprintf(LOG_FILE, '    V_tilde0 at b0 = %.6g   (%.1f min)\n', ...
        welfare0.Vt0_b0, toc(t_sc)/60);
    n_done = n_done + 1;
end

lprintf(LOG_FILE, '\n%s\nDONE  %.1f min, %d new solves\n%s\n\n', repmat('=',1,70), ...
    toc(t_wall)/60, n_done, repmat('=',1,70));
fprintf('\nNow run:  report_tau_sensitivity\n');
end

%% =======================================================================
function tau = baseline_path(p, opts)
%BASELINE_PATH  The unbumped tau_S, length T-1.
if ~isempty(opts.base_tau)
    tau = opts.base_tau(:);
    assert(numel(tau) >= p.T - 1, 'tau_bump_sensitivity:base_tau', ...
        'base_tau needs at least T-1 = %d entries (got %d).', p.T - 1, numel(tau));
    tau = tau(1 : p.T - 1);
    return
end
if opts.baseline == "flat"
    tau = repmat(opts.flat_level, p.T - 1, 1);
    return
end
M = strategy.menu();
k = find(strcmp({M.name}, char(opts.baseline)), 1);
assert(~isempty(k), 'tau_bump_sensitivity:baseline', ...
    'Baseline "%s" is not in strategy.menu().', opts.baseline);
tau = strategy.spline_tau(p, M(k).knot_ages, M(k).knot_fracs);
end

function [tau, d_center, d_total, idx] = apply_bump(p, tau_base, job, opts)
%APPLY_BUMP  tau_base with a clamped +/- delta over the age window.
%   Returns the realised change, which is what the gradient must be divided by:
%   near tau = 0 or 1 the clamp shrinks the step, so the nominal delta would
%   understate the slope.
tau = tau_base;
if isnan(job.age)
    d_center = 0; d_total = 0; idx = [];
    return
end
lo  = max(p.age0,               job.age - opts.width);
hi  = min(p.age0 + p.T - 2,     job.age + opts.width);
idx = (lo : hi) - p.age0 + 1;
tau(idx) = min(max(tau_base(idx) + job.sgn*opts.delta, 0), 1);
d_center = tau(job.age - p.age0 + 1) - tau_base(job.age - p.age0 + 1);
d_total  = sum(tau(idx) - tau_base(idx));
end

function name = bump_filename(tag, job, delta)
if isnan(job.age)
    name = sprintf('bump_%s_base_%s.mat', tag, job.housing);
else
    name = sprintf('bump_%s_a%d_%s%d_%s.mat', tag, job.age, ...
        ternary(job.sgn > 0, 'p', 'm'), round(100*delta), job.housing);
end
end

function start_pool()
nw = str2double(getenv('CGM_N_WORKERS'));
if ~isnan(nw) && nw >= 1
    pool = gcp('nocreate');
    if isempty(pool) || pool.NumWorkers < nw
        if ~isempty(pool), delete(pool); end
        try
            clus = parcluster('local'); clus.NumWorkers = max(clus.NumWorkers, nw);
            parpool(clus, nw);
        catch err
            fprintf('Process pool failed (%s); falling back to Threads.\n', err.message);
            parpool('Threads');
        end
    end
elseif isempty(gcp('nocreate'))
    try
        parpool('Threads');
    catch
        try
            parpool('local');
        catch
            warning('tau_bump_sensitivity:pool', 'parpool failed; running serial');
        end
    end
end
end

function p = assert_production_fill(p)
% Same production guard as run_spline_strategies / run_nodc: p.legacy_fill is
% the pre-fix phantom-penalty continuation fill and is test-only. Stamping it
% false explicitly is what lets param_fingerprint fence pre-fix files off.
assert(~(isfield(p, 'legacy_fill') && p.legacy_fill), ...
    'tau_bump_sensitivity:legacy_fill', ...
    'p.legacy_fill is set -- that is the pre-fix phantom-penalty fill, test-only.');
p.legacy_fill = false;
end

function lprintf(log_file, fmt, varargin)
msg = sprintf(fmt, varargin{:});
fprintf('%s', msg);
fid = fopen(log_file, 'a');
if fid >= 0, fprintf(fid, '%s', msg); fclose(fid); end
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end
