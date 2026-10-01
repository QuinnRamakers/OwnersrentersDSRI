function pool = start_pool()
%START_POOL  Open a parallel pool sized to the cores this process may use.
%
%   pool = utility.start_pool()
%
%   The per-node search in solver.bellman_step_lna is a parfor, so a pool is
%   what makes a solve fast; without one it runs serially and gives the same
%   numbers. The pool is sized by utility.cpu_quota, which respects a
%   container's CPU quota: a pool sized to the whole node instead of the quota
%   was measured to run several times slower on the cluster.
%
%   A thread pool by default. Setting CGM_N_WORKERS asks for a process pool of
%   that size instead, falling back to threads if processes fail to start, and
%   pins each worker's BLAS to one thread. An existing pool of the right size
%   is reused; one of another size is replaced.

n = utility.cpu_quota();
pool = gcp('nocreate');
if ~isempty(pool) && pool.NumWorkers ~= n
    delete(pool);
    pool = [];
end
if ~isempty(pool), return; end

if ~isnan(str2double(getenv('CGM_N_WORKERS')))
    try
        clus = parcluster('local');
        clus.NumWorkers = max(clus.NumWorkers, n);
        pool = parpool(clus, n);
        parfevalOnAll(@() maxNumCompThreads(1), 0);
        return
    catch err
        fprintf('Process pool failed (%s); using threads.\n', err.message);
    end
end
try
    pool = parpool('Threads', n);
catch
    try
        pool = parpool('Threads');
    catch err
        warning('start_pool:none', 'No parallel pool (%s); solving serially.', err.message);
        pool = [];
    end
end
end
