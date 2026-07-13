% PROTO_LNA_OVERNIGHT  Convergence-ladder arbiter: simplex vs lna grid.
%
%   Refines BOTH grid systems past production resolution and reports, per
%   arm, the age-20 certainty-equivalent per unit wealth z0 at the EXACT
%   initial state (X=A=0, H=h_mult*Y0) -- the state welfare CEVs are read
%   from -- plus policy/CE diffs at common visited states. The system whose
%   ladder stops moving is the converged one.
%
%   Background (2026-07-13 validation): the two systems agree to 0.02% CE
%   one step from terminal and their policies converge toward each other
%   with grid refinement, but the simplex arm's VALUE LEVEL keeps drifting
%   as its grid refines (z_min fill contaminates every interpolation cell
%   on the sX=0 boundary, where households start life), reaching a ~2.5x
%   CE gap at young ages vs the lna arm at production resolution.
%
%   Arms (solved in this order so a crash keeps the cheap steps; each sol
%   is saved to proto_on_<name>.mat in CGM_OUTPUT_DIR immediately and
%   reused on restart after a params check):
%     lna_28x20x20   reused from combined_renter_lna.mat if present
%     simplex_40     reused from combined_renter.mat if present
%     lna_40x28x28   ~1.6 h at 64 workers
%     simplex_52     ~1.4 h at 64 workers (polish always on)
%     lna_56x40x40   ~4.5 h at 64 workers   <- reference arm
%
%   Pod usage (after bootstrap_pod):
%     setenv('CGM_OUTPUT_DIR','/Solutionstorage');   % PV with the .mat files
%     setenv('PROTO_N_WORKERS','64');
%     proto_lna_overnight
%
%   Renter scenario only -- the grid question is scenario-independent.
%   All params built fresh from config.params(); stored .mat sols are only
%   reused after a field-by-field params + grid equality check.

clear; clc;

nw = str2double(getenv('PROTO_N_WORKERS'));
if isnan(nw) || nw < 1, nw = feature('numcores'); end
pool = gcp('nocreate');
if isempty(pool) || pool.NumWorkers ~= nw || isa(pool, 'parallel.ThreadPool')
    if ~isempty(pool), delete(pool); end
    clus = parcluster('local');
    clus.NumWorkers = max(clus.NumWorkers, nw);
    parpool(clus, nw);
end
out_dir = utility.output_dir();

p_base = config.params(); p_base.is_owner = false;
[~, mu_growth, sigma_l_log] = config.income_profile(p_base);
profile.mu_growth   = mu_growth;
profile.sigma_l_log = sigma_l_log;
profile.p_surv      = config.survival(p_base);
shocks    = grids.shock_grid(p_base);
ann_price = pension.annuity_price(p_base, profile, shocks);
fprintf('=== proto_lna_overnight: %d workers, gamma=%g, mu_S=%g ===\n', ...
        nw, p_base.gamma, p_base.mu_S_level);

% arm spec: {name, type, dims, reuse_file}
arm_spec = { ...
  'lna_28x20x20', 'lna',     [28 20 20], 'combined_renter_lna.mat'; ...
  'simplex_40',   'simplex', [40 40 40], 'combined_renter.mat';     ...
  'lna_40x28x28', 'lna',     [40 28 28], '';                        ...
  'simplex_52',   'simplex', [52 52 52], '';                        ...
  'lna_56x40x40', 'lna',     [56 40 40], ''                         };
n_arm = size(arm_spec, 1);

arms = struct('name', {}, 'type', {}, 'p', {}, 'sol', {}, 'sim', {});
for a = 1:n_arm
    name = arm_spec{a,1}; typ = arm_spec{a,2}; dims = arm_spec{a,3};
    p = make_arm_params(p_base, typ, dims);
    sol = try_reuse(fullfile(out_dir, ['proto_on_' name '.mat']), p, typ);
    if isempty(sol) && ~isempty(arm_spec{a,4})
        sol = try_reuse(fullfile(out_dir, arm_spec{a,4}), p, typ);
    end
    if isempty(sol)
        fprintf('\n--- solving %s (%s, %dx%dx%d) ---\n', name, typ, dims);
        if strcmp(typ, 'lna')
            sol = solver.solve_lifecycle_lna(p, profile, shocks, ann_price);
        else
            sol = solver.solve_lifecycle(p, profile, shocks, ann_price);
        end
        save(fullfile(out_dir, ['proto_on_' name '.mat']), 'p', 'sol', '-v7.3');
        fprintf('%s solved in %.0f s, saved.\n', name, sol.elapsed);
    else
        fprintf('%s: reusing stored solution.\n', name);
    end
    arms(a) = struct('name', name, 'type', typ, 'p', p, 'sol', sol, 'sim', []);
end

% ------------------------------------------------------------- simulate --
N_sim = 5000;
for a = 1:n_arm
    if strcmp(arms(a).type, 'lna')
        arms(a).sim = simulate.paths_lna(arms(a).p, profile, arms(a).sol, ann_price, N_sim);
    else
        arms(a).sim = simulate.paths(arms(a).p, profile, arms(a).sol, ann_price, N_sim);
    end
end
for a = 2:n_arm   % exogenous invariant across every pair
    d = max([max(abs(arms(1).sim.Y(:) - arms(a).sim.Y(:))), ...
             max(abs(arms(1).sim.A(:) - arms(a).sim.A(:))), ...
             max(abs(arms(1).sim.H(:) - arms(a).sim.H(:)))]);
    assert(d == 0, 'invariant violated between %s and %s', arms(1).name, arms(a).name);
end
fprintf('\ninvariant OK: exogenous paths bit-identical across all %d arms.\n', n_arm);

% ------------------------------------- headline: z0 at the initial state --
% Initial state: X=A=0, H=h_mult*Y0 => lam0 = 1/(1+h_mult), sH0 = h_mult/(1+h_mult)
% (u1 = lam0, u2 = 1, u3 = 0). This is the state CEV welfare reads V from.
gamma = p_base.gamma; omg = 1 - gamma;
lam0 = 1 / (1 + p_base.h_mult); sH0 = p_base.h_mult / (1 + p_base.h_mult);
fprintf('\n=== z0 = age-20 CE per unit wealth at the initial state (welfare anchor) ===\n');
z0 = zeros(n_arm, 1);
for a = 1:n_arm
    Fz = z_interp_arm(arms(a), 1, omg);
    if strcmp(arms(a).type, 'lna'), z0(a) = Fz(lam0, 1, 0);
    else,                           z0(a) = Fz(lam0, 0, sH0); end
    fprintf('  %-14s z0 = %.5f\n', arms(a).name, z0(a));
end
i_ref = n_arm;   % lna_56x40x40
fprintf('ladders (CEV-equivalent %% gap vs %s):\n', arms(i_ref).name);
for a = 1:n_arm
    fprintf('  %-14s %+7.2f%%\n', arms(a).name, 100*(z0(a)/z0(i_ref) - 1));
end

% --------------------- diffs vs reference arm at its own visited states --
ages_probe = [25, 30, 50, 75];
fprintf('\n=== vs %s at its visited states: INTERIOR sX>=0.15 | BOUNDARY sX<0.05 ===\n', arms(i_ref).name);
for a = 1:n_arm-1
    fprintf('--- %s ---\n  age   mean|dc|  mean|dpi|  mean|dz/z| | bnd mean|dc|  mean|dpi|  mean|dz/z|\n', arms(a).name);
    for ag = ages_probe
        t = ag - p_base.age0 + 1;
        lam = arms(i_ref).sim.lambda(:,t); sA = arms(i_ref).sim.sA(:,t); sH = arms(i_ref).sim.sH(:,t);
        sX = 1 - lam - sA - sH;
        im = sX >= 0.15; bm = sX < 0.05;
        [cR, pR, zR] = eval_arm(arms(i_ref), t, omg, lam, sA, sH);
        [cA, pA, zA] = eval_arm(arms(a),     t, omg, lam, sA, sH);
        dc = abs(cA - cR); dp = abs(pA - pR); dz = abs(zA./zR - 1);
        fprintf('  %3d  %9.4f  %9.4f  %10.4f | %9.4f  %9.4f  %10.4f\n', ag, ...
            mean(dc(im)), mean(dp(im)), mean(dz(im)), ...
            mean(dc(bm)), mean(dp(bm)), mean(dz(bm)));
    end
end

% ------------------------------------------------------------ moments ----
fprintf('\n=== sim moments per arm: mean c_frac / mean X at ages 30|50|65 ===\n');
for a = 1:n_arm
    s = arms(a).sim; v = zeros(3,2);
    agv = [30 50 65];
    for i = 1:3
        t = agv(i) - p_base.age0 + 1;
        v(i,:) = [mean(s.c_frac(:,t)), mean(s.X(:,t))];
    end
    fprintf('  %-14s c: %.3f|%.3f|%.3f   X: %6.2f|%6.2f|%6.2f\n', ...
            arms(a).name, v(1,1), v(2,1), v(3,1), v(1,2), v(2,2), v(3,2));
end

sims = {arms.sim}; ps = {arms.p}; names = {arms.name};
save(fullfile(out_dir, 'proto_lna_overnight_results.mat'), ...
     'names', 'ps', 'sims', 'z0', 'N_sim', '-v7.3');
fprintf('\nDone. z0 ladder + sims saved to proto_lna_overnight_results.mat\n');
fprintf('Verdict guide: the converged system is the one whose z0 ladder step is\n');
fprintf('near zero; if simplex_52 moved toward the lna arms while lna steps are\n');
fprintf('small, adopt the lna grid for all results (incl. welfare CEVs).\n');

% -------------------------------------------------------- local functions --
function p = make_arm_params(p_base, typ, dims)
p = p_base;
if strcmp(typ, 'lna')
    p.N_u1 = dims(1); p.N_u2 = dims(2); p.N_u3 = dims(3);
    p.u1_grid = linspace(0, 1, dims(1)).';
    p.u2_grid = linspace(0, 1, dims(2)).';
    p.u3_grid = linspace(0, 1, dims(3)).';
    p.skip_polish = false;
else
    p.N_lambda = dims(1); p.N_sA = dims(2); p.N_sH = dims(3);
    p.lambda_grid = linspace(0, 1, dims(1)).';
    p.sA_grid     = linspace(0, 1, dims(2)).';
    p.sH_grid     = linspace(0, 1, dims(3)).';
end
end

function sol = try_reuse(fname, p_want, typ)
% Reuse a stored solution only if economic params AND the grid match the
% fresh config exactly -- stored .mat files can embed stale calibrations.
sol = [];
if ~isfile(fname), return; end
try
    S = load(fname, 'p', 'sol');
catch
    return
end
fk = {'gamma','beta','chi','kappa','delta','replacement','r','mu_S_level', ...
      'sigma_S_level','mu_H_level','sigma_H_level','tau_inc','tau_cg_bond', ...
      'tau_cg_stock','alpha','theta','h_mult','r_m','N_mort','sigma_l_log', ...
      'corr_SL','corr_HL','corr_SH','gh_n','is_owner'};
for i = 1:numel(fk)
    if ~isfield(S.p, fk{i}) || ~isequal(S.p.(fk{i}), p_want.(fk{i}))
        fprintf('  (%s: param %s differs -- not reusing)\n', fname, fk{i});
        return
    end
end
if strcmp(typ, 'lna')
    ok = isfield(S.p, 'u1_grid') && isequal(S.p.u1_grid, p_want.u1_grid) && ...
         isequal(S.p.u2_grid, p_want.u2_grid) && isequal(S.p.u3_grid, p_want.u3_grid);
else
    ok = isequal(S.p.lambda_grid, p_want.lambda_grid) && ...
         isequal(S.p.sA_grid, p_want.sA_grid) && isequal(S.p.sH_grid, p_want.sH_grid);
end
if ok, sol = S.sol; else, fprintf('  (%s: grid differs -- not reusing)\n', fname); end
end

function Fz = z_interp_arm(arm, t, omg)
V = arm.sol.V(:,:,:,t);
z = omg*V; z(z <= 0) = NaN; z = z.^(1/omg);
zmin = min(z(isfinite(z)), [], 'all'); z(~isfinite(z)) = zmin;
Fz = griddedInterpolant(grid_of(arm), z, 'linear', 'linear');
end

function [c, pi_, z] = eval_arm(arm, t, omg, lam, sA, sH)
% Evaluate an arm's policies and z at simplex-coordinate query points.
persistent fill_cache
if isempty(fill_cache), fill_cache = containers.Map; end
if strcmp(arm.type, 'lna')
    sAH = sA + sH;
    q1 = min(max(lam, 0), 1);
    q2 = min(max(sAH ./ max(1 - lam, 1e-12), 0), 1);
    q3 = min(max(sA ./ max(sAH, 1e-12), 0), 1);
    C = arm.sol.c_pol(:,:,:,t); P = arm.sol.pi_pol(:,:,:,t);
else
    q1 = lam; q2 = sA; q3 = sH;
    % The nearest-feasible fill map is O(n_bad * n_feas) to build (minutes
    % at 52^3) and depends only on the arm's grid -- cache it per arm name.
    if fill_cache.isKey(arm.name)
        m = fill_cache(arm.name); bad_lin = m{1}; nn_lin = m{2};
    else
        mask_ok = ~isnan(arm.sol.c_pol(:,:,:,1));
        [bad_lin, nn_lin] = nan_fill_map(mask_ok);
        fill_cache(arm.name) = {bad_lin, nn_lin};
    end
    C = apply_fill(arm.sol.c_pol(:,:,:,t), bad_lin, nn_lin);
    P = apply_fill(arm.sol.pi_pol(:,:,:,t), bad_lin, nn_lin);
end
g   = grid_of(arm);
Fc  = griddedInterpolant(g, C, 'linear', 'nearest');
Fp  = griddedInterpolant(g, P, 'linear', 'nearest');
Fz  = z_interp_arm(arm, t, omg);
c   = min(max(Fc(q1, q2, q3), 0), 1);
pi_ = min(max(Fp(q1, q2, q3), 0), 1);
z   = Fz(q1, q2, q3);
end

function g = grid_of(arm)
if strcmp(arm.type, 'lna')
    g = {arm.p.u1_grid, arm.p.u2_grid, arm.p.u3_grid};
else
    g = {arm.p.lambda_grid, arm.p.sA_grid, arm.p.sH_grid};
end
end

function [bad_lin, nn_lin] = nan_fill_map(mask_ok)
bad_lin = find(~mask_ok); nn_lin = zeros(size(bad_lin));
if isempty(bad_lin), return; end
[NL, NA, NH] = size(mask_ok);
[Ig, Jg, Kg] = ndgrid(1:NL, 1:NA, 1:NH);
I_ok = Ig(mask_ok); J_ok = Jg(mask_ok); K_ok = Kg(mask_ok);
ok_lin = find(mask_ok);
I_bad = Ig(~mask_ok); J_bad = Jg(~mask_ok); K_bad = Kg(~mask_ok);
for k = 1:numel(I_bad)
    d2 = (I_bad(k)-I_ok).^2 + (J_bad(k)-J_ok).^2 + (K_bad(k)-K_ok).^2;
    [~, q] = min(d2);
    nn_lin(k) = ok_lin(q);
end
end

function Z = apply_fill(M, bad_lin, nn_lin)
Z = M; if ~isempty(bad_lin), Z(bad_lin) = M(nn_lin); end
end
