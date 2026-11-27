% Step 24 (default as a choice, bequest at b = 2), standard grid: the solver's
% value along simulated paths against the realised remaining utility, by age,
% for both tenures (100,000 households, seed 303). As
% diagnostics/step18_absorbing/value_along_paths.m, with the bequest: a
% solvent household gets beta (1 - p_t) chi u(bequest after a year of
% returns) each year, and one that defaults is worth u(F) D_beq(t), its floor
% for life and beq_bankrupt years of it at death. The last year's bequest is
% taken before returns (the panel has no returns past 100; its weight is the
% survival to 100). Run from the repository root after
% neural.make_testsets({24}, numerics={'standard'}, keep_solve=true).
d = fullfile(pwd, 'neural', 'data');
out = struct();
for ten = ["renter", "owner"]
    f = fullfile(d, "solve_24_" + ten + "_standard.mat");
    if ~isfile(f), fprintf('%s: no solve yet\n', ten); continue, end
    r = load(f).r;
    p = r.p; sol = r.sol; g = p.gamma; T = p.T; N = 100000;
    sim = simulate.paths_lna(p, r.profile, sol, r.ann_price, N, 303, p.b0);
    Y0 = sim.Y(1, 1);
    u = @(x) (x / Y0) .^ (1 - g) / (1 - g);
    ps = r.profile.p_surv(:);
    hb = p.is_owner * (1 - p.sell_cost);
    ab = sim.absorbed;
    % Realised: per-year utility of the solvent, with the bequest term
    rt = zeros(N, T);
    for t = 1:T
        if t < T, b = sim.X(:, t + 1) + hb * sim.H(:, t + 1); else, b = sim.bequest; end
        b = max(b, 1e-12 * sim.W(:, t));
        rt(:, t) = u(sim.C(:, t)) + p.beta * (1 - ps(t)) * p.chi * u(b);
    end
    R = zeros(N, T);
    Cbar = sim.C(sub2ind([N T], (1:N)', min(T - sum(ab, 2) + 1, T)));   % consumption in the year of default
    for t = T:-1:1
        if t == T, R(:, t) = rt(:, t); else, R(:, t) = rt(:, t) + p.beta * ps(t) * R(:, t + 1); end
        R(ab(:, t), t) = u(Cbar(ab(:, t))) * p.D_beq(t);
    end
    % The solver's value at each household's state; the default value for the defaulted
    Vh = zeros(N, T);
    q_grid = p.q_grid(:);
    for t = 1:T
        [g1, g2] = utility.grid_at(p, t);
        V = sol.V(:, :, :, :, t);
        z = zeros(size(V)); m = isfinite(V); z(m) = ((1 - g) * V(m)) .^ (1 / (1 - g));
        sAH = sim.sA(:, t) + sim.sH(:, t);
        u1 = sim.lambda(:, t); u2 = sAH ./ max(1 - u1, 1e-12);
        u3 = min(max(sim.sA(:, t) ./ max(sAH, 1e-12), 0), 1);
        if numel(q_grid) > 1
            zz = griddedInterpolant({g1, g2, p.u3_grid, q_grid}, z, 'linear', 'nearest');
            zz = zz(u1, u2, u3, sim.q(:, t));
        else
            zz = griddedInterpolant({g1, g2, p.u3_grid}, z(:, :, :, 1), 'linear', 'nearest');
            zz = zz(u1, u2, u3);
        end
        Vh(:, t) = (sim.W(:, t) / Y0 .* zz) .^ (1 - g) / (1 - g);
        Vh(ab(:, t), t) = u(Cbar(ab(:, t))) * p.D_beq(t);
    end
    ce = @(v, t) ((1 - g) * mean(v) / p.D_abs(t)) ^ (1 / (1 - g));
    never = ~any(ab, 2);
    ages = p.age0 + (0:T-1);
    fprintf('\n%s: ever defaulted %.4f, median age %g; entry: solver %.4f, realised %.4f; never defaulted: solver %.4f, realised %.4f\n', ...
        ten, mean(~never), median(sim.abs_age(~never)), ce(Vh(:, 1), 1), ce(R(:, 1), 1), ce(Vh(never, 1), 1), ce(R(never, 1), 1));
    fprintf(' age  solver  realised | never defaulted: solver realised | share defaulted\n');
    rows = [1 6 11 16 21 26 31 36 41 43 46 51 56 61 66 71 75];
    T_out = zeros(numel(rows), 6);
    for k = 1:numel(rows)
        t = rows(k);
        T_out(k, :) = [ages(t), ce(Vh(:, t), t), ce(R(:, t), t), ce(Vh(never, t), t), ce(R(never, t), t), mean(ab(:, t))];
        fprintf('%4d  %.4f  %.4f   |                 %.4f  %.4f | %.4f\n', T_out(k, :));
    end
    % Who defaults: resources against the default amount the year before and at default
    k = find(~never); ta = T - sum(ab(k, :), 2) + 1;
    for lag = [1 0]
        ok = ta - lag >= 1; idx = sub2ind([N T], k(ok), ta(ok) - lag);
        fprintf(' %d years before default: median LW/Y %.3f, floor share %.3f, X %.3f, Y %.3f (entry income)\n', lag, ...
            median(sim.LW(idx) ./ sim.Y(idx)), median(p.phi_path(ta(ok) - lag)), median(sim.X(idx) / Y0), median(sim.Y(idx) / Y0));
    end
    out.(ten) = T_out;
end
save(fullfile(d, 'absdiag_24_standard.mat'), '-struct', 'out');
