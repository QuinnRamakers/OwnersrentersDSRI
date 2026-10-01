% Minimal verification, three backward steps rather than a full life cycle:
% enough to exercise the terminal branch, a retired step and a working step.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear; clc
p = config.params(); p.is_owner = false;
p.grid_mode = 'none'; p.polish_ver = 2; p.use_refine = false;
p = utility.build_state_grids(p, [8 8 6], 3);
[~, mg, sl] = config.income_profile(p);
prof.mu_growth = mg; prof.sigma_l_log = sl; prof.p_surv = config.survival(p);
shk = grids.shock_grid(p); ann = pension.annuity_price(p, prof, shk);
fprintf('grid %dx%dx%d gh_n=%d  T=%d t_ret=%d\n', numel(p.u1_grid), numel(p.u2_grid), ...
        numel(p.u3_grid), p.gh_n, p.T, p.t_ret);

[VT, cT, piT] = solver.bellman_step_lna(p.T, [], p, prof, shk, ann);
pol.c = cT; pol.pi = piT;

ts = [p.T-1, p.t_ret, p.t_ret-1, 20];   % retired, handover, working

A = struct(); B = struct();
for t = ts
    q = p;                          [A.(sprintf('t%d',t)).V, A.(sprintf('t%d',t)).c, A.(sprintf('t%d',t)).pi] = ...
        solver.bellman_step_lna(t, VT, q, prof, shk, ann, pol);
    r = p; r.interp_object = 'kappa';
    [B.(sprintf('t%d',t)).V, B.(sprintf('t%d',t)).c, B.(sprintf('t%d',t)).pi] = ...
        solver.bellman_step_lna(t, VT, r, prof, shk, ann, pol);
end
z = p; z.interp_object = 'z';
[Vz,cz,~] = solver.bellman_step_lna(20, VT, z, prof, shk, ann, pol);
fprintf('(a) default vs explicit ''z'' at t=20: isequal(V)=%d  max|dV|=%g  max|dc|=%g\n', ...
        isequal(A.t20.V, Vz), max(abs(A.t20.V(:)-Vz(:))), max(abs(A.t20.c(:)-cz(:))));

fprintf('\n(b) z vs kappa, one step from the same V_next\n');
fprintf('%6s %12s %12s %12s %12s %10s\n','t','minV z','minV kappa','med|dc|/c','med|dpi|','finite');
for t = ts
    k = sprintf('t%d',t); a = A.(k); b = B.(k);
    dc = abs(b.c(:)-a.c(:))./max(abs(a.c(:)),eps);
    fprintf('%6d %12.4g %12.4g %11.2f%% %12.4f %9d/%d\n', t, min(a.V(:)), min(b.V(:)), ...
            100*median(dc), median(abs(b.pi(:)-a.pi(:))), sum(isfinite(b.V(:))), numel(b.V));
end

