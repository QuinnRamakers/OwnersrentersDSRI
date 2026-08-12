function sol = solve_lifecycle_lna(p, profile, shocks, ann_price)
%SOLVE_LIFECYCLE_LNA  Backward induction on the (u1,u2,u3) cube grid.
%   Reparametrized state (see solver.bellman_step_lna):
%       u1 = lambda,  u2 = (A+H)/(W-Y),  u3 = A/(A+H)
%   Arrays are N1 x N2 x N3 x T on {p.u1_grid, p.u2_grid, p.u3_grid}.
%   Every cube point is feasible, so unlike solve_lifecycle there is no
%   NaN-filling for the probe interpolants.
%
%   Records per-period wall time and pool/machine metadata in sol.timing.
%
%   The caller must declare p.grid_type = 'lna'. config.params defaults it to
%   'simplex' and utility.param_fingerprint records it, so a cube solve that
%   left the default in place would be labelled a simplex run and would pass
%   the comparability gate against one. Asserted rather than stamped, because
%   p is passed by value and the caller is what gets saved.

assert(isfield(p, 'grid_type') && strcmp(char(p.grid_type), 'lna'), ...
    'solve_lifecycle_lna:grid_type', ...
    ['p.grid_type must be ''lna'' to solve on the cube (got ''%s''). It is ' ...
     'what utility.param_fingerprint uses to keep cube runs from rating as ' ...
     'welfare-comparable to simplex runs.'], ...
    char(string(getfield_default(p, 'grid_type', 'unset'))));

N1 = numel(p.u1_grid); N2 = numel(p.u2_grid); N3 = numel(p.u3_grid); T = p.T;
V      = zeros(N1, N2, N3, T);
c_pol  = zeros(N1, N2, N3, T);
pi_pol = zeros(N1, N2, N3, T);
period_sec = zeros(T, 1);

t0 = tic;

% Free DC investment choice: store the per-state tau policy only in that
% regime (the glide regime has no per-state tau to record -- it is p.tau_S).
choose_tau = isfield(p, 'choose_tau_S') && p.choose_tau_S;
if choose_tau
    tau_pol = zeros(N1, N2, N3, T);
end

% Terminal
t_step = tic;
if choose_tau
    [V(:,:,:,T), c_pol(:,:,:,T), pi_pol(:,:,:,T), tau_pol(:,:,:,T)] = ...
        solver.bellman_step_lna(T, [], p, profile, shocks, ann_price);
else
    [V(:,:,:,T), c_pol(:,:,:,T), pi_pol(:,:,:,T)] = ...
        solver.bellman_step_lna(T, [], p, profile, shocks, ann_price);
end
period_sec(T) = toc(t_step);

% Probe: same mid-life simplex point as solve_lifecycle, converted to u:
% (lam, sA, sH) = (0.2, 0.2, 0.4)  ->  u1 = 0.2, u2 = 0.6/0.8, u3 = 0.2/0.6
probe_u1 = 0.2; probe_u2 = 0.75; probe_u3 = 1/3;

for t = T-1 : -1 : 1
    t_step = tic;
    if choose_tau
        [V(:,:,:,t), c_pol(:,:,:,t), pi_pol(:,:,:,t), tau_pol(:,:,:,t)] = ...
            solver.bellman_step_lna(t, V(:,:,:,t+1), p, profile, shocks, ann_price);
    else
        [V(:,:,:,t), c_pol(:,:,:,t), pi_pol(:,:,:,t)] = ...
            solver.bellman_step_lna(t, V(:,:,:,t+1), p, profile, shocks, ann_price);
    end
    period_sec(t) = toc(t_step);
    if mod(t, 10) == 0 || t == T-1 || t == 1
        Fc  = griddedInterpolant({p.u1_grid, p.u2_grid, p.u3_grid}, ...
                                  c_pol(:,:,:,t), 'linear', 'nearest');
        Fpi = griddedInterpolant({p.u1_grid, p.u2_grid, p.u3_grid}, ...
                                  pi_pol(:,:,:,t), 'linear', 'nearest');
        c_mid  = Fc(probe_u1, probe_u2, probe_u3);
        pi_mid = Fpi(probe_u1, probe_u2, probe_u3);
        fprintf('  t=%2d (age %d): c@(u1=%.2f,u2=%.2f,u3=%.2f)=%.4f, pi=%.4f  [%.1f s]\n', ...
                t, p.age0+t-1, probe_u1, probe_u2, probe_u3, c_mid, pi_mid, period_sec(t));
    end
end

sol.V = V; sol.c_pol = c_pol; sol.pi_pol = pi_pol;
if choose_tau, sol.tau_pol = tau_pol; end
sol.grid_type = 'lna';
sol.elapsed = toc(t0);
sol.timing  = struct('period_sec', period_sec, 'total_sec', sol.elapsed, ...
                      'pool', pool_info(), 'hostname', hostname(), ...
                      'timestamp', char(datetime('now')));
end

function info = pool_info()
pool = gcp('nocreate');
if isempty(pool)
    info = struct('type', 'none', 'num_workers', 1);
else
    info = struct('type', class(pool), 'num_workers', pool.NumWorkers);
end
end

function name = hostname()
try
    [~, name] = system('hostname');
    name = strtrim(name);
catch
    name = 'unknown';
end
end

function v = getfield_default(s, f, d)
% Scalar-safe field read for the assert message above.
v = d;
if isfield(s, f) && (ischar(s.(f)) || isstring(s.(f))), v = s.(f); end
end
