function neural_tests()
%NEURAL_TESTS  Checks of the MATLAB side of the neural-network branch.
%
%   From the repository root: matlab -batch "addpath tests; neural_tests"
%
%   Kept apart from run_tests, which stays as it is on main. Checks that
%   neural.draw_shocks gives the draws of simulate.paths_lna for the same
%   seed: the stock returns, the income paths and (for households never
%   bankrupt) the house or rent paths built from them equal the panel's in
%   every bit, on quick-grid solves of step 1 and of step 13 for owners.

cases = {{1, false}, {13, true}};
n_fail = 0;
for i = 1:numel(cases)
    p = ladder.params(cases{i}{1});
    p.is_owner = cases{i}{2};
    p.grid_dims = [8 6 6 4];
    p.gh_n = 3;
    p = config.derive(p);
    r = model.run(p, N_sim=100, verbose=false);
    N = 500; seed = 7;
    sim = simulate.paths_lna(r.p, r.profile, r.sol, r.ann_price, N, seed, r.p.b0);
    d = neural.draw_shocks(r.p, N, seed);

    R_S = exp(p.mu_S + p.sigma_S * d.eps_S);
    Y = zeros(N, p.T); Y(:, 1) = sim.Y(:, 1);
    [mu_HR, sigma_HR] = config.h_process(p);
    H = zeros(N, p.T); H(:, 1) = sim.H(:, 1);
    for t = 1:p.T-1
        if t < p.t_ret - 1
            Y(:, t+1) = Y(:, t) .* exp(r.profile.mu_growth(t) + r.profile.sigma_l_log(t) .* d.eps_Y(:, t));
        elseif t == p.t_ret - 1
            Y(:, t+1) = p.replacement .* Y(:, t);
        else
            Y(:, t+1) = Y(:, t);
        end
        H(:, t+1) = exp(mu_HR + sigma_HR * d.eps_H(:, t)) .* H(:, t);
    end
    solvent = ~any(sim.absorbed, 2);
    ok = [isequal(R_S, sim.R_S), isequal(Y, sim.Y), isequal(H(solvent, :), sim.H(solvent, :))];
    names = {'stock returns', 'income paths', 'house paths'};
    for k = 1:3
        fprintf('step %d, %s: %s %s\n', cases{i}{1}, model.tenure(p), names{k}, ...
            ternary(ok(k), 'equal in every bit', 'DIFFER'));
    end
    n_fail = n_fail + sum(~ok);
end
fprintf('neural_tests: %d of %d checks failed.\n', n_fail, 3 * numel(cases));
assert(n_fail == 0, 'neural_tests:failed', '%d checks failed.', n_fail);
end

function s = ternary(c, a, b)
if c, s = a; else, s = b; end
end
