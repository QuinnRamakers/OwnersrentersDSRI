function floor_agreement_sweep()
%FLOOR_AGREEMENT_SWEEP  Does the solver agree with the simulator, and at what floor?
%
%   For each phi_floor: solve, simulate, and compare the panel's mean
%   discounted u(C) against V_tilde at the same initial state, in
%   certainty-equivalent terms.
%
%   The two sides cannot agree exactly even when they implement the same
%   model, because they do not share a shock support: the solver quadratures
%   over gh_n Gauss-Hermite nodes, which are bounded, while simulate.paths
%   draws from the continuous lognormal, which is not. The simulator therefore
%   visits states the quadrature never contemplates. With utility unbounded
%   below that discrepancy is unbounded too, so the gap should shrink as the
%   floor rises and bounds u from below.

PHIS = [0, 1e-6, 1e-3, 0.1, 0.5, 1.0];

fprintf('floor_agreement_sweep   grid [10 8 8], gh_n = 3, 4000 paths\n\n');
fprintf('%10s | %10s %10s | %12s %12s | %9s\n', ...
        'phi_floor', 'floor@67', 'C=0 share', 'E[sum u(C)]', 'V_tilde lvl', 'CE gap');

for phi = PHIS
    q = config.params();
    % Pinned to the simplex: this file drives the simplex solver/simulator
    % directly, and config.params now defaults to the cube (utility.active_grid).
    q.grid_type = 'simplex';
    q.is_owner = false; q.legacy_fill = false;
    q = utility.build_state_grids(q, [10 8 8], 3);
    q.N_c = 9; q.N_pi = 9;
    q.phi_floor = phi;

    [~, mg, sl] = config.income_profile(q);
    profile.mu_growth = mg; profile.sigma_l_log = sl;
    profile.p_surv = config.survival(q);
    shocks = grids.shock_grid(q);
    ann    = pension.annuity_price(q, profile, shocks);
    sol    = solver.solve_lifecycle(q, profile, shocks, ann);
    sim    = simulate.paths(q, profile, sol, ann, 4000, 11, q.b0);

    omg  = 1 - q.gamma;
    disc = cumprod([1; q.beta*config.survival(q)]); disc = disc(1:q.T).';
    Cs   = sim.C; Cs(Cs <= 0) = realmin;        % phi = 0 arm has exact zeros
    eu   = mean((Cs.^omg/omg) * disc.');

    w   = utility.welfare_summary(q, sol.V(:,:,:,1));
    W0  = (1 + q.h_mult + q.b0) * sim.Y(1,1);
    vt  = w.Vt0_b0 * W0^omg;
    gap = (eu/vt)^(1/omg) - 1;

    fprintf('%10.4g | %10.2f %9.2f%% | %12.5g %12.5g | %8.1f%%\n', ...
        phi, phi*sim.Y(1,q.t_ret), 100*mean(sim.C(:) <= 0), eu, vt, 100*gap);
end

fprintf(['\nA gap near zero means the panel and the value function price the same\n' ...
         'model. A large negative gap means the simulator is finding catastrophic\n' ...
         'states the quadrature never reaches.\n']);
end
