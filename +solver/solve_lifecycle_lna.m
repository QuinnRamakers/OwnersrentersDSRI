function sol = solve_lifecycle_lna(p, profile, shocks, ann_price, verbose)
%SOLVE_LIFECYCLE_LNA  Backward induction over the life cycle on the cube.
%
%   sol = solver.solve_lifecycle_lna(p, profile, shocks, ann_price)
%   sol = solver.solve_lifecycle_lna(..., verbose)    % false: no progress lines
%
%   Returns sol.V, sol.c_pol and sol.pi_pol, each N_u1 x N_u2 x N_u3 x T, plus
%   timing. Each period's search is warm-started from the next period's policy.

if nargin < 5 || isempty(verbose), verbose = true; end

alloc = config.tau_effective(p) + config.reit_effective(p);
assert(all(alloc <= 1 + 1e-12), 'solve_lifecycle_lna:reit_alloc', ...
    'tau_S + tau_REIT exceeds 1 (max %.4f): the fund bond leg would go negative.', max(alloc));

N1 = numel(p.u1_grid); N2 = numel(p.u2_grid); N3 = numel(p.u3_grid); T = p.T;
V      = zeros(N1, N2, N3, T);
c_pol  = zeros(N1, N2, N3, T);
pi_pol = zeros(N1, N2, N3, T);
period_sec = zeros(T, 1);
t0 = tic;

t_step = tic;
[V(:,:,:,T), c_pol(:,:,:,T), pi_pol(:,:,:,T)] = ...
    solver.bellman_step_lna(T, [], p, profile, shocks, ann_price);
period_sec(T) = toc(t_step);

% A fixed interior state whose policy is printed as the solve progresses.
probe = [0.2, 0.75, 1/3];

for t = T-1 : -1 : 1
    t_step = tic;
    pol_next = struct('c', c_pol(:,:,:,t+1), 'pi', pi_pol(:,:,:,t+1));
    [V(:,:,:,t), c_pol(:,:,:,t), pi_pol(:,:,:,t)] = ...
        solver.bellman_step_lna(t, V(:,:,:,t+1), p, profile, shocks, ann_price, pol_next);
    period_sec(t) = toc(t_step);
    if verbose && (mod(t, 10) == 0 || t == T-1 || t == 1)
        Fc  = griddedInterpolant({p.u1_grid, p.u2_grid, p.u3_grid}, c_pol(:,:,:,t), 'linear', 'nearest');
        Fpi = griddedInterpolant({p.u1_grid, p.u2_grid, p.u3_grid}, pi_pol(:,:,:,t), 'linear', 'nearest');
        fprintf('  t=%2d (age %d): c=%.4f, pi=%.4f at u=(%.2f, %.2f, %.2f)  [%.1f s]\n', ...
                t, p.age0 + t - 1, Fc(probe), Fpi(probe), probe, period_sec(t));
    end
end

sol.V = V; sol.c_pol = c_pol; sol.pi_pol = pi_pol;
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
