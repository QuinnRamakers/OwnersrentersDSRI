% Step 18 owners, standard grid: where the households that go bankrupt sit on
% the grid in the years before, and what they hold when they go bankrupt
% (house, outstanding mortgage, equity, pot, income). HANDOFF.md, 27 November 2026.
d = fullfile(pwd, 'neural', 'data');
r = load(fullfile(d, 'solve_18_owner_standard.mat')).r;
p = r.p; sol = r.sol; g = p.gamma; N = 100000;
fprintf('u1 grid: %s\n', mat2str(p.u1_grid(:).', 3));
fprintf('u2 grid: %s\n', mat2str(p.u2_grid(:).', 4));
fprintf('u3 grid: %s\n', mat2str(p.u3_grid(:).', 3));
fprintf('q grid:  %s\n', mat2str(p.q_grid(:).', 3));
fprintf('age grid: %d\n', isfield(p, 'u1_grid_age') && ~isempty(p.u1_grid_age));
sim = simulate.paths_lna(p, r.profile, sol, r.ann_price, N, 303, p.b0);
never = ~any(sim.absorbed, 2);
k = find(~never);
ab_t = p.T - sum(sim.absorbed, 2) + 1;
Y0 = sim.Y(1,1);
fprintf('\nBankrupt owners (%d), at their state 1, 3 and 5 years before bankruptcy, and at bankruptcy:\n', numel(k));
for lag = [5 3 1 0]
    rows = k(ab_t(k) - lag >= 1); tt = ab_t(rows) - lag; idx = sub2ind([N p.T], rows, tt);
    sAH = sim.sA(idx) + sim.sH(idx); u1 = sim.lambda(idx); u2 = sAH ./ (1 - u1);
    X = sim.X(idx)/Y0; H = sim.H(idx)/Y0; A = sim.A(idx)/Y0; Y = sim.Y(idx)/Y0; q = sim.q(idx);
    H0 = q .* H; Wt = sim.W(idx)/Y0;
    fprintf(' lag %d: median u1 %.4f, 1-u2 %.5f, u3 %.3f, q %.3f | X %.3f, Y %.3f, A %.2f, H %.2f, H0 %.2f, W %.2f (entry income units); c_frac %.3f, pi %.3f\n', ...
        lag, median(u1), median(1 - u2), median(sim.sA(idx)./sAH), median(q), median(X), median(Y), median(A), median(H), median(H0), median(Wt), ...
        median(sim.c_frac(idx), 'omitnan'), median(sim.pi(idx), 'omitnan'));
end
% Equity at bankruptcy: house minus the outstanding annuity mortgage on H0
rows = k; tt = ab_t(k); idx = sub2ind([N p.T], rows, tt);
H = sim.H(idx)/Y0; H0 = sim.q(idx).*H;
n_m = 30; r_m = p.r_m;
left = max(n_m - (tt - 1), 0);
bal = H0 .* (1 - (1 + r_m).^(-left)) / r_m .* (r_m ./ (1 - (1 + r_m).^(-n_m)));   % outstanding balance of a 30-year annuity
fprintf('\nAt bankruptcy: median house %.2f, outstanding mortgage %.2f, equity %.2f, pension pot %.2f, income %.2f (entry income units)\n', ...
    median(H), median(bal), median(H - bal), median(sim.A(idx)/Y0), median(sim.Y(idx)/Y0));
fprintf('Share with positive equity %.3f; median equity / floor consumption per year %.0f\n', mean(H - bal > 0), median((H - bal) ./ (sim.C(idx)/Y0)));
fprintf('Median income at bankruptcy relative to the median at that age: %.2f\n', median(sim.Y(idx) ./ arrayfun(@(s) median(sim.Y(:, s)), tt)));
