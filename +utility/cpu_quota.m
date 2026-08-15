function n = cpu_quota()
%CPU_QUOTA  Cores this process may actually use, not what the node reports.
%
%   n = utility.cpu_quota()
%
%   Inside a container feature('numcores') sees the whole physical node (e.g.
%   128) while the pod is cgroup-capped far lower (e.g. 32). A parallel pool
%   sized to the node then runs many workers on a handful of real cores --
%   128 fmincon threads (times their BLAS) fighting over 32 cores ran the cube
%   Bellman step ~7x slower on the cluster than a right-sized 10-process pool
%   on a laptop. This reads the cgroup CPU quota so the pool matches the pod.
%
%   Resolution order:
%     1. CGM_N_WORKERS, if set   -- explicit override wins (laptop process pool)
%     2. cgroup v2 cpu.max        -- "<quota> <period>"; cores = quota/period
%     3. cgroup v1 cfs_quota/period
%     4. feature('numcores')      -- off a cluster, or when no quota is set
%
%   A cgroup that says "max" (v2) or -1 (v1) is an unlimited pod; that falls
%   through to feature('numcores'), which is then the right answer.

nw = str2double(getenv('CGM_N_WORKERS'));
if ~isnan(nw) && nw >= 1
    n = max(1, round(nw));
    return
end

n = cgroup_cores();
if isnan(n) || n < 1
    n = feature('numcores');
end
n = max(1, floor(n));
end

function n = cgroup_cores()
% Effective cores from the cgroup CPU quota, or NaN if unlimited/unreadable.
n = NaN;

% cgroup v2: single file "<quota> <period>", or "max <period>" when unlimited.
try
    parts = strsplit(strtrim(fileread('/sys/fs/cgroup/cpu.max')));
    if numel(parts) == 2
        if strcmp(parts{1}, 'max'), return; end   % unlimited -> fall back
        q = str2double(parts{1}); pr = str2double(parts{2});
        if pr > 0 && q > 0, n = q / pr; return; end
    end
catch
end

% cgroup v1: quota and period in separate files; quota -1 means unlimited.
try
    q  = str2double(strtrim(fileread('/sys/fs/cgroup/cpu/cpu.cfs_quota_us')));
    pr = str2double(strtrim(fileread('/sys/fs/cgroup/cpu/cpu.cfs_period_us')));
    if q > 0 && pr > 0, n = q / pr; end
catch
end
end
