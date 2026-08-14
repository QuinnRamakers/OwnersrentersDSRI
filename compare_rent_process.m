function compare_rent_process()
%COMPARE_RENT_PROCESS  Renter outcomes under the old and new rent processes.
%
%   Two arms, identical in every respect except the growth process of the
%   renter's H state:
%     old  mu_R_level = 0.027, sigma_R_level = 0.037  -- the house-price
%          process, which is what the renter used before the split
%     new  mu_R_level = 0.0097, sigma_R_level = 0.018 -- the rent estimate
%
%   Both arms carry the production DC glide path. Same grid, same shock seed,
%   same number of paths, so every difference is the rent process.
%
%   No welfare comparison is reported. The two arms have different
%   fingerprints, so their value functions are not on a common scale and a CEV
%   between them would be meaningless. Everything here is a behavioural or
%   outcome statistic read off the simulated panel.
%
%   Writes rent_process_comparison.mat and fig_rent_process_comparison.png.

GRID   = [25 15 15];   % the sweep grid, as used by run_nodc; production is 40^3
GH_N   = 5;            % production is 7
N_SIM  = 20000;
SEED   = 20260812;

fprintf('compare_rent_process\n');
fprintf('  grid [%d %d %d], gh_n = %d, %d paths, seed %d\n', ...
        GRID(1), GRID(2), GRID(3), GH_N, N_SIM, SEED);

arms = struct( ...
    'name',    {'old (house process)', 'new (rent estimate)'}, ...
    'mu',      {0.027,  0.0097}, ...
    'sigma',   {0.037,  0.018});

R = struct();
for a = 1:numel(arms)
    fprintf('\n[%d/%d] %s: mu_R_level = %.4f, sigma_R_level = %.4f\n', ...
            a, numel(arms), arms(a).name, arms(a).mu, arms(a).sigma);
    t0 = tic;

    p = config.params();
    % Pinned to the simplex: this file drives the simplex solver/simulator
    % directly, and config.params now defaults to the cube (utility.active_grid).
    p.grid_type = 'simplex';
    p.is_owner    = false;
    p.legacy_fill = false;
    p = utility.build_state_grids(p, GRID, GH_N);
    p.mu_R_level    = arms(a).mu;
    p.sigma_R_level = arms(a).sigma;
    p.sigma_R = sqrt(log(1 + (p.sigma_R_level / (1 + p.mu_R_level))^2));
    p.mu_R    = log(1 + p.mu_R_level) - 0.5 * p.sigma_R^2;

    [~, mg, sl] = config.income_profile(p);
    profile.mu_growth   = mg;
    profile.sigma_l_log = sl;
    profile.p_surv      = config.survival(p);
    shocks    = grids.shock_grid(p);
    ann_price = pension.annuity_price(p, profile, shocks);

    sol = solver.solve_lifecycle(p, profile, shocks, ann_price);
    sim = simulate.paths(p, profile, sol, ann_price, N_SIM, SEED, p.b0);

    R(a).p    = p;
    R(a).sim  = sim;
    R(a).name = arms(a).name;
    R(a).fingerprint = utility.param_fingerprint(p);
    fprintf('  done in %.1f min\n', toc(t0)/60);
end

report(R);
% Through utility.output_dir, like every other writer: a bare filename lands in
% whatever the cwd happens to be, which on the cluster is the pod's ephemeral
% filesystem rather than the mounted volume. This script was missed by the
% pass that routed the other figure writers.
out_dir = utility.output_dir();
mat_file = fullfile(out_dir, 'rent_process_comparison.mat');
save(mat_file, 'R', 'GRID', 'GH_N', 'N_SIM', 'SEED', '-v7.3');
make_figure(R, GRID, GH_N, N_SIM);
fprintf('\nwrote %s and %s\n', mat_file, ...
    fullfile(out_dir, 'fig_rent_process_comparison.png'));
end

% ---------------------------------------------------------------- reporting

function report(R)
p = R(1).p;
ages = p.age0 : p.age0 + p.T - 1;
key  = [1 21 42 43 51 61 71 76];

fprintf('\nfingerprints differ (arms are separate models, no CEV between them): %d\n', ...
        ~strcmp(R(1).fingerprint, R(2).fingerprint));

fprintf('\n=== Rent burden: median rent as a share of net AOW, and of net AOW+annuity ===\n');
fprintf('%5s | %10s %10s | %8s %8s | %8s %8s\n', ...
        'age', 'rent old', 'rent new', 'ofAOW o', 'ofAOW n', 'ofRes o', 'ofRes n');
for i = key
    v = zeros(2,3);
    for a = 1:2
        s = R(a).sim; q = R(a).p;
        rent  = q.alpha * s.H(:,i);
        naow  = (1-q.tau_inc) * s.Y(:,i);
        nres  = (1-q.tau_inc) * (s.Y(:,i) + s.ann_pay(:,i));
        v(a,:) = [median(rent), 100*median(rent./max(naow,1)), 100*median(rent./max(nres,1))];
    end
    fprintf('%5d | %10.0f %10.0f | %7.0f%% %7.0f%% | %7.0f%% %7.0f%%\n', ...
            ages(i), v(1,1), v(2,1), v(1,2), v(2,2), v(1,3), v(2,3));
end

fprintf('\n=== Zero-consumption incidence (share of surviving households) ===\n');
fprintf('%5s | %10s %10s\n', 'age', 'old', 'new');
for i = key
    fprintf('%5d | %9.1f%% %9.1f%%\n', ages(i), ...
            100*mean(R(1).sim.C(:,i) <= 0), 100*mean(R(2).sim.C(:,i) <= 0));
end
fprintf('%5s | %9.1f%% %9.1f%%\n', 'all', ...
        100*mean(R(1).sim.C(:) <= 0), 100*mean(R(2).sim.C(:) <= 0));

fprintf('\n=== Behaviour: median consumption, liquid buffer, DC balance ===\n');
fprintf('%5s | %9s %9s | %9s %9s | %9s %9s\n', ...
        'age', 'C old', 'C new', 'X old', 'X new', 'A old', 'A new');
for i = key
    fprintf('%5d | %9.0f %9.0f | %9.0f %9.0f | %9.0f %9.0f\n', ages(i), ...
        median(R(1).sim.C(:,i)), median(R(2).sim.C(:,i)), ...
        median(R(1).sim.X(:,i)), median(R(2).sim.X(:,i)), ...
        median(R(1).sim.A(:,i)), median(R(2).sim.A(:,i)));
end

fprintf('\n=== Portfolio: median liquid equity share pi ===\n');
fprintf('%5s | %9s %9s\n', 'age', 'old', 'new');
for i = key(1:6)
    fprintf('%5d | %8.3f %8.3f\n', ages(i), ...
            median(R(1).sim.pi(:,i)), median(R(2).sim.pi(:,i)));
end

fprintf('\n=== Lifetime consumption, discounted at beta and survival ===\n');
for a = 1:2
    q = R(a).p; s = R(a).sim;
    disc = cumprod([1; q.beta * config.survival(q)]);
    disc = disc(1:q.T).';
    fprintf('  %-22s mean PV(C) = %10.0f   mean min C over life = %8.0f\n', ...
        R(a).name, mean(s.C * disc.'), mean(min(s.C, [], 2)));
end
end

% ------------------------------------------------------------------ figure

function make_figure(R, GRID, GH_N, N_SIM)
p = R(1).p;
ages = p.age0 : p.age0 + p.T - 1;
col = [0.75 0.20 0.15; 0.10 0.35 0.65];
f = figure('Position', [80 80 1180 780], 'Color', 'w');
tl = tiledlayout(f, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile; hold on; box on
for a = 1:2
    plot(ages, median(R(a).p.alpha * R(a).sim.H, 1), 'Color', col(a,:), 'LineWidth', 1.8);
end
plot(ages, median((1-p.tau_inc)*R(1).sim.Y, 1), 'k--', 'LineWidth', 1.2);
xline(p.retirement_age, ':', 'Color', [.4 .4 .4]);
legend({R.name, 'net income'}, 'Location', 'northwest', 'Box', 'off');
title('Median rent vs net income'); xlabel('age'); ylabel('2025 EUR');

nexttile; hold on; box on
for a = 1:2
    plot(ages, 100*mean(R(a).sim.C <= 0, 1), 'Color', col(a,:), 'LineWidth', 1.8);
end
xline(p.retirement_age, ':', 'Color', [.4 .4 .4]);
title('Zero-consumption incidence'); xlabel('age'); ylabel('% of households');

nexttile; hold on; box on
for a = 1:2
    C = R(a).sim.C;
    plot(ages, median(C,1), 'Color', col(a,:), 'LineWidth', 1.8);
    fill([ages fliplr(ages)], [prctile(C,10,1) fliplr(prctile(C,90,1))], col(a,:), ...
         'FaceAlpha', 0.12, 'EdgeColor', 'none');
end
xline(p.retirement_age, ':', 'Color', [.4 .4 .4]);
title('Consumption, median and 10-90 band'); xlabel('age'); ylabel('2025 EUR');

nexttile; hold on; box on
for a = 1:2
    plot(ages, median(R(a).sim.X, 1), 'Color', col(a,:), 'LineWidth', 1.8);
    plot(ages, median(R(a).sim.A, 1), 'Color', col(a,:), 'LineWidth', 1.2, 'LineStyle', '--');
end
xline(p.retirement_age, ':', 'Color', [.4 .4 .4]);
legend({'liquid X, old', 'DC A, old', 'liquid X, new', 'DC A, new'}, ...
       'Location', 'northwest', 'Box', 'off');
title('Median balances'); xlabel('age'); ylabel('2025 EUR');

title(tl, sprintf(['Renter under the old and new rent processes  |  grid [%d %d %d], ' ...
                   'gh_n = %d, %d paths'], GRID(1), GRID(2), GRID(3), GH_N, N_SIM));
exportgraphics(f, fullfile(utility.output_dir(), 'fig_rent_process_comparison.png'), ...
    'Resolution', 150);
close(f);
end
