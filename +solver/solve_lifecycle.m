function sol = solve_lifecycle(p, profile, shocks, ann_price)
%SOLVE_LIFECYCLE  Backward induction for the combined pension+housing model.
%   State is 3D: (lambda, s_A, s_H). Arrays are NL x NA x NH x T.
%
%   Records per-period wall time and pool/machine metadata in sol.timing so
%   that runs on different hardware (e.g. local machine vs. cluster) can be
%   compared after the fact.

% Mirror of the guard in solve_lifecycle_lna: a p declared for the cube must
% not be solved here, or the saved run would carry an 'lna' tag on a simplex
% solve. Absent field is fine -- p-structs predating the tag are simplex.
if isfield(p, 'grid_type')
    assert(~strcmp(char(p.grid_type), 'lna'), 'solve_lifecycle:grid_type', ...
        'p.grid_type is ''lna'' but this is the simplex solver.');
end

NL = p.N_lambda; NA = p.N_sA; NH = p.N_sH; T = p.T;

% Welfare-anchor guard. The calibrated (b0) and sensitivity (b_alt) initial
% nodes must be EXACT grid members or the headline welfare number becomes a
% trilinear blend that moves with grid resolution. config.params installs them
% via config.insert_anchor_nodes; a run script that rebuilds the grid vectors
% afterwards must call it again. Skipped for legacy p-structs (loaded from an
% old .mat) that predate the anchors.
if all(isfield(p, {'b0', 'b_alt', 'h_mult'}))
    b_a  = [p.b0, p.b_alt];
    name = {'b0', 'b_alt'};
    for a = 1:2
        den = 1 + p.h_mult + b_a(a);
        assert(min(abs(p.lambda_grid - 1/den)) == 0, ...
            'solve_lifecycle:anchor_missing', ...
            ['lambda anchor %.17g (buffer %s = %.6g) is not an exact node of ' ...
             'lambda_grid -- call config.insert_anchor_nodes(p) after rebuilding ' ...
             'the grid vectors.'], 1/den, name{a}, b_a(a));
        assert(min(abs(p.sH_grid - p.h_mult/den)) == 0, ...
            'solve_lifecycle:anchor_missing', ...
            ['s_H anchor %.17g (buffer %s = %.6g) is not an exact node of ' ...
             'sH_grid -- call config.insert_anchor_nodes(p) after rebuilding ' ...
             'the grid vectors.'], p.h_mult/den, name{a}, b_a(a));
    end
end

% Nearest-feasible fill map for the continuation interpolant's infeasible cube
% nodes (solver.build_fill_map: replaces the old global-minimum fill, which put
% a phantom ruin penalty one cell wide along the sX = 0 face). Grid-only, so it
% is built once here and reused by every Bellman step.
p.fill_map = solver.build_fill_map(p.lambda_grid, p.sA_grid, p.sH_grid);

V      = zeros(NL, NA, NH, T);
c_pol  = zeros(NL, NA, NH, T);
pi_pol = zeros(NL, NA, NH, T);
period_sec = zeros(T, 1);

% Free DC investment choice: store the tau policy only in that regime (the
% glide regime has no per-state tau to record -- it is just p.tau_S).
choose_tau = isfield(p, 'choose_tau_S') && p.choose_tau_S;
if choose_tau
    tau_pol = zeros(NL, NA, NH, T);
end

t0 = tic;

% Terminal
t_step = tic;
if choose_tau
    [V(:,:,:,T), c_pol(:,:,:,T), pi_pol(:,:,:,T), ~, tau_pol(:,:,:,T)] = ...
        solver.bellman_step(T, [], p, profile, shocks, ann_price);
else
    [V(:,:,:,T), c_pol(:,:,:,T), pi_pol(:,:,:,T)] = ...
        solver.bellman_step(T, [], p, profile, shocks, ann_price);
end
period_sec(T) = toc(t_step);

% Pre-build trilinear interpolants for the probe (single mid-life point)
probe_lam = 0.2; probe_sA = 0.2; probe_sH = 0.4;

for t = T-1 : -1 : 1
    t_step = tic;
    if choose_tau
        [V(:,:,:,t), c_pol(:,:,:,t), pi_pol(:,:,:,t), ~, tau_pol(:,:,:,t)] = ...
            solver.bellman_step(t, V(:,:,:,t+1), p, profile, shocks, ann_price);
    else
        [V(:,:,:,t), c_pol(:,:,:,t), pi_pol(:,:,:,t)] = ...
            solver.bellman_step(t, V(:,:,:,t+1), p, profile, shocks, ann_price);
    end
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
if choose_tau
    sol.tau_pol = tau_pol;
end
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
