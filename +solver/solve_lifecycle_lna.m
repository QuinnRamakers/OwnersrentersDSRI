function sol = solve_lifecycle_lna(p, profile, shocks, ann_price)
% SOLVE_LIFECYCLE_LNA  Solve the model by backward induction on the new coordinate system.
% Main wrapper to call the actual backward induction and actually set up everything


% chewck if everything is correct %
assert(isfield(p, 'grid_type') && strcmp(char(p.grid_type), 'lna'), ...
    'solve_lifecycle_lna:grid_type', ...
    'p.grid_type must be ''lna'' to solve on the cube (got ''%s'').', ...
    char(string(getfield_default(p, 'grid_type', 'unset'))));

% DC allocation feasibility: the bond leg 1 - tau_S - tau_REIT must stay
% non-negative. Re-checked here (config.params also checks it) so a tau_REIT
% overridden after params is still caught before it becomes a silent short.
alloc = config.tau_effective(p) + config.reit_effective(p);
assert(all(alloc <= 1 + 1e-12), 'solve_lifecycle_lna:reit_alloc', ...
    'tau_S + tau_REIT exceeds 1 (max %.4f): DC bond leg would go negative.', max(alloc));

% skip_polish bypasses the per-node optimiser: the (c, pi) policy is left at the
% warm-start seed, which freezes pi at the terminal all-bond value. The solve
% still runs, but its policies/simulations/welfare are not valid -- for smoke
% tests only. Warn loudly so a real run never ships on it unnoticed.
if isfield(p, 'skip_polish') && p.skip_polish
    warning('solve_lifecycle_lna:skip_polish', ...
        ['p.skip_polish is TRUE: the per-node optimiser is bypassed and pi is ' ...
         'frozen at the warm-start seed. Policies, simulations and welfare from ' ...
         'this solve are INVALID -- use only for functionality smoke tests.']);
end

%create storage objects
N1 = numel(p.u1_grid); N2 = numel(p.u2_grid); N3 = numel(p.u3_grid); T = p.T;
V      = zeros(N1, N2, N3, T);
c_pol  = zeros(N1, N2, N3, T);
pi_pol = zeros(N1, N2, N3, T);
period_sec = zeros(T, 1);

%start timer
t0 = tic;



% Creat DC account decision storage if free choice is enabled
choose_tau = isfield(p, 'choose_tau_S') && p.choose_tau_S;
if choose_tau
    tau_pol = zeros(N1, N2, N3, T);
end

% Terminal node
t_step = tic;
if choose_tau
    [V(:,:,:,T), c_pol(:,:,:,T), pi_pol(:,:,:,T), tau_pol(:,:,:,T)] = ...
        solver.bellman_step_lna(T, [], p, profile, shocks, ann_price);
else
    [V(:,:,:,T), c_pol(:,:,:,T), pi_pol(:,:,:,T)] = ...
        solver.bellman_step_lna(T, [], p, profile, shocks, ann_price);
end
period_sec(T) = toc(t_step);

% Diagnostic state that gets printed with status updates.
probe_u1 = 0.2; probe_u2 = 0.75; probe_u3 = 1/3;

%backward inductin loop
for t = T-1 : -1 : 1
    t_step = tic;
    % The next period's policy is this step's warm start.
    pol_next = struct('c', c_pol(:,:,:,t+1), 'pi', pi_pol(:,:,:,t+1), 'tau', []);
    %free choice call
    if choose_tau
        pol_next.tau = tau_pol(:,:,:,t+1);
        [V(:,:,:,t), c_pol(:,:,:,t), pi_pol(:,:,:,t), tau_pol(:,:,:,t)] = ...
            solver.bellman_step_lna(t, V(:,:,:,t+1), p, profile, shocks, ann_price, pol_next);
    else 
    %non free choice call
        [V(:,:,:,t), c_pol(:,:,:,t), pi_pol(:,:,:,t)] = ...
            solver.bellman_step_lna(t, V(:,:,:,t+1), p, profile, shocks, ann_price, pol_next);
    end
    period_sec(t) = toc(t_step);
    %status update print
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

%creating the returned objects
sol.V = V; sol.c_pol = c_pol; sol.pi_pol = pi_pol;
if choose_tau, sol.tau_pol = tau_pol; end
sol.grid_type = 'lna';
sol.elapsed = toc(t0);
sol.timing  = struct('period_sec', period_sec, 'total_sec', sol.elapsed, ...
                      'pool', pool_info(), 'hostname', hostname(), ...
                      'timestamp', char(datetime('now')));
end

%parallelisation startup
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
