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
          @income_table, @tenure_arms};
if opts.solve
    checks = [checks, {@collapsed_axes_exact, @smoke_both_tenures, @nohousing_arms_corr, @figures_render}];
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
% DHS cubic in 2025 euros, by tenure: the level at 25 and at the peak against
% the values computed from the published coefficients, the peak age, the
% tenure's shock std, and the step down by the replacement rate at retirement.
target = struct('owner',  struct('y25', 39763, 'peak', 50, 'ypeak', 74656, 'sigma', 0.0816), ...
                'renter', struct('y25', 30098, 'peak', 49, 'ypeak', 52013, 'sigma', 0.0843));
for owner = [true false]
    p = config.params(false); p.is_owner = owner; p = config.derive(p);
    if owner, e = target.owner; else, e = target.renter; end
    [logY, ~, sig] = config.income_profile(p);
    Y = exp(logY); ages = p.age0 + (0 : p.T - 1).';
    work = 1 : p.t_ret - 1;
    [ypk, ipk] = max(Y(work));
    assert(abs(Y(1) / e.y25 - 1) < 1e-4, 'level at 25: %.0f against %.0f', Y(1), e.y25);
    assert(ages(ipk) == e.peak, 'peak at %d, expected %d', ages(ipk), e.peak);
    assert(abs(ypk / e.ypeak - 1) < 1e-4, 'peak level %.0f against %.0f', ypk, e.ypeak);
    assert(sig(1) == e.sigma && all(sig(p.t_ret - 1 : end) == 0), 'shock std');
    assert(abs(Y(p.t_ret) / Y(p.t_ret - 1) - p.replacement) < 1e-12, 'replacement step');
end
end

function tenure_arms()
% Steps whose renter and owner income fields agree keep one no-housing arm;
% once they differ, a step without housing has a renter and an owner arm.
S = ladder.steps();
for k = 1:numel(S)
    p = ladder.params(k);
    split = ~isequal(p.income_coef, p.income_coef_rent) || p.sigma_l_log ~= p.sigma_l_log_rent;
    assert(model.tenures_differ(p) == (p.h_mult > 0 || split), 'step %d arms', k);
    if k < ladder.index('income')
        assert(strcmp(model.tenure(p), 'nohousing'), 'step %d should keep one arm', k);
    end
end
p = ladder.params('income');
q = p; q.is_owner = true;
assert(strcmp(model.tenure(p), 'nohousing_renter') && strcmp(model.tenure(q), 'nohousing_owner'), ...
    'labels of the no-housing arms');
end

function income_table()
% The BKV lookup and its extrapolation edges against independently computed
% values, all three sexes (tests/verify_income_profile.m).
out = evalc('verify_income_profile');
assert(contains(out, 'ALL CHECKS PASSED'), 'verify_income_profile reported a failure');
end

function collapsed_axes_exact()
% Without housing and DC, u2 = u3 = 0 on every path. Solving on the collapsed
% {0,1} axes must give the same policy on that line as a fuller cube. Solved
% with active-set and the sweep: interior-point stops within about 0.005 of the
% equity share where it does not matter (households that consume everything),
% and the objective scaling differs between the two cubes, so it would test the
% optimiser's tolerance rather than the axes.
p = ladder.params('cgm');
p.grid_dims = [8 6 5]; p.gh_n = 3;
p.fmincon_algorithm = 'active-set'; p.use_refine = true;
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

function nohousing_arms_corr()
% The step that adds the income-stock correlation, on a small grid: two arms
% that differ, and the correlation on the quadrature nodes and in the panel
% equal to corr_SL.
p = ladder.params('corr_SL');
p.grid_dims = [6 5 4]; p.gh_n = 3;
C = struct();
for owner = [false true]
    pa = p; pa.is_owner = owner; pa = config.derive(pa);
    r = model.run(pa, N_sim = 2000, verbose = false);
    assert(all(isfinite(r.sol.V(:))), 'non-finite value');
    assert(abs(r.checks.corr_SL_nodes - p.corr_SL) < 1e-10, 'nodes correlation %.4f', r.checks.corr_SL_nodes);
    assert(abs(r.checks.corr_SL_sim - p.corr_SL) < 0.01, 'panel correlation %.4f', r.checks.corr_SL_sim);
    C.(r.tenure) = r;
end
assert(isfield(C, 'nohousing_renter') && isfield(C, 'nohousing_owner'), 'arm labels');
assert(~isequal(C.nohousing_renter.sol.c_pol, C.nohousing_owner.sol.c_pol), 'the arms should differ');
end

function figures_render()
% The dashboard and the overlay draw for a no-housing step and for an owner
% with housing and DC, and the overlay takes results on different grids and
% optimisers.
q = ladder.params('cgm'); q.grid_dims = [6 5 4]; q.gh_n = 3; q = config.derive(q);
p = config.params(false); p.is_owner = true; p.grid_dims = [6 5 4]; p.gh_n = 3; p = config.derive(p);
p2 = p; p2.grid_dims = [7 5 4]; p2.fmincon_algorithm = 'sqp'; p2 = config.derive(p2);
r = {model.run(q, N_sim = 300, verbose = false), model.run(p, N_sim = 300, verbose = false), ...
     model.run(p2, N_sim = 300, verbose = false)};
d = tempname; mkdir(d); cleanup = onCleanup(@() rmdir(d, 's'));
figures.dashboard(r{1}, fullfile(d, 'a.png'));
figures.dashboard(r{2}, fullfile(d, 'b.png'));
figures.compare(r(2:3), {'active-set', 'sqp, finer u1'}, 'test', fullfile(d, 'c.png'));
figures.compare(r([1 2]), {'cgm', 'production'}, 'test', fullfile(d, 'd.png'));
assert(all(isfile(fullfile(d, {'a.png', 'b.png', 'c.png', 'd.png'}))), 'a figure was not written');
end
