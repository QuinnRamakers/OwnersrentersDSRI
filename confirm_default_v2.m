function confirm_default_v2()
%CONFIRM_DEFAULT_V2  Adoption check for polish_ver = 2 as the default.
%
%   Two things have to hold before this is safe to ship as the default:
%     (1) output is unchanged -- the whole case for adopting a null result is
%         that it costs nothing behaviourally, so any drift invalidates it;
%     (2) the runtime cost is known, since that is the one real price.
%
%   Both tenures, identical grid, floor, seed and path count. The fixed polish
%   starts are now gated to the no-tensor mode, so this measures scaling and
%   warm starts alone, which is what was asked for.

GRID = [25 15 15]; GH_N = 5; N_SIM = 20000; SEED = 20260813; PHI = 0.05;
vers = [1 2];
tenures = struct('name', {'renter', 'owner'}, 'is_owner', {false, true});

fprintf('confirm_default_v2: grid [%d %d %d], gh_n = %d, phi_floor = %.3g\n\n', ...
        GRID(1), GRID(2), GRID(3), GH_N, PHI);
pool = gcp();
parfevalOnAll(pool, @() warning('off', 'MATLAB:nearlySingularMatrix'), 0);
parfevalOnAll(pool, @() warning('off', 'MATLAB:singularMatrix'), 0);

R = struct(); n = 0;
for h = 1:numel(tenures)
    for v = vers
        n = n + 1; t0 = tic;
        p = config.params();
        p.is_owner    = tenures(h).is_owner;
        p.legacy_fill = false;
        p.polish_ver  = v;
        p.phi_floor   = PHI;
        p = utility.build_state_grids(p, GRID, GH_N);
        [~, mg, sl] = config.income_profile(p);
        profile = struct('mu_growth', mg, 'sigma_l_log', sl, 'p_surv', config.survival(p));
        shocks = grids.shock_grid(p);
        ann    = pension.annuity_price(p, profile, shocks);

        sol = solver.solve_lifecycle(p, profile, shocks, ann);
        w   = utility.welfare_summary(p, sol.V(:,:,:,1));
        sim = simulate.paths(p, profile, sol, ann, N_SIM, SEED, p.b0);
        F   = p.phi_floor * sim.Y;

        R(n).tenure = tenures(h).name;
        R(n).ver    = v;
        R(n).Vt0    = w.Vt0_b0;
        R(n).floor  = mean(sim.LW(:) < F(:));
        R(n).C      = median(sim.C, 1);
        R(n).pi     = median(sim.pi, 1);
        R(n).min    = toc(t0)/60;
        fprintf('  %-6s v%d  %5.1f min  Vt0 = %.10g  floor %.3f%%\n', ...
                R(n).tenure, v, R(n).min, R(n).Vt0, 100*R(n).floor);
    end
end

fprintf('\n===== v2 against v1, same tenure =====\n');
for h = 1:numel(tenures)
    a = R(find(strcmp({R.tenure}, tenures(h).name) & [R.ver] == 1, 1));
    b = R(find(strcmp({R.tenure}, tenures(h).name) & [R.ver] == 2, 1));
    dC  = max(abs(b.C  - a.C)  ./ max(abs(a.C), 1));
    dpi = max(abs(b.pi - a.pi));
    fprintf(['  %-6s  Vt0 identical: %d | rel dVt0 %.3g | max rel dC %.3g | ' ...
             'max dpi %.3g | dfloor %.4fpp | cost %.2fx\n'], ...
        tenures(h).name, b.Vt0 == a.Vt0, abs(b.Vt0/a.Vt0 - 1), dC, dpi, ...
        100*(b.floor - a.floor), b.min/a.min);
end
save('confirm_default_v2.mat', 'R');
fprintf('\nwrote confirm_default_v2.mat\ndone\n');
end
