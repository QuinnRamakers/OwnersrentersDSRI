function smoke_floor_lna()
%SMOKE_FLOOR_LNA  The consumption floor on the alternative cube (LNA) grid.
%
%   The floor was applied to six solver/simulator sites. smoke_consumption_floor
%   exercises the two simplex ones; this covers the LNA pair, which is otherwise
%   changed but never executed.
%
%   Checks that both regimes solve and simulate, that phi_floor = 0 reproduces
%   the pre-floor behaviour, and that a positive floor removes zero consumption.

fprintf('smoke_floor_lna\n');
n_fail = 0;

for phi = [0, 1e-6]
    q = config.params();
    q.is_owner = false;
    q.N_u1 = 10; q.N_u2 = 8; q.N_u3 = 8;
    q.u1_grid = linspace(0, 1, q.N_u1).';
    q.u2_grid = linspace(0, 1, q.N_u2).';
    q.u3_grid = linspace(0, 1, q.N_u3).';
    q.gh_n = 3; q.N_c = 9; q.N_pi = 9;
    q.phi_floor = phi;

    [~, mg, sl] = config.income_profile(q);
    profile.mu_growth   = mg;
    profile.sigma_l_log = sl;
    profile.p_surv      = config.survival(q);
    shocks    = grids.shock_grid(q);
    ann_price = pension.annuity_price(q, profile, shocks);

    sol = solver.solve_lifecycle_lna(q, profile, shocks, ann_price);
    sim = simulate.paths_lna(q, profile, sol, ann_price, 1500, 5);

    finite_V = all(isfinite(sol.V(~isnan(sol.V))));
    n_fail = n_fail + check(sprintf('phi=%g: lna solve produces finite V', phi), finite_V);

    has_zero = any(sim.C(:) <= 0);
    if phi > 0
        n_fail = n_fail + check(sprintf('phi=%g: no zero consumption', phi), ~has_zero);
        n_fail = n_fail + check(sprintf('phi=%g: sentinel gone', phi), ~any(sol.V(:) == -1e15));
    else
        n_fail = n_fail + check(sprintf('phi=%g: sentinel retained (no-op path)', phi), ...
                                any(sol.V(:) == -1e15));
    end
    fprintf('       min C = %.6g, share C<=0 = %.2f%%\n', min(sim.C(:)), 100*mean(sim.C(:) <= 0));
end

if n_fail == 0
    fprintf('smoke_floor_lna: all checks passed\n');
else
    error('smoke_floor_lna:fail', '%d check(s) failed', n_fail);
end
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
