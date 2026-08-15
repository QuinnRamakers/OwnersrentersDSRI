function sol = solve_lifecycle_lna(p, profile, shocks, ann_price)
%SOLVE_LIFECYCLE_LNA  Solve the model by backward induction on the cube grid.
%
%   Steps solver.bellman_step_lna back from the terminal age to age 25 on the
%   (u1, u2, u3) cube, carrying each period's policy forward as the warm start
%   for the previous one. Returns the value function and policies over the full
%   life cycle in sol, with per-period timing.
%
%   The caller must set p.grid_type = 'lna'; the fingerprint records it so cube
%   and simplex runs are never compared against each other.

assert(isfield(p, 'grid_type') && strcmp(char(p.grid_type), 'lna'), ...
    'solve_lifecycle_lna:grid_type', ...
    'p.grid_type must be ''lna'' to solve on the cube (got ''%s'').', ...
    char(string(getfield_default(p, 'grid_type', 'unset'))));

N1 = numel(p.u1_grid); N2 = numel(p.u2_grid); N3 = numel(p.u3_grid); T = p.T;
V      = zeros(N1, N2, N3, T);
c_pol  = zeros(N1, N2, N3, T);
pi_pol = zeros(N1, N2, N3, T);
period_sec = zeros(T, 1);

t0 = tic;

% Under free DC choice the pension equity share is a per-state policy; under
% the glide it is just the fund's fixed path, so there is nothing to store.
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

% A fixed mid-life state printed as a progress probe during the solve.
probe_u1 = 0.2; probe_u2 = 0.75; probe_u3 = 1/3;

for t = T-1 : -1 : 1
    t_step = tic;
    % The next period's policy is this step's warm start.
    pol_next = struct('c', c_pol(:,:,:,t+1), 'pi', pi_pol(:,:,:,t+1), 'tau', []);
    if choose_tau
        pol_next.tau = tau_pol(:,:,:,t+1);
        [V(:,:,:,t), c_pol(:,:,:,t), pi_pol(:,:,:,t), tau_pol(:,:,:,t)] = ...
            solver.bellman_step_lna(t, V(:,:,:,t+1), p, profile, shocks, ann_price, pol_next);
    else
        [V(:,:,:,t), c_pol(:,:,:,t), pi_pol(:,:,:,t)] = ...
            solver.bellman_step_lna(t, V(:,:,:,t+1), p, profile, shocks, ann_price, pol_next);
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
