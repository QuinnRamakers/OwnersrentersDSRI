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
%     gh_n       : Gauss-Hermite nodes per shock dimension (default 5 ->
%                  125 joint nodes; the full-model production value is 7)
%     state_grid : [N_lambda N_sA N_sH] (default [25 15 15]; lambda is
%                  empirically the steepest policy axis, hence upweighted --
%                  same reasoning as the lna grid design in config.params).
%                  The full-model production grid is [40 40 40].
%     smoke      : true -> even coarser grids + 200 households, smoke_ file
%                  prefix; end-to-end plumbing check in minutes, NOT results.
%   All sweep runs must share gh_n/state_grid -- welfare rankings are only
%   comparable across runs solved on identical grids (compare with the
%   defaults everywhere, or pass the same overrides everywhere).
%
%   Output files:  {strategy}_{renter|owner}.mat, e.g. spl_100_050_000_owner.mat.
%   Each file carries a small top-level `welfare0` summary (V_tilde at the
%   initial state) so compare_spline_strategies can rank runs without
%   loading the big sol/sim arrays.
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
    opts.gh_n    (1,1) double {mustBeInteger, mustBePositive} = 5
    opts.state_grid (1,3) double {mustBeInteger, mustBePositive} = [25 15 15]
    opts.smoke   (1,1) logical = false
end

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

%% Job list: housing-major
jobs = struct('strat', {}, 'housing', {});
for hi = 1:numel(HOUSING)
    for si = 1:numel(strats)
        jobs(end+1) = struct('strat', strats(si), 'housing', HOUSING{hi}); %#ok<AGROW>
    end
end

%% Parallel pool (start once, reused across all runs)
nw = str2double(getenv('CGM_N_WORKERS'));
if ~isnan(nw) && nw >= 1
    pool = gcp('nocreate');
    if isempty(pool) || pool.NumWorkers < nw
        if ~isempty(pool), delete(pool); end
        try
            clus = parcluster('local');
            clus.NumWorkers = max(clus.NumWorkers, nw);
            parpool(clus, nw);
        catch err
            % Cluster pods can fail to start process workers; Threads spans
            % all cores in one process and handles fmincon fine.
            fprintf('Process pool failed (%s); falling back to Threads.\n', err.message);
            parpool('Threads');
        end
    end
elseif isempty(gcp('nocreate'))
    try
        parpool('Threads');
    catch
        try, parpool('local'); catch, warning('parpool failed; running serial'); end
    end
end

%% Log header
lprintf(LOG_FILE, '\n%s\n', repmat('=',1,65));
lprintf(LOG_FILE, 'run_spline_strategies  start: %s%s\n', ...
    datestr(now, 'yyyy-mm-dd HH:MM:SS'), ternary(SMOKE, '  [SMOKE MODE]', ''));
lprintf(LOG_FILE, 'This call: %d strategies x %s = %d jobs  (%s ... %s)\n', ...
    numel(strats), strjoin(HOUSING, '+'), numel(jobs), ...
    strats(1).name, strats(end).name);
lprintf(LOG_FILE, 'Grids: state %dx%dx%d, gh_n=%d (%d joint nodes)\n', ...
    opts.state_grid(1), opts.state_grid(2), opts.state_grid(3), ...
    opts.gh_n, opts.gh_n^3);
lprintf(LOG_FILE, '%s\n\n', repmat('-',1,65));

%% Main loop
t_wall   = tic;
manifest = {};

for j = 1:numel(jobs)
    st      = jobs(j).strat;
    housing = jobs(j).housing;
    out_file = fullfile(utility.output_dir(), sprintf('%s%s_%s.mat', prefix, st.name, housing));

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

    % Sweep grids (defaults reduced vs the full model's 40^3 / gh_n=7)
    p.gh_n     = opts.gh_n;
    p.N_lambda = opts.state_grid(1);
    p.N_sA     = opts.state_grid(2);
    p.N_sH     = opts.state_grid(3);
    p.lambda_grid = linspace(0, 1, p.N_lambda).';
    p.sA_grid     = linspace(0, 1, p.N_sA).';
    p.sH_grid     = linspace(0, 1, p.N_sH).';

    if SMOKE
        p.gh_n     = 3;
        p.N_lambda = 12;  p.N_sA = 12;  p.N_sH = 12;
        p.lambda_grid = linspace(0, 1, p.N_lambda).';
        p.sA_grid     = linspace(0, 1, p.N_sA).';
        p.sH_grid     = linspace(0, 1, p.N_sH).';
        p.N_c = 15;  p.N_pi = 15;
    end

    idx = @(a) a - p.age0 + 1;  % age -> 1-based index into tau_S
    lprintf(LOG_FILE, '    tau_S: age20=%.2f  age40=%.2f  age64=%.2f  age66=%.2f\n', ...
        p.tau_S(idx(20)), p.tau_S(idx(40)), p.tau_S(idx(64)), p.tau_S(idx(66)));

    %% Shared inputs
    [~, mu_growth, sigma_l_log] = config.income_profile(p);
    profile.mu_growth   = mu_growth;
    profile.sigma_l_log = sigma_l_log;
    profile.p_surv      = config.survival(p);
    shocks    = grids.shock_grid(p);
    ann_price = pension.annuity_price(p, profile, shocks);

    %% Solve
    sol = solver.solve_lifecycle(p, profile, shocks, ann_price);
    lprintf(LOG_FILE, '    Solver: %.1f s\n', sol.elapsed);

    %% Welfare summary at the initial state (see welfare_dc_strategies.m):
    %% V(W,state) = W^(1-gamma) * V_tilde(state); all strategies share the
    %% same initial state, so V_tilde there is the exact welfare ranking.
    %% Saved top-level so comparison can matfile-read it without touching sol.
    lam0 = 1 / (1 + p.h_mult);
    sH0  = p.h_mult / (1 + p.h_mult);
    V0f  = fill_nan_nearest_3d(sol.V(:,:,:,1));
    Fv   = griddedInterpolant({p.lambda_grid, p.sA_grid, p.sH_grid}, ...
                              V0f, 'linear', 'nearest');
    welfare0 = struct('Vt0', Fv(lam0, 0, sH0), 'lam0', lam0, 'sA0', 0, ...
                      'sH0', sH0, 'gamma', p.gamma);
    lprintf(LOG_FILE, '    V_tilde0 = %.6g\n', welfare0.Vt0);

    %% Simulate
    t_sim = tic;
    sim = simulate.paths(p, profile, sol, ann_price, N_SIM);
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
    save(out_file, 'p','profile','shocks','ann_price','sol','sim', ...
         'strat_info','timing','welfare0', '-v7.3');
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

function Z = fill_nan_nearest_3d(M)
% Replace infeasible-state NaNs with nearest finite value (same helper as
% welfare_dc_strategies.m -- the initial state sits exactly on the
% feasibility boundary, so 'linear' interpolation would pick up a NaN corner).
Z = M;
if ~any(isnan(Z(:))), return; end
[NL, NA, NH] = size(Z);
mask_ok = ~isnan(Z);
[Ig, Jg, Kg] = ndgrid(1:NL, 1:NA, 1:NH);
I_ok = Ig(mask_ok); J_ok = Jg(mask_ok); K_ok = Kg(mask_ok); V_ok = Z(mask_ok);
I_bad = Ig(~mask_ok); J_bad = Jg(~mask_ok); K_bad = Kg(~mask_ok);
for k = 1:numel(I_bad)
    di = I_bad(k) - I_ok; dj = J_bad(k) - J_ok; dk = K_bad(k) - K_ok;
    d2 = di.*di + dj.*dj + dk.*dk;
    [~, q] = min(d2);
    Z(I_bad(k), J_bad(k), K_bad(k)) = V_ok(q);
end
end
