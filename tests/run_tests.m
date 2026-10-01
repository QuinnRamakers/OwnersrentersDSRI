function n_fail = run_tests(opts)
%RUN_TESTS  Checks on the calibration machinery and the solver.
%
%   run_tests                 % everything (a few minutes on a small grid)
%   run_tests(solve=false)    % only the checks that need no solve
%   n = run_tests(...)        % return the failure count instead of erroring
%
%   From the repository root:  addpath tests; run_tests
%   Headless:                  matlab -batch "addpath tests; run_tests"

arguments
    opts.solve (1,1) logical = true
end

checks = {@params_derive, @ladder_reaches_production, @ladder_fields, @income_profile, ...
          @income_table};
if opts.solve
    checks = [checks, {@collapsed_axes_exact, @smoke_both_tenures}];
end
n_fail = 0;
for i = 1:numel(checks)
    name = func2str(checks{i});
    t0 = tic;
    try
        checks{i}();
        fprintf('PASS  %-28s %6.1f s\n', name, toc(t0));
    catch err
        n_fail = n_fail + 1;
        fprintf('FAIL  %-28s %6.1f s  %s\n', name, toc(t0), err.message);
    end
end
fprintf('%d of %d checks failed.\n', n_fail, numel(checks));
if nargout == 0 && n_fail > 0
    error('run_tests:failed', '%d checks failed.', n_fail);
end
end

% ------------------------------------------------------------------------
function params_derive()
% derive is idempotent and every derived field is rebuilt from primitives.
p = config.params();
assert(isequaln(config.derive(p), p), 'derive changed an already-derived p');
q = config.params(false);
q.r = 0.02; q.retirement_age = 65; q.kappa_base = 0.1; q.h_mult = 9;
q = config.derive(q);
assert(abs(q.Rf - 1.02) < 1e-15, 'Rf not rebuilt');
assert(q.t_ret == 41 && numel(q.tau_S) == q.T - 1 && q.tau_S(41) == 0, 'glide not rebuilt');
assert(all(q.kappa(q.t_ret:end) == 0) && max(q.kappa) < 0.1, 'kappa not rebuilt');
assert(abs(max(q.u1_grid) - 0.3) < 1e-12, 'u1 axis not rebuilt for h_mult');
end

function ladder_reaches_production()
% The last step of the default ladder is the production calibration.
S = ladder.steps();
p = ladder.params(numel(S));
assert(ladder.same_calibration(p, config.params()), ...
    'the last ladder step differs from config.params');
end

function ladder_fields()
% Every step builds, and a misspelt override is refused.
S = ladder.steps();
for k = 1:numel(S), ladder.params(k); end
assert(ladder.index('housing') > ladder.index('cgm'), 'step order');
bad = S(1); bad.set = struct('gama', 5);
threw = false;
try
    ladder.params(1, bad);
catch err
    threw = strcmp(err.identifier, 'ladder:unknown_field');
end
assert(threw, 'a misspelt override was accepted');
end

function income_profile()
% BKV lookup: anchored at the age-25 wage in 2025 euros, rising through the
% forties, and stepping down by the replacement rate at retirement.
p = config.params();
logY = config.income_profile(p);
Y = exp(logY);
assert(abs(Y(1) - 33000 * p.income_price_factor) < 1e-6 * Y(1), 'anchor');
assert(all(diff(Y(1:20)) > 0), 'profile should rise to 45');
assert(abs(Y(p.t_ret) / Y(p.t_ret - 1) - p.replacement) < 1e-12, 'replacement step');
end

function income_table()
% The BKV lookup and its extrapolation edges against independently computed
% values, all three sexes (tests/verify_income_profile.m).
out = evalc('verify_income_profile');
assert(contains(out, 'ALL CHECKS PASSED'), 'verify_income_profile reported a failure');
end

function collapsed_axes_exact()
% Without housing and DC, u2 = u3 = 0 on every path. Solving on the collapsed
% {0,1} axes must give the same policy on that line as a fuller cube.
p = ladder.params('cgm');
p.grid_dims = [8 6 5]; p.gh_n = 3;
p = config.derive(p);
assert(p.N_u2 == 2 && p.N_u3 == 2, 'axes did not collapse');
[pf, sk, an] = config.model_inputs(p);
solA = solver.solve(p, pf, sk, an, false);
q = p;
q.u2_grid = linspace(0, 1, 5).'; q.u3_grid = linspace(0, 1, 4).';
q.N_u2 = 5; q.N_u3 = 4;
solB = solver.solve(q, pf, sk, an, false);
dc  = max(abs(squeeze(solA.c_pol(:, 1, 1, :))  - squeeze(solB.c_pol(:, 1, 1, :))), [], 'all');
dpi = max(abs(squeeze(solA.pi_pol(:, 1, 1, :)) - squeeze(solB.pi_pol(:, 1, 1, :))), [], 'all');
assert(dc < 1e-4 && dpi < 1e-3, 'collapsed axes moved the policy: dc %.2g, dpi %.2g', dc, dpi);
end

function smoke_both_tenures()
% A small solve and simulation for each tenure: finite, in range, on the grid.
for owner = [false true]
    p = config.params();
    p.grid_dims = [6 5 4]; p.gh_n = 3; p.is_owner = owner;
    p = config.derive(p);
    r = model.run(p, N_sim = 500, verbose = false);
    assert(all(isfinite(r.sol.V(:))), 'non-finite value');
    % fmincon respects bounds to its tolerance, so allow a hair either side;
    % the simulator clamps.
    assert(all(r.sol.c_pol(:) > 0 & r.sol.c_pol(:) <= 1 + 1e-6), 'c out of range');
    assert(all(r.sol.pi_pol(:) >= -1e-6 & r.sol.pi_pol(:) <= 1 + 1e-6), 'pi out of range');
    assert(all(isfinite(r.summary.C.mean)) && all(r.summary.C.mean > 0), 'consumption');
    assert(sum(r.checks.offgrid) == 0, 'off-grid lookups on the default grid');
end
end
