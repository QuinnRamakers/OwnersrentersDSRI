function run_cluster_sweep(opts)
%RUN_CLUSTER_SWEEP  Solve the full spline-strategy sweep on a cluster.
%
%   run_cluster_sweep()                          % full menu, both tenures
%   run_cluster_sweep(max_hours=336)             % stop gracefully after 14 days
%   run_cluster_sweep(levels=0:0.1:1)            % a finer strategy grid
%   run_cluster_sweep(housing="owner")           % one tenure only
%
%   Runs strategy.menu() over both housing types on the production grid, one
%   strategy at a time, saving each result before starting the next. This is a
%   thin driver around run_spline_strategies; all it adds is a wall-clock budget
%   and progress reporting so it can be launched once and left running.
%
%   Resumable. Every completed scenario is written to its own file and skipped
%   on a later call, so if the job is interrupted -- a node dies, the wall-clock
%   limit is hit, the process is requeued -- just call run_cluster_sweep again
%   with the same output directory and it continues where it stopped.
%
%   Options:
%     levels    knot-fraction grid passed to strategy.menu (default 0:0.125:1,
%               the 165-strategy production menu). A finer grid gives more
%               strategies and a longer run.
%     housing   "renter" | "owner" | "both" (default "both").
%     max_hours wall-clock budget in hours (default 336 = 14 days). The driver
%               stops between strategies once this is reached, so no partial
%               result is ever left half-written.
%     n_sim     simulated households per scenario (default 5000).
%
%   Cluster setup:
%     - Set CGM_OUTPUT_DIR to a mounted volume so results survive a restart.
%     - Leave CGM_N_WORKERS unset on the pod; the Threads pool spans all cores.
%       On a laptop set it to a process-pool size (e.g. 10).
%     - CGM_GRID selects the coordinate system (the cube by default).
%
%   Combine the results by pointing compare_spline_strategies at the output
%   directory once the sweep is done (or at any time, on whatever has finished).

arguments
    opts.levels   (1,:) double = 0:0.125:1
    opts.housing  (1,1) string {mustBeMember(opts.housing, ["renter","owner","both"])} = "both"
    opts.max_hours(1,1) double {mustBePositive} = 336
    opts.n_sim    (1,1) double {mustBePositive} = 5000
end

grid_type  = utility.active_grid();
[dims, gh] = utility.production_grid();
out_dir    = utility.output_dir();
suffix     = utility.grid_suffix();

M       = strategy.menu(opts.levels);
n_strat = numel(M);
per     = 1 + (opts.housing == "both");
n_jobs  = n_strat * per;

fprintf('\n==================  run_cluster_sweep  ==================\n');
fprintf('grid        : %s, state %dx%dx%d, gh_n=%d\n', grid_type, dims(1), dims(2), dims(3), gh);
fprintf('strategies  : %d  (levels %s)\n', n_strat, mat2str(opts.levels));
fprintf('housing     : %s  ->  %d jobs total\n', opts.housing, n_jobs);
fprintf('output dir  : %s\n', out_dir);
fprintf('wall budget : %.0f h\n', opts.max_hours);
fprintf('already done: %d / %d jobs\n', count_done(M, opts.housing, out_dir, suffix), n_jobs);
fprintf('========================================================\n\n');

t0 = tic;
for i = 1:n_strat
    if toc(t0) / 3600 >= opts.max_hours
        fprintf('Wall budget reached after %.1f h. Stopping between strategies; ', toc(t0)/3600);
        fprintf('call run_cluster_sweep again to resume.\n');
        break
    end

    run_spline_strategies(M(i), housing = opts.housing, n_sim = opts.n_sim);

    done    = count_done(M, opts.housing, out_dir, suffix);
    elapsed = toc(t0) / 3600;
    if done > 0
        eta = elapsed / done * (n_jobs - done);
        fprintf('>> progress %d/%d jobs  |  %.1f h elapsed  |  ~%.1f h remaining\n\n', ...
            done, n_jobs, elapsed, eta);
    end
end

done = count_done(M, opts.housing, out_dir, suffix);
fprintf('\nSession finished: %d / %d jobs complete in %.1f h.\n', done, n_jobs, toc(t0)/3600);
if done < n_jobs
    fprintf('Resume the rest by calling run_cluster_sweep again.\n');
else
    fprintf('Sweep complete. Rank it with compare_spline_strategies.\n');
end
end

function d = count_done(M, housing, out_dir, suffix)
% Count scenarios already on disk, so progress and resume reflect real files.
if housing == "both", H = {'renter', 'owner'}; else, H = {char(housing)}; end
d = 0;
for i = 1:numel(M)
    for h = 1:numel(H)
        f = fullfile(out_dir, sprintf('%s_%s%s.mat', M(i).name, H{h}, suffix));
        d = d + isfile(f);
    end
end
end
