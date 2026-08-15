function time_one_strategy(opts)
%TIME_ONE_STRATEGY  Solve+simulate ONE spline strategy to size a cluster sweep.
%
%   time_one_strategy()                       % one strategy, both tenures, active grid
%   time_one_strategy(housing="owner")        % one tenure only
%   setenv('CGM_GRID','simplex'); time_one_strategy()   % time the simplex grid
%
%   Runs a single strategy from strategy.menu() on the SAME production grid
%   run_cluster_sweep would use -- it reads utility.production_grid() and lets
%   run_spline_strategies pick the grid up itself, so passing NO grid override
%   here guarantees the timing matches the real sweep. Which grid that is
%   depends on CGM_GRID: the LNA cube [28 20 20]/gh_n=7 by default (~11,200
%   live states), or the simplex [25 15 15]/gh_n=5 (~940). Time whichever one
%   you intend to launch the sweep on -- the two are an order of magnitude
%   apart, so a simplex timing does NOT size a cube sweep.
%
%   Writes its .mat to a scratch dir (tempdir) and deletes it afterwards, so
%   it neither pollutes the real sweep output dir nor counts as a done job,
%   and the timing is repeatable.

arguments
    opts.housing (1,1) string {mustBeMember(opts.housing,["renter","owner","both"])} = "both"
    opts.n_sim   (1,1) double {mustBePositive} = 5000
end

M       = strategy.menu();            % 165-strategy production menu
st      = M(ceil(numel(M)/2));        % a representative mid-menu glide path
n_strat = numel(M);
[dims, gh_n] = utility.production_grid();   % report the grid we are timing

% Redirect output to a scratch dir so we don't touch the real sweep outputs,
% and so re-running the timer actually re-solves (run_spline_strategies skips
% existing files).
old_dir = getenv('CGM_OUTPUT_DIR');
tmp_dir = fullfile(tempdir, 'cgm_timing');
if ~isfolder(tmp_dir), mkdir(tmp_dir); end
setenv('CGM_OUTPUT_DIR', tmp_dir);
restore = onCleanup(@() setenv('CGM_OUTPUT_DIR', old_dir));
delete(fullfile(tmp_dir, '*.mat'));   % ensure a cold solve

fprintf('Timing 1 strategy "%s" (%s) on grid %s [%d %d %d], gh_n=%d ...\n', ...
    st.name, opts.housing, utility.active_grid(), dims(1), dims(2), dims(3), gh_n);

t = tic;
run_spline_strategies(st, housing=opts.housing, n_sim=opts.n_sim);
sec = toc(t);

delete(fullfile(tmp_dir, '*.mat'));   % leave no trace

per     = 1 + (opts.housing == "both");   % jobs solved this call
per_job = sec / per;                       % one strategy x one tenure
n_jobs  = 2 * n_strat;                      % full menu, both tenures

fprintf('\n=================  timing  =================\n');
fprintf('grid                      : %s [%d %d %d], gh_n=%d\n', ...
    utility.active_grid(), dims(1), dims(2), dims(3), gh_n);
fprintf('one strategy, housing=%s : %.1f min (%.0f s)\n', opts.housing, sec/60, sec);
fprintf('per job (1 tenure)        : %.1f min\n', per_job/60);
fprintf('full sweep                : %d strat x 2 tenures = %d jobs\n', n_strat, n_jobs);
fprintf('projected wall, 1 instance: %.1f h  (serial)\n', per_job*n_jobs/3600);
fprintf('  split over 4 instances   : %.1f h each\n', per_job*n_jobs/3600/4);
fprintf('  split over 8 instances   : %.1f h each\n', per_job*n_jobs/3600/8);
fprintf('===========================================\n');
end
