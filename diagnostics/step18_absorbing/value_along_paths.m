% Step 18, standard grid: the solver's value along simulated paths against the
% realised remaining utility, by age, for both tenures (100,000 households,
% seed 303). Run from the repository root after neural.make_testsets({18},
% numerics={'standard'}, keep_solve=true). HANDOFF.md, 27 November 2026.
% Solver's value along simulated paths against realised remaining utility, by age.
d = fullfile(pwd, 'neural', 'data');
out = struct();
for ten = ["owner", "renter"]
    r = load(fullfile(d, "solve_18_" + ten + "_standard.mat")).r;
    p = r.p; sol = r.sol; g = p.gamma; T = p.T; N = 100000;
    fprintf('%s: sol fields: %s\n', ten, strjoin(fieldnames(sol)', ' '));
    sim = simulate.paths_lna(p, r.profile, sol, r.ann_price, N, 303, p.b0);
    Y0 = sim.Y(1, 1);
    uC = (sim.C / Y0) .^ (1 - g) / (1 - g);
    ps = r.profile.p_surv;
    R = zeros(N, T); R(:, T) = uC(:, T);
    for t = T-1:-1:1, R(:, t) = uC(:, t) + p.beta * ps(t) * R(:, t + 1); end
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
            F = griddedInterpolant({g1, g2, p.u3_grid, q_grid}, z, 'linear', 'nearest');
            zz = F(u1, u2, u3, sim.q(:, t));
        else
            F = griddedInterpolant({g1, g2, p.u3_grid}, z, 'linear', 'nearest');
            zz = F(u1, u2, u3);
        end
        Vh(:, t) = (sim.W(:, t) / Y0 .* zz) .^ (1 - g) / (1 - g);
        ab = sim.absorbed(:, t);
        Vh(ab, t) = uC(ab, t) * p.D_beq(t);
    end
    ce = @(v, t) ((1 - g) * mean(v) / p.D_abs(t)) ^ (1 / (1 - g));
    ages = p.age0 + (0:T-1);
    ceS = zeros(T, 1); ceR = ceS; ceB = ceS; solv = ceS; ceSs = ceS; ceRs = ceS;
    for t = 1:T
        ceS(t) = ce(Vh(:, t), t); ceR(t) = ce(R(:, t), t);
        if t < T, ceB(t) = ce(uC(:, t) + p.beta * ps(t) * Vh(:, t + 1), t); else, ceB(t) = ceS(t); end
        never = ~any(sim.absorbed, 2);
        ceSs(t) = ce(Vh(never, t), t); ceRs(t) = ce(R(never, t), t);
        solv(t) = mean(~sim.absorbed(:, t));
    end
    fprintf('%s: ever bankrupt %.4f; entry: solver %.4f, realised %.4f; never-bankrupt households: solver %.4f, realised %.4f\n', ...
        ten, mean(~never), ceS(1), ceR(1), ceSs(1), ceRs(1));
    fprintf(' age  solver  realised  one-step(u+bV_next)  | never bankrupt: solver realised | solvent\n');
    for t = [1 3 6 11 16 21 26 31 36 41 43 46 51 56 61 66 71 75]
        fprintf('%4d  %.4f  %.4f   %.4f               |                 %.4f  %.4f  | %.4f\n', ...
            ages(t), ceS(t), ceR(t), ceB(t), ceSs(t), ceRs(t), solv(t));
    end
    % The households who go bankrupt: solver's value against realised, years before entry.
    ab_t = p.T - sum(sim.absorbed, 2) + 1;   % first bankrupt year index
    k = find(~never);
    fprintf('bankrupt households: %d; age at entry: median %d, 10th-90th %d-%d\n', numel(k), ...
        median(sim.abs_age(k)), prctile(sim.abs_age(k), 10), prctile(sim.abs_age(k), 90));
    for lag = [10 5 3 2 1 0]
        rows = k(ab_t(k) - lag >= 1);
        tt = ab_t(rows) - lag;
        idx = sub2ind([N T], rows, tt);
        rs = mean(((1 - g) * Vh(idx) ./ p.D_abs(tt)) .^ (1 / (1 - g)));
        rr = mean(((1 - g) * R(idx) ./ p.D_abs(tt)) .^ (1 / (1 - g)));
        lw = mean(sim.LW(idx) ./ sim.Y(idx)); fy = mean(p.phi_path(tt));
        fprintf(' %2d years before bankruptcy: mean household CE, solver %.4f realised %.4f; LW/Y %.3f (floor %.3f)\n', ...
            lag, rs, rr, lw, fy);
    end
    out.(ten) = struct('ages', ages, 'ceS', ceS, 'ceR', ceR, 'ceB', ceB, 'ceSs', ceSs, 'ceRs', ceRs, 'solv', solv);
    clear r sol sim R Vh uC
end
save(fullfile(d, 'absdiag_18_standard.mat'), '-struct', 'out');
