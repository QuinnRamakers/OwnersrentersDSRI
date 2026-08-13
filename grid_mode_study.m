function grid_mode_study()
%GRID_MODE_STUDY  Can the tensor seed search go, and does a modest floor help?
%
%   Two questions, deliberately crossed because they interact: a better
%   conditioned objective is exactly what would make dropping the tensor safe.
%
%   GRID MODE. 'full' is the 41x41 tensor per state, 'coarse' is 9x9, 'none'
%   evaluates only the t+1 policy plus two fixed points. The tensor is the
%   dominant per-state cost, so if 'none' tracks 'full' the solver gets much
%   cheaper. What is at risk is the guarantee: with a tensor, V >= its maximum
%   by construction; without one, the polish is unsupervised. Glide arm only --
%   free-tau keeps the tensor, since its dominance proof rests on the glide
%   slice's grid maximum.
%
%   FLOOR. phi_floor is a fraction of GROSS income, so at retirement
%   (Y = 21,167) 1e-6 is a floor of 2 cents and the ruin-to-normal utility
%   ratio is ~4e24. 0.05 and 0.10 put it at roughly 1,000 and 2,100 euros,
%   ratios ~6e5 and ~4e4 -- four to six fewer orders of magnitude, while still
%   being far below the social minimum (net AOW is 13,081).
%
%   Reference is (full, 1e-6): the current production configuration. Every
%   comparison is against the 'full' run AT THE SAME FLOOR, since changing the
%   floor changes the model rather than the numerics.

GRID  = [25 15 15];
GH_N  = 5;
N_SIM = 8000;
SEED  = 20260813;

phis  = [1e-6, 0.05, 0.10];
modes = {'full', 'coarse', 'none'};

fprintf('grid_mode_study: grid [%d %d %d], gh_n = %d, polish_ver = 2\n\n', ...
        GRID(1), GRID(2), GRID(3), GH_N);
pool = gcp();
parfevalOnAll(pool, @() warning('off', 'MATLAB:nearlySingularMatrix'), 0);
parfevalOnAll(pool, @() warning('off', 'MATLAB:singularMatrix'), 0);

R = struct(); n = 0;
AGES = [25 35 45 55 67 85];

for iphi = 1:numel(phis)
    for imode = 1:numel(modes)
        n = n + 1;
        t0 = tic;
        p = config.params();
        p.is_owner    = false;
        p.legacy_fill = false;
        p.polish_ver  = 2;
        p.phi_floor   = phis(iphi);
        p.grid_mode   = modes{imode};
        p = utility.build_state_grids(p, GRID, GH_N);

        [~, mg, sl] = config.income_profile(p);
        profile = struct('mu_growth', mg, 'sigma_l_log', sl, 'p_surv', config.survival(p));
        shocks    = grids.shock_grid(p);
        ann_price = pension.annuity_price(p, profile, shocks);

        sol = solver.solve_lifecycle(p, profile, shocks, ann_price);
        w   = utility.welfare_summary(p, sol.V(:,:,:,1));
        sim = simulate.paths(p, profile, sol, ann_price, N_SIM, SEED, p.b0);

        pi_med = zeros(1, numel(AGES));
        for j = 1:numel(AGES)
            pi_med(j) = median(sim.pi(:, AGES(j) - p.age0 + 1));
        end
        Vf = sol.V(:,:,:,1); Vf = Vf(isfinite(Vf) & Vf ~= 0);
        F  = p.phi_floor * sim.Y;

        R(n).phi     = phis(iphi);
        R(n).mode    = modes{imode};
        R(n).Vt0_b0  = w.Vt0_b0;
        R(n).z       = ((1 - p.gamma) * w.Vt0_b0)^(1/(1 - p.gamma));
        R(n).span    = max(abs(Vf)) / min(abs(Vf));   % conditioning of V at t=1
        R(n).floor   = mean(sim.LW(:) < F(:));
        R(n).pi_med  = pi_med;
        R(n).minutes = toc(t0)/60;

        fprintf('phi=%-7.4g mode=%-7s %5.1f min  Vt0=%12.5g  z=%10.5g  |V| span=%9.3g  floor=%.2f%%\n', ...
                R(n).phi, R(n).mode, R(n).minutes, R(n).Vt0_b0, R(n).z, R(n).span, 100*R(n).floor);
        save('grid_mode_study.mat', 'R', 'AGES', 'GRID', 'GH_N', 'N_SIM', 'SEED');
    end
end

fprintf('\n===== against ''full'' at the same floor =====\n');
fprintf('%-9s %-8s %10s %9s %9s %9s | %s\n', 'phi','mode','z','rel z','speedup','floor%','median pi');
for iphi = 1:numel(phis)
    ref = R(find([R.phi] == phis(iphi) & strcmp({R.mode}, 'full'), 1));
    for imode = 1:numel(modes)
        r = R(find([R.phi] == phis(iphi) & strcmp({R.mode}, modes{imode}), 1));
        fprintf('%-9.4g %-8s %10.4g %+8.2f%% %8.2fx %8.2f%% | %s\n', ...
            r.phi, r.mode, r.z, 100*(r.z/ref.z - 1), ref.minutes/r.minutes, ...
            100*r.floor, sprintf('%6.3f', r.pi_med));
    end
end

fprintf(['\nRel z near 0 means the cheaper seed found the same answer.\n' ...
         'A large negative rel z means it did not, and the tensor is doing real work.\n']);
fprintf('\nwrote grid_mode_study.mat\ndone\n');
end
