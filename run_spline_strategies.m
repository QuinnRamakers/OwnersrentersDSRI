function run_spline_strategies(strats, opts)
%RUN_SPLINE_STRATEGIES  Solve+simulate a list of spline glide-path strategies.
%
%   run_spline_strategies(strats)
%   run_spline_strategies(strats, housing="renter", n_sim=5000, smoke=false)
%
%   strats : struct array from strategy.menu() / strategy.make_grid(), or a
%            cell/string array of strategy names resolved against
%            strategy.menu(). Each strategy's PCHIP glide path (see
%            strategy.spline_tau) overrides p.tau_S; the household's own
%            (c,pi) choice is still solved optimally given that rule.
%
%   Assigning strategies to cluster instances is just slicing the menu:
%     M = strategy.menu();
%     run_spline_strategies(M(1:18));                       % instance A
%     run_spline_strategies(M(19:end));                     % instance B
%     run_spline_strategies({'spl_100_050_000'});           % by name
%     run_spline_strategies(M, housing="owner");            % one housing only
%   From the shell:  matlab -batch "M=strategy.menu(); run_spline_strategies(M(1:18))"
%
%   Options:
%     housing    : "renter" | "owner" | "both" (default "both")
%     n_sim      : simulated households per scenario (default 5000)
%     gh_n       : Gauss-Hermite nodes per shock dimension. Default comes from
%                  utility.production_grid for the active coordinate system.
%     state_grid : three state-grid sizes -- [N_u1 N_u2 N_u3] on the cube,
%                  [N_lambda N_sA N_sH] on the simplex. Default likewise from
%                  utility.production_grid, which is also what run_combined and
%                  run_nodc read, so the sweep and the benchmarks land on the
%                  same grid without three copies of the numbers. lambda gets
%                  the extra resolution on both grids: it is empirically the
%                  steepest policy axis.
%     smoke      : true -> even coarser grids + 200 households, smoke_ file
%                  prefix; end-to-end plumbing check in minutes, NOT results.
%   All sweep runs must share gh_n/state_grid -- welfare rankings are only
%   comparable across runs solved on identical grids (compare with the
%   defaults everywhere, or pass the same overrides everywhere).
%
%   Coordinate system follows CGM_GRID (utility.active_grid): the cube by
%   default, the simplex with CGM_GRID=simplex. Cube output carries an _lna
%   suffix, so both sweeps can live in one output dir and resume independently.
%   Before launching a cube sweep read the sizing note in
%   utility.production_grid -- the cube has no infeasible nodes, so its
%   production grid holds an order of magnitude more live states than the
%   simplex sweep grid does.
%
%   Output files:  {strategy}_{renter|owner}[_lna].mat,
%                  e.g. spl_100_050_000_owner_lna.mat.
%   By default each file is lean: the calibration `p`, the `welfare0` summary
%   (V_tilde at the initial state -- corner, the b0/b_alt anchors and a buffer
%   curve; see utility.welfare_summary), the strategy definition, timing, and a
%   `sim_summary` of life-cycle means. That is everything the comparison and
%   plots read; the value function and full simulated paths are dropped to keep
%   a large sweep to a manageable size. Pass full_output=true to keep them for a
%   single strategy you want to examine in detail.
%   Log file:      spline_strategies_log.txt  (appended, not overwritten)
%
%   Resume-safe: any scenario whose .mat file already exists is skipped, so
%   instances can restart (or overlap in strategy lists) harmlessly, and
%   combining results = download every instance's output dir into one
%   folder, then run compare_spline_strategies.
%
%   Environment variables (infrastructure only):
%     CGM_N_WORKERS : force an n-worker PROCESS pool (laptop: use 10; the
%                     'Threads' profile is capped at 2 there). Unset on the
%                     pod -> Threads pool spanning all cores.
%     CGM_OUTPUT_DIR: write outputs to a persistent volume (see
%                     utility.output_dir).

arguments
    strats
    opts.housing (1,1) string {mustBeMember(opts.housing, ["renter","owner","both"])} = "both"
    opts.n_sim   (1,1) double {mustBePositive} = 5000
    % Empty means "take the production grid for whichever coordinate system is
    % active" -- resolved below, because that default depends on CGM_GRID and
    % an arguments block cannot express one default in terms of another.
    % Passing either explicitly still overrides, and still has to be passed
    % identically to every run in a sweep for the rankings to mean anything.
    opts.gh_n    (1,:) double {mustBeInteger, mustBePositive} = []
    opts.state_grid (1,:) double {mustBeInteger, mustBePositive} = []
    opts.smoke   (1,1) logical = false
    % A sweep only needs each strategy's welfare and a life-cycle summary, not
    % the full value function and every simulated path -- those are tens of MB
    % per file. Default to the lean save; set full_output=true for a single
    % strategy you want to inspect or plot in detail.
    opts.full_output (1,1) logical = false
end

[dims_default, gh_default] = utility.production_grid();
if isempty(opts.state_grid), opts.state_grid = dims_default; end
if isempty(opts.gh_n),       opts.gh_n       = gh_default;   end
assert(numel(opts.state_grid) == 3, 'run_spline_strategies:state_grid', ...
    'state_grid must be three integers, got %s.', mat2str(opts.state_grid));
assert(isscalar(opts.gh_n), 'run_spline_strategies:gh_n', ...
    'gh_n must be a scalar, got %s.', mat2str(opts.gh_n));

%% Resolve the strategy list
if iscellstr(strats) || isstring(strats)  %#ok<ISCLSTR>  names -> menu lookup
    names = cellstr(strats);
    M = strategy.menu();
    [tf, loc] = ismember(names, {M.name});
    assert(all(tf), 'run_spline_strategies:unknown', ...
        'Not in strategy.menu(): %s', strjoin(names(~tf), ', '));
    strats = M(loc);
end
assert(isstruct(strats) && all(isfield(strats, {'name','knot_ages','knot_fracs'})), ...
    'run_spline_strategies:badinput', ...
    'strats must be a struct array with fields name/knot_ages/knot_fracs, or a list of names');

if opts.housing == "both", HOUSING = {'renter', 'owner'};
else,                      HOUSING = {char(opts.housing)};
end

SMOKE    = opts.smoke;
N_SIM    = opts.n_sim;
if SMOKE, N_SIM = 200; end
LOG_FILE = fullfile(utility.output_dir(), 'spline_strategies_log.txt');
prefix   = ternary(SMOKE, 'smoke_', '');
GRID_SUFFIX = utility.grid_suffix();   % '' simplex, '_lna' cube

%% Job list: housing-major
jobs = struct('strat', {}, 'housing', {});
for hi = 1:numel(HOUSING)
    for si = 1:numel(strats)
        jobs(end+1) = struct('strat', strats(si), 'housing', HOUSING{hi}); %#ok<AGROW>
    end
end

%% Parallel pool (start once, reused across all runs)
% Size the pool to the cores the pod may actually use, not what MATLAB detects.
% feature('numcores') sees the whole node inside a container (e.g. 128) while
% the cgroup caps the pod far lower (e.g. 32); a pool sized to the node
% oversubscribes -- 128 fmincon workers, each with multithreaded BLAS, on 32
% real cores -- and ran the cube step ~7x slower than a right-sized laptop
% pool. utility.cpu_quota reads the cgroup quota (or CGM_N_WORKERS when set);
% maxNumCompThreads(1) stops each fmincon's BLAS from oversubscribing on top of
% the parfor. Both are the fix for that slowdown; keep them together.
n_target = utility.cpu_quota();
maxNumCompThreads(1);

want_process = ~isnan(str2double(getenv('CGM_N_WORKERS')));  % explicit -> process pool (laptop)

pool = gcp('nocreate');
if ~isempty(pool) && pool.NumWorkers ~= n_target
    delete(pool); pool = [];   % wrong size (e.g. a stale 128-wide pool) -> rebuild
end
if isempty(pool)
    started = false;
    if want_process
        try
            clus = parcluster('local');
            clus.NumWorkers = max(clus.NumWorkers, n_target);
            parpool(clus, n_target);
            % Client maxNumCompThreads does not reach separate worker
            % processes, so pin BLAS on each one explicitly.
            parfevalOnAll(@() maxNumCompThreads(1), 0);
            started = true;
        catch err
            % Cluster pods routinely fail to start process workers; the
            % Threads pool shares the client process (and its 1 BLAS thread).
            fprintf('Process pool failed (%s); falling back to Threads.\n', err.message);
        end
    end
    if ~started
        try
            parpool('Threads', n_target);
        catch
            try, parpool('Threads'); catch, warning('parpool failed; running serial'); end
        end
    end
end

%% Log header
lprintf(LOG_FILE, '\n%s\n', repmat('=',1,65));
lprintf(LOG_FILE, 'run_spline_strategies  start: %s%s\n', ...
    datestr(now, 'yyyy-mm-dd HH:MM:SS'), ternary(SMOKE, '  [SMOKE MODE]', ''));
lprintf(LOG_FILE, 'This call: %d strategies x %s = %d jobs  (%s ... %s)\n', ...
    numel(strats), strjoin(HOUSING, '+'), numel(jobs), ...
    strats(1).name, strats(end).name);
lprintf(LOG_FILE, 'Grids: %s, state %dx%dx%d, gh_n=%d (%d joint nodes)\n', ...
    utility.active_grid(), ...
    opts.state_grid(1), opts.state_grid(2), opts.state_grid(3), ...
    opts.gh_n, opts.gh_n^3);
lprintf(LOG_FILE, '%s\n\n', repmat('-',1,65));

%% Main loop
t_wall   = tic;
manifest = {};

for j = 1:numel(jobs)
    st      = jobs(j).strat;
    housing = jobs(j).housing;
    % Grid suffix from the active coordinate system, not from p -- p does not
    % exist yet, and this name is what the resume check below tests. That also
    % means a cube sweep and a simplex sweep resume independently of each
    % other in one output dir, which is the point.
    out_file = fullfile(utility.output_dir(), ...
        sprintf('%s%s_%s%s.mat', prefix, st.name, housing, GRID_SUFFIX));

    if isfile(out_file)
        lprintf(LOG_FILE, 'SKIP   %s  (file exists)\n', out_file);
        continue
    end

    lprintf(LOG_FILE, '\n--- [%d/%d] %s | %s\n', j, numel(jobs), st.name, housing);
    lprintf(LOG_FILE, '    knots: ages [%s]  fracs [%s]\n', ...
        strjoin(compose('%.1f', st.knot_ages), ' '), ...
        strjoin(compose('%.2f', st.knot_fracs), ' '));
    t_sc = tic;

    %% Build params and tau_S override
    p = config.params();
    p.is_owner = strcmp(housing, 'owner');
    p.tau_S    = strategy.spline_tau(p, st.knot_ages, st.knot_fracs);

    % Sweep grids (defaults reduced vs the full model's 40^3 / gh_n=7).
    % build_state_grids rebuilds the linspaces AND re-inserts the welfare
    % anchors, so N_lambda/N_sH come back +2 -- read them off p, never off
    % opts.state_grid.
    p = utility.build_state_grids(p, opts.state_grid, opts.gh_n);

    if SMOKE
        p = utility.build_state_grids(p, [12 12 12], 3);
        p.N_c = 15;  p.N_pi = 15;
    end

    p = assert_production_fill(p);

    idx = @(a) a - p.age0 + 1;  % age -> 1-based index into tau_S
    % A few ages to print the glide value at, derived from p so they stay in
    % range if age0 or the retirement age change.
    diag_ages = unique(max(p.age0, min(p.age0 + p.T - 2, ...
        round([p.age0, (p.age0 + p.retirement_age)/2, p.retirement_age - 1, p.retirement_age]))));
    lprintf(LOG_FILE, '    tau_S: %s\n', strjoin(arrayfun(@(a) ...
        sprintf('age%d=%.2f', a, p.tau_S(idx(a))), diag_ages, 'UniformOutput', false), '  '));

    %% Shared inputs
    [~, mu_growth, sigma_l_log] = config.income_profile(p);
    profile.mu_growth   = mu_growth;
    profile.sigma_l_log = sigma_l_log;
    profile.p_surv      = config.survival(p);
    shocks    = grids.shock_grid(p);
    ann_price = pension.annuity_price(p, profile, shocks);

    %% Solve
    sol = solver.solve(p, profile, shocks, ann_price);
    lprintf(LOG_FILE, '    Solver: %.1f s\n', sol.elapsed);

    %% Welfare summary at the initial state (see utility.welfare_summary):
    %% V(W,state) = W^(1-gamma) * V_tilde(state); all strategies share the
    %% same initial state, so V_tilde there is the exact welfare ranking.
    %% Saved top-level so comparison can matfile-read it without touching sol.
    welfare0 = utility.welfare_summary(p, sol.V(:,:,:,1));
    lprintf(LOG_FILE, '    V_tilde0 = %.6g (corner) | %.6g at b0 | %.6g at b_alt\n', ...
        welfare0.Vt0, welfare0.Vt0_b0, welfare0.Vt0_b_alt);

    %% Simulate
    t_sim = tic;
    sim = simulate.forward(p, profile, sol, ann_price, N_SIM);
    sim_elapsed = toc(t_sim);
    lprintf(LOG_FILE, '    Simulated %d households in %.1f s\n', N_SIM, sim_elapsed);

    %% Diagnostic summary at key ages
    lprintf(LOG_FILE, '    age  meanPi  meanC   meanA   meanH\n');
    for a = [30, 50, 65, 75]
        t = a - p.age0 + 1;
        if t < 1 || t > p.T, continue; end
        lprintf(LOG_FILE, '    %3d  %5.3f  %6.3f  %6.3f  %6.3f\n', ...
            a, mean(sim.pi(:,t)), mean(sim.C(:,t)), mean(sim.A(:,t)), mean(sim.H(:,t)));
    end

    %% Save
    strat_info = struct('name',st.name, 'type','spline', ...
        'knot_ages',st.knot_ages, 'knot_fracs',st.knot_fracs, 'housing',housing);
    timing          = sol.timing;
    timing.sim_sec  = sim_elapsed;
    timing.strategy = st.name;
    timing.housing  = housing;
    sim_summary     = summarise_sim(sim);
    if opts.full_output
        save(out_file, 'p','profile','shocks','ann_price','sol','sim', ...
             'strat_info','timing','welfare0','sim_summary', '-v7.3');
    else
        % Lean: welfare for the ranking, p for the fingerprint and grid, and a
        % life-cycle summary for plotting -- everything compare_spline_strategies
        % reads, without the sol/sim arrays.
        save(out_file, 'p','strat_info','timing','welfare0','sim_summary', '-v7.3');
    end
    elapsed_sc = toc(t_sc);
    lprintf(LOG_FILE, '    Saved %-38s  (%.1f min)\n', out_file, elapsed_sc/60);

    manifest{end+1} = {out_file, st.name, housing, elapsed_sc/60};  %#ok<AGROW>
end

%% Footer
elapsed_total = toc(t_wall);
lprintf(LOG_FILE, '\n%s\n', repmat('=',1,65));
lprintf(LOG_FILE, 'DONE  total wall time: %.1f min  (%d new scenarios)\n', ...
    elapsed_total/60, numel(manifest));
if ~isempty(manifest)
    lprintf(LOG_FILE, 'Completed this session:\n');
    for k = 1:numel(manifest)
        lprintf(LOG_FILE, '  %-42s  %.1f min\n', manifest{k}{1}, manifest{k}{4});
    end
end
lprintf(LOG_FILE, '%s\n\n', repmat('=',1,65));

fprintf('\nLog written to: %s\n', LOG_FILE);
end

%% =======================================================================
function lprintf(log_file, fmt, varargin)
%LPRINTF  Write formatted text to console and append to log file.
    msg = sprintf(fmt, varargin{:});
    fprintf('%s', msg);
    fid = fopen(log_file, 'a');
    if fid >= 0, fprintf(fid, '%s', msg); fclose(fid); end
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end

function s = summarise_sim(sim)
% Compact life-cycle summary: the cross-household mean at each age for the main
% variables, plus a 10/90 band on consumption and equity share. A few vectors
% of length T instead of every simulated path, so a swept strategy can still be
% plotted without carrying the full simulation.
s.ages = sim.ages;
s.N    = size(sim.C, 1);
mean_of = @(f) mean(sim.(f), 1);
for f = ["C","pi","A","H","LW","lambda","disp_inc"]
    if isfield(sim, f), s.("mean_" + f) = mean_of(f); end
end
if isfield(sim, 'tau_A'), s.mean_tau_A = mean(sim.tau_A, 1); end
s.p10_C  = quantile(sim.C,  0.10, 1);
s.p90_C  = quantile(sim.C,  0.90, 1);
s.p10_pi = quantile(sim.pi, 0.10, 1);
s.p90_pi = quantile(sim.pi, 0.90, 1);
end

function p = assert_production_fill(p)
% p.legacy_fill selects an old continuation-fill rule kept only for tests; it
% must be off for a production run. Setting it to false explicitly (rather than
% leaving it absent) is what the fingerprint records.
assert(~(isfield(p, 'legacy_fill') && p.legacy_fill), ...
    'run_spline_strategies:legacy_fill', ...
    'p.legacy_fill is set, which is a test-only continuation fill.');
p.legacy_fill = false;
end
