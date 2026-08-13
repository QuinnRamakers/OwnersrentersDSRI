function run_dash_configs()
%RUN_DASH_CONFIGS  Solve renter and owner under each solver configuration.
%
%   Three configurations, so the effect of the solver changes can be inspected
%   in the paths rather than only in the value function:
%     v1_full  polish_ver 1, full tensor  -- the original solver
%     v2_full  polish_ver 2, full tensor  -- scaling + warm + fixed starts
%     v2_none  polish_ver 2, no tensor    -- the candidate replacement
%
%   Both tenures each, identical grid, floor, seed and path count, so any
%   difference between the figures is the solver and nothing else.
%
%   Saves dash_<tag>_<tenure>.mat. Dashboards are drawn separately, one MATLAB
%   process per configuration: make_plots is a script and reusing a workspace
%   across runs of it leaks variables.

GRID = [25 15 15]; GH_N = 5; N_SIM = 20000; SEED = 20260813; PHI = 0.05;

cfgs = struct('tag',  {'v1_full', 'v2_full', 'v2_none'}, ...
              'ver',  {1,         2,         2}, ...
              'mode', {'full',    'full',    'none'});
tenures = struct('name', {'renter', 'owner'}, 'is_owner', {false, true});

fprintf('run_dash_configs: grid [%d %d %d], gh_n = %d, phi_floor = %.3g, %d paths\n', ...
        GRID(1), GRID(2), GRID(3), GH_N, PHI, N_SIM);
pool = gcp();
parfevalOnAll(pool, @() warning('off', 'MATLAB:nearlySingularMatrix'), 0);
parfevalOnAll(pool, @() warning('off', 'MATLAB:singularMatrix'), 0);

for c = 1:numel(cfgs)
    for h = 1:numel(tenures)
        out = sprintf('dash_%s_%s.mat', cfgs(c).tag, tenures(h).name);
        if isfile(out)
            fprintf('  %s exists, skipping\n', out);
            continue
        end
        t0 = tic;
        p = config.params();
        p.is_owner    = tenures(h).is_owner;
        p.legacy_fill = false;
        p.polish_ver  = cfgs(c).ver;
        p.grid_mode   = cfgs(c).mode;
        p.phi_floor   = PHI;
        p = utility.build_state_grids(p, GRID, GH_N);

        [~, mg, sl] = config.income_profile(p);
        profile = struct('mu_growth', mg, 'sigma_l_log', sl, 'p_surv', config.survival(p));
        shocks    = grids.shock_grid(p);
        ann_price = pension.annuity_price(p, profile, shocks);

        sol      = solver.solve_lifecycle(p, profile, shocks, ann_price);
        welfare0 = utility.welfare_summary(p, sol.V(:,:,:,1));
        sim      = simulate.paths(p, profile, sol, ann_price, N_SIM, SEED, p.b0);
        F = p.phi_floor * sim.Y;

        fprintf('  %-9s %-6s %5.1f min | Vt0=%11.5g | floor %.2f%% | C@45 %6.0f | pi@45 %.3f\n', ...
            cfgs(c).tag, tenures(h).name, toc(t0)/60, welfare0.Vt0_b0, ...
            100*mean(sim.LW(:) < F(:)), median(sim.C(:,21)), median(sim.pi(:,21)));

        save(out, 'p', 'profile', 'sol', 'ann_price', 'sim', 'welfare0', '-v7.3');
    end
end
fprintf('\ndone\n');
end
