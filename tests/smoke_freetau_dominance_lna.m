function smoke_freetau_dominance_lna()
%SMOKE_FREETAU_DOMINANCE_LNA  Free DC choice must dominate the glide, on the cube.
%
%   The correctness property of free tau is not "it runs" but "it is never
%   worse". Choosing tau per state includes the option of choosing the glide
%   value, so for the same continuation the free arm must weakly dominate the
%   glide arm at every state. If it does not, the polish is failing to find a
%   point the glide solve did find -- which is exactly what happened on the
%   simplex before the derivative-free refinement was added, and why
%   refine_cpi_u exists.
%
%   Checks, all on a coarse cube:
%     (a) one Bellman step from an IDENTICAL V_next, glide vs free. This is the
%         real test: the continuations are the same, so dominance is exact up
%         to the optimiser, with no accumulation.
%     (b) the full backward solve. The per-state polish is not itself monotone
%         and the two arms' continuations diverge, so a small tolerance applies.
%     (c) the recorded tau policy is in [0,1] and defined wherever it should be.
%     (d) at a RETIRED age the free arm must reproduce the glide arm
%         bit-identically. tau is not a choice from t_ret on (the annuity is
%         priced off the plan's path), so optimise_tau is false there and the
%         slice tensor must collapse to the original single-slice search.

fprintf('smoke_freetau_dominance_lna\n');
n_fail = 0;

p = base_params();

[~, mg, sl] = config.income_profile(p);
profile.mu_growth   = mg;
profile.sigma_l_log = sl;
profile.p_surv      = config.survival(p);
shocks    = grids.shock_grid(p);
ann_price = pension.annuity_price(p, profile, shocks);

% ---- (a) one step from a common continuation, mid-accumulation
t_probe = 20;
p_g = p; p_g.choose_tau_S = false;
p_f = p; p_f.choose_tau_S = true;

rng(3);
Vn = -exp(randn(numel(p.u1_grid), numel(p.u2_grid), numel(p.u3_grid)));
[Vg, ~, ~]      = solver.bellman_step_lna(t_probe, Vn, p_g, profile, shocks, ann_price);
[Vf, ~, ~, tf]  = solver.bellman_step_lna(t_probe, Vn, p_f, profile, shocks, ann_price);

d   = Vf - Vg;
bad = d < 0;
n_fail = n_fail + check('(a) free >= glide at every state, one step', ~any(bad(:)));
fprintf('       worst shortfall %.3g over %d states (%d violating)\n', ...
        min(d(:)), numel(d), nnz(bad));
n_fail = n_fail + check('(a) free strictly better somewhere', any(d(:) > 0));

% ---- (c) tau policy well formed
n_fail = n_fail + check('(c) tau policy within [0,1]', all(tf(:) >= 0 & tf(:) <= 1));

% ---- (d) at a retired age the two arms must be bit-identical
t_ret_probe = p.t_ret + 5;
[Vr_f, cr_f, pir_f] = solver.bellman_step_lna(t_ret_probe, Vn, p_f, profile, shocks, ann_price);
[Vr_g, cr_g, pir_g] = solver.bellman_step_lna(t_ret_probe, Vn, p_g, profile, shocks, ann_price);
n_fail = n_fail + check('(d) retired age: free reproduces glide bit-identically', ...
    isequal(Vr_f, Vr_g) && isequal(cr_f, cr_g) && isequal(pir_f, pir_g));

% ---- (b) full solve
solg = solver.solve_lifecycle_lna(p_g, profile, shocks, ann_price);
solf = solver.solve_lifecycle_lna(p_f, profile, shocks, ann_price);
wg = utility.welfare_summary(p_g, solg.V(:,:,:,1));
wf = utility.welfare_summary(p_f, solf.V(:,:,:,1));
cev = (wf.Vt0_b0 / wg.Vt0_b0)^(1/(1 - p.gamma)) - 1;
fprintf('       full solve: glide Vt0_b0=%.6g  free Vt0_b0=%.6g  CEV %+.3f%%\n', ...
        wg.Vt0_b0, wf.Vt0_b0, 100*cev);
n_fail = n_fail + check('(b) free >= glide at the welfare anchor', cev >= -1e-4);
n_fail = n_fail + check('(b) tau_pol carried through solve_lifecycle_lna', ...
                        isfield(solf, 'tau_pol') && ~isfield(solg, 'tau_pol'));

if n_fail == 0
    fprintf('smoke_freetau_dominance_lna: all checks passed\n');
else
    error('smoke_freetau_dominance_lna:fail', '%d check(s) failed', n_fail);
end
end

function p = base_params()
p = config.params();
p.is_owner  = false;
p.grid_type = 'lna';
p = utility.build_state_grids(p, [12 9 9], 3);
p.N_c = 15; p.N_pi = 15; p.N_tau = 5;
end

function bad = check(name, ok)
if ok
    fprintf('  ok   %s\n', name);
    bad = 0;
else
    fprintf('  FAIL %s\n', name);
    bad = 1;
end
end
