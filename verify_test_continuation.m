function verify_test_continuation()
%VERIFY_TEST_CONTINUATION  Was the reported per-state gain a test artefact?
%
%   smoke_polish_v2 and the grid_mode single-step checks both fed bellman_step a
%   RANDOM continuation, -exp(3*randn(...)), and reported v2 beating v1 at most
%   states by up to 28.8%. The full solve then showed v2_full identical to
%   v1_full to six figures with max|dpi| = 0. Those cannot both describe the
%   same solver.
%
%   The suspicion is that a random V_next is a pathological surface -- wildly
%   irregular, dispersion of e^3 -- so the polish has multimodality and kinks to
%   exploit that a genuinely solved, smooth V_next does not present. If so the
%   gain is real but only ever occurs off the solution path, which is exactly
%   why it vanishes in a real solve.
%
%   This runs the identical one-step comparison twice: once against a real
%   solved V_{t+1}, once against the random surface. If the real continuation
%   shows near-zero difference and the random one shows the large gain, the
%   test design was the problem and the reported numbers should be withdrawn.

p = config.params();
p.is_owner = false; p.legacy_fill = false; p.phi_floor = 0.05;
p = utility.build_state_grids(p, [14 10 10], 3);
p.N_c = 21; p.N_pi = 21;

[~, mg, sl] = config.income_profile(p);
profile = struct('mu_growth', mg, 'sigma_l_log', sl, 'p_surv', config.survival(p));
shocks = grids.shock_grid(p);
ann    = pension.annuity_price(p, profile, shocks);

p1 = p; p1.polish_ver = 1;
sol = solver.solve_lifecycle(p1, profile, shocks, ann);

[L, A, H] = ndgrid(p.lambda_grid, p.sA_grid, p.sH_grid);
feas = (L + A + H) <= 1 + 1e-12;
t = 20;

rng(11);
Vreal = sol.V(:,:,:,t+1);
Vrand = -exp(3*randn(size(Vreal))); Vrand(~feas) = NaN;
pol = struct('c', sol.c_pol(:,:,:,t+1), 'pi', sol.pi_pol(:,:,:,t+1), 'tau', []);

fprintf('one step at t=%d, v2_full vs v1, same continuation each row\n\n', t);
fprintf('%-10s %8s %8s %12s %12s\n', 'V_next', 'better', 'worse', 'max gain', 'worst loss');
for nm = {'REAL', 'RANDOM'}
    Vn = Vreal;
    if strcmp(nm{1}, 'RANDOM'), Vn = Vrand; end
    Va = solver.bellman_step(t, Vn, p1, profile, shocks, ann);
    q = p; q.polish_ver = 2; q.grid_mode = 'full';
    Vb = solver.bellman_step(t, Vn, q, profile, shocks, ann, pol);
    r = (Vb(feas) - Va(feas)) ./ abs(Va(feas));
    fprintf('%-10s %8d %8d %12.4g %12.4g\n', nm{1}, ...
            nnz(r > 1e-12), nnz(r < -1e-12), max(r), min(r));
end

fprintf(['\nIf REAL is ~0 and RANDOM is large, the gains only exist on surfaces\n' ...
         'the solver never encounters, and the headline numbers were a test\n' ...
         'artefact rather than a property of the change.\n']);
fprintf('done\n');
end
