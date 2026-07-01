function sol = solve_lifecycle(p, profile, shocks, ann_price)
%SOLVE_LIFECYCLE  Backward induction for the combined pension+housing model.
%   State is 3D: (lambda, s_A, s_H). Arrays are NL x NA x NH x T.
%
%   Records per-period wall time and pool/machine metadata in sol.timing so
%   that runs on different hardware (e.g. local machine vs. cluster) can be
%   compared after the fact.

NL = p.N_lambda; NA = p.N_sA; NH = p.N_sH; T = p.T;
V      = zeros(NL, NA, NH, T);
c_pol  = zeros(NL, NA, NH, T);
pi_pol = zeros(NL, NA, NH, T);
period_sec = zeros(T, 1);

t0 = tic;

% Terminal
t_step = tic;
[V(:,:,:,T), c_pol(:,:,:,T), pi_pol(:,:,:,T)] = ...
    solver.bellman_step(T, [], p, profile, shocks, ann_price);
period_sec(T) = toc(t_step);

% Pre-build trilinear interpolants for the probe (single mid-life point)
probe_lam = 0.2; probe_sA = 0.2; probe_sH = 0.4;

for t = T-1 : -1 : 1
    t_step = tic;
    [V(:,:,:,t), c_pol(:,:,:,t), pi_pol(:,:,:,t)] = ...
        solver.bellman_step(t, V(:,:,:,t+1), p, profile, shocks, ann_price);
    period_sec(t) = toc(t_step);
    if mod(t, 10) == 0 || t == T-1 || t == 1
        Fc  = griddedInterpolant({p.lambda_grid, p.sA_grid, p.sH_grid}, ...
                                  fill_nan_nearest_3d(c_pol(:,:,:,t)), 'linear', 'nearest');
        Fpi = griddedInterpolant({p.lambda_grid, p.sA_grid, p.sH_grid}, ...
                                  fill_nan_nearest_3d(pi_pol(:,:,:,t)), 'linear', 'nearest');
        c_mid  = Fc(probe_lam, probe_sA, probe_sH);
        pi_mid = Fpi(probe_lam, probe_sA, probe_sH);
        fprintf('  t=%2d (age %d): c@(lam=%.1f,sA=%.1f,sH=%.1f)=%.4f, pi=%.4f  [%.1f s]\n', ...
                t, p.age0+t-1, probe_lam, probe_sA, probe_sH, c_mid, pi_mid, period_sec(t));
    end
end

sol.V = V; sol.c_pol = c_pol; sol.pi_pol = pi_pol;
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

function Z = fill_nan_nearest_3d(M)
% Replace infeasible-state NaNs with nearest finite value (probe-only helper).
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
