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

checks = {@params_derive, @ladder_reaches_production, @ladder_fields, @ladder_branches, ...
          @income_profile, @income_table, @tenure_arms, @housing_corr_by_tenure, @q_axis_where_live, ...
          @nibud_rule};
if opts.solve
    checks = [checks, {@collapsed_axes_exact, @nohousing_ignores_housing, @smoke_both_tenures, ...
                       @nohousing_arms_corr, @annuity_flat_prices, @annuity_payment_pv, ...
                       @figures_render}];
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
q.r = 0.02; q.retirement_age = 65; q.kappa_base = 0.1; q.h_mult = 9; q.h_rule = 'fixed';
q = config.derive(q);
assert(abs(q.Rf - 1.02) < 1e-15, 'Rf not rebuilt');
assert(q.t_ret == 41 && numel(q.tau_S) == q.T - 1 && q.tau_S(41) == 0, 'glide not rebuilt');
assert(all(q.kappa(q.t_ret:end) == 0) && max(q.kappa) < 0.1, 'kappa not rebuilt');
assert(abs(max(q.u1_grid) - 0.3) < 1e-12, 'u1 axis not rebuilt for h_mult');
end

function ladder_reaches_production()
% The last step of the default ladder is the production calibration.
S = ladder.steps();
p = ladder.params(S(end).name);
assert(ladder.same_calibration(p, config.params()), ...
    'the last ladder step differs from config.params');
end

function ladder_fields()
% Every step builds, and a misspelt override is refused.
S = ladder.steps();
for k = 1:numel(S), ladder.params(S(k).name); end
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

function ladder_branches()
% The DC steps build on the baseline without housing and the housing steps
% have no DC pillar; the combined step has both. The annuity mortgage is a
% step of its own between housing and the housing correlations, numbered 7b,
% so the steps after it keep their numbers. The three funds are all bonds,
% all stocks, and the production glide.
S = ladder.steps();
assert(ladder.parent('dc_bonds') == ladder.index('corr_SL'), 'dc_bonds parent');
assert(ladder.parent('pension') == ladder.index('housing_corr'), 'pension parent');
assert(ladder.parent('housing') == ladder.index('corr_SL'), 'housing parent');
assert(ladder.parent('annuity') == ladder.index('housing'), 'annuity parent');
assert(ladder.parent('housing_corr') == ladder.index('annuity'), 'housing_corr parent');
assert(ladder.index('7b') == ladder.index('annuity') && ladder.index(8) == ladder.index('housing_corr') ...
    && ladder.index(16) == numel(S), 'step numbers');
assert(strcmp(ladder.params('housing').mortgage, 'proportional') && ...
    strcmp(ladder.params('annuity').mortgage, 'annuity') && ...
    strcmp(ladder.params('housing_corr').mortgage, 'annuity'), 'mortgage contract along the ladder');
for k = ladder.index('dc_bonds') : ladder.index('aow')
    p = ladder.params(S(k).name);
    assert(p.h_mult == 0 && p.kappa_base == 0.186, '%s: DC pillar without housing', S(k).name);
end
for k = [ladder.index('housing'), ladder.index('annuity'), ladder.index('housing_corr')]
    p = ladder.params(S(k).name);
    assert(p.kappa_base == 0 && p.replacement == 0.68212, '%s: housing without DC', S(k).name);
end
p = ladder.params('pension');
assert(p.h_mult > 0 && p.kappa_base > 0 && p.replacement == 0.307, 'pension combines both');
assert(ladder.params('dc_glide').replacement == 0.68212 && ladder.params('aow').replacement == 0.307, ...
    'replacement along the DC branch');
assert(all(config.tau_effective(ladder.params('dc_bonds')) == 0), 'all-bond fund');
assert(all(config.tau_effective(ladder.params('dc_stocks')) == 1), 'all-stock fund');
assert(isequal(config.tau_effective(ladder.params('dc_glide')), config.tau_effective(config.params())), ...
    'glide fund differs from production');
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
    p = ladder.params(S(k).name);
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

function housing_corr_by_tenure()
% At the housing-correlation step the quadrature nodes carry the tenure's
% correlations of the H shock with income and with the stock return, and
% the step before it has none.
S = ladder.steps();
for k = [ladder.index('housing'), ladder.index('housing_corr')]
    for owner = [false true]
        p = ladder.params(S(k).name); p.is_owner = owner; p = config.derive(p);
        sk = grids.shock_grid(p); w = sk.joint.w(:) / sum(sk.joint.w);
        lh = log(sk.joint.R_H(:)); ly = sk.joint.eps_Y_unit(:); ls = log(sk.joint.R_S(:));
        wc = @(x, y) sum(w .* (x - sum(w .* x)) .* (y - sum(w .* y))) / ...
             sqrt(sum(w .* (x - sum(w .* x)).^2) * sum(w .* (y - sum(w .* y)).^2));
        [cHL, cSH] = config.h_corr(p);
        assert(abs(wc(ly, lh) - cHL) < 1e-10 && abs(wc(ls, lh) - cSH) < 1e-10, ...
            'step %d, owner %d: node correlations %.4f, %.4f against %.4f, %.4f', ...
            k, owner, wc(ly, lh), wc(ls, lh), cHL, cSH);
        if k == ladder.index('housing'), assert(cHL == 0 && cSH == 0, 'step 7 should have none'); end
    end
end
p = ladder.params('housing_corr'); q = p; q.is_owner = true;
[a, b] = config.h_corr(p); [c, d] = config.h_corr(q);
assert(isequal([a b c d], [0.06 0.43 0.09 0.24]), 'tenure selection of the housing correlations');
end

function q_axis_where_live()
% q = H0/H is a state only for an owner with the annuity mortgage, while it
% runs, or with maintenance on the purchase price, at every age. Renters,
% steps without housing and step 7 keep the single node q = 1.
for name = {'corr_SL', 'housing', 'annuity', 'housing_corr'}
    for owner = [false true]
        p = ladder.params(name{1}); p.is_owner = owner; p = config.derive(p);
        live = owner && any(strcmp(name{1}, {'annuity', 'housing_corr'}));
        assert((p.N_q > 1) == live, '%s, owner %d: %d q nodes', name{1}, owner, p.N_q);
        if live
            assert(isequal(find(p.q_live).', 1:p.N_mort), '%s: q live in the wrong years', name{1});
        else
            assert(isequal(p.q_grid, 1) && ~any(p.q_live), '%s, owner %d: q axis', name{1}, owner);
        end
    end
end
p = ladder.params('annuity'); p.is_owner = true; p.maint_on_purchase = true; p = config.derive(p);
assert(all(p.q_live) && any(p.q_grid == 1) && p.N_q == p.grid_dims(4) + 1, ...
    'maintenance on the purchase price: q live at every age, with q = 1 spliced in');
end

function nibud_rule()
% The lookup reproduces cells of the workbook's maximum-mortgage table (box 1,
% below AOW age, rates at the bracket midpoints); the EUR 17,000 increase
% applies only above the first income row. Under the rule each tenure's house
% at entry is the lookup at its own income at 25 and r_m. Steps 7-15 keep 4.
cells = [30000 0.0325 110866.9563963191; 39000 0.0425 155913.3572837433; ...
         74000 0.0325 332983.8293146786; 125000 0.0675 517140.9975474549];
for k = 1:size(cells, 1)
    M = config.nibud_lti(cells(k, 1), cells(k, 2), false) * cells(k, 1);
    assert(abs(M / cells(k, 3) - 1) < 1e-12, 'workbook cell %d: %.2f against %.2f', k, M, cells(k, 3));
end
assert(config.nibud_lti(30000, 0.0348, true) == config.nibud_lti(30000, 0.0348, false), ...
    'the increase applied at the first income row');
assert(abs((config.nibud_lti(39763, 0.0348, true) - config.nibud_lti(39763, 0.0348, false)) * 39763 - 17000) < 1e-8, ...
    'the increase is not EUR 17,000');
expect = struct('owner', 4.446, 'renter', 4.155);
for owner = [true false]
    p = config.params(false); p.is_owner = owner; p = config.derive(p);
    Y0 = exp(config.income_profile(p)); Y0 = Y0(1);
    assert(p.h_mult == config.nibud_lti(Y0, p.r_m, p.nibud_extra), 'owner %d: h_mult is not the lookup', owner);
    if owner, e = expect.owner; else, e = expect.renter; end
    assert(abs(p.h_mult - e) < 5e-4, 'owner %d: h_mult %.4f against %.3f', owner, p.h_mult, e);
    for name = {'housing', 'box3'}
        q = ladder.params(name{1}); q.is_owner = owner; q = config.derive(q);
        assert(q.h_mult == 4, '%s, owner %d: house not at 4 times income', name{1}, owner);
    end
end
q = ladder.params('cgm'); q.h_mult = 4; q.h_rule = 'nibud';
threw = false;
try
    config.derive(q);
catch err
    threw = strcmp(err.identifier, 'derive:poly_nibud');
end
assert(threw, 'the Nibud rule accepted income not in euros');
end

function collapsed_axes_exact()
% Without housing and DC, u2 = u3 = 0 on every path. Solving on the collapsed
% {0,1} axes must give the same policy on that line as a fuller cube. Solved
% with active-set and the sweep: interior-point stops within about 0.005 of the
% equity share where it does not matter (households that consume everything),
% and the objective scaling differs between the two cubes, so it would test the
% optimiser's tolerance rather than the axes.
p = ladder.params('cgm');
p.grid_dims = [8 6 5 3]; p.gh_n = 3;
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

function nohousing_ignores_housing()
% A step without housing must not depend on any housing parameter, not even
% through the nodes no household occupies: changing them all leaves the
% solution bit-identical, for both tenures.
for owner = [false true]
    p = ladder.params('corr_SL'); p.is_owner = owner;
    p.grid_dims = [6 5 4 3]; p.gh_n = 3; p = config.derive(p);
    q = p;
    q.mu_H_level = 0.01; q.sigma_H_level = 0.2; q.mu_R_level = 0.03; q.sigma_R_level = 0.1;
    q.alpha = 0.1; q.theta = 0.05; q.r_m = 0.05; q.sell_cost = 0.1;
    q.mortgage = 'proportional'; q.maint_on_purchase = true;
    q.corr_HL = 0.5; q.corr_HL_rent = 0.5; q.corr_SH = 0.5; q.corr_SH_rent = 0.5;
    q = config.derive(q);
    [pf, sk, an] = config.model_inputs(p);
    [qf, qk, qn] = config.model_inputs(q);
    A = solver.solve(p, pf, sk, an, false);
    B = solver.solve(q, qf, qk, qn, false);
    assert(isequaln(A.V, B.V) && isequaln(A.c_pol, B.c_pol) && isequaln(A.pi_pol, B.pi_pol), ...
        'owner %d: the housing parameters moved a solve without housing', owner);
end
end

function smoke_both_tenures()
% A small solve and simulation for each tenure: finite, in range, on the grid.
for owner = [false true]
    p = config.params();
    p.grid_dims = [6 5 4 3]; p.gh_n = 3; p.is_owner = owner;
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
p.grid_dims = [6 5 4 3]; p.gh_n = 3;
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

function annuity_flat_prices()
% With flat house prices q stays at 1, so on the q = 1 slice the annuity and
% the proportional contract are the same problem: V, c and pi agree to 1e-10
% (V relative to its size).
p = ladder.params('annuity'); p.is_owner = true;
p.mu_H_level = 0; p.sigma_H_level = 0;
p.grid_dims = [6 5 4 3]; p.gh_n = 3; p = config.derive(p);
q = p; q.mortgage = 'proportional'; q = config.derive(q);
assert(p.N_q > 1 && q.N_q == 1, 'q nodes: annuity %d, proportional %d', p.N_q, q.N_q);
[pf, sk, an] = config.model_inputs(p);
A = solver.solve(p, pf, sk, an, false);
B = solver.solve(q, pf, sk, an, false);
at1 = @(X) reshape(X(:, :, :, p.q_grid == 1, :), [], 1);
dV  = max(abs(at1(A.V) - B.V(:)) ./ abs(B.V(:)));
dc  = max(abs(at1(A.c_pol) - B.c_pol(:)));
dpi = max(abs(at1(A.pi_pol) - B.pi_pol(:)));
assert(dV < 1e-10 && dc < 1e-10 && dpi < 1e-10, ...
    'annuity against proportional at q = 1: dV %.2g, dc %.2g, dpi %.2g', dV, dc, dpi);
end

function annuity_payment_pv()
% In the step-7b owner panel each household pays m * LTV * H0 in every year
% to N_mort and nothing after, and the payments are worth the loan at r_m.
p = ladder.params('annuity'); p.is_owner = true;
p.grid_dims = [6 5 4 3]; p.gh_n = 3; p = config.derive(p);
r = model.run(p, N_sim = 200, keep_sim = true, verbose = false);
n = p.N_mort; H0 = r.sim.H(:, 1); pay = r.sim.m_pay;
dpay = max(abs(pay(:, 1:n) ./ (p.m_rate_path(1) * H0) - 1), [], 'all');
assert(dpay < 1e-12, 'payment differs from m * LTV * H0 by %.2g', dpay);
assert(all(pay(:, n+1:end) == 0, 'all'), 'a payment after year %d', n);
pv = sum(pay(:, 1:n) ./ (1 + p.r_m) .^ (1:n), 2);
dpv = max(abs(pv ./ (p.LTV * H0) - 1));
assert(dpv < 1e-12, 'present value differs from the loan by %.2g', dpv);
assert(sum(r.checks.offgrid) == 0, 'off-grid lookups: %s', mat2str(r.checks.offgrid));
end

function figures_render()
% The dashboard and the overlay draw for a no-housing step and for an owner
% with housing and DC, and the overlay takes results on different grids and
% optimisers. The mortgage figure draws for the owner.
q = ladder.params('cgm'); q.grid_dims = [6 5 4 3]; q.gh_n = 3; q = config.derive(q);
p = config.params(false); p.is_owner = true; p.grid_dims = [6 5 4 3]; p.gh_n = 3; p = config.derive(p);
p2 = p; p2.grid_dims = [7 5 4 3]; p2.fmincon_algorithm = 'sqp'; p2 = config.derive(p2);
r = {model.run(q, N_sim = 300, verbose = false), model.run(p, N_sim = 300, verbose = false), ...
     model.run(p2, N_sim = 300, verbose = false)};
d = tempname; mkdir(d); cleanup = onCleanup(@() rmdir(d, 's'));
figures.dashboard(r{1}, fullfile(d, 'a.png'));
figures.dashboard(r{2}, fullfile(d, 'b.png'));
figures.compare(r(2:3), {'active-set', 'sqp, finer u1'}, 'test', fullfile(d, 'c.png'));
figures.compare(r([1 2]), {'cgm', 'production'}, 'test', fullfile(d, 'd.png'));
figures.step_dashboard(r{1}, r{2}, {'cgm', 'production'}, 'test', fullfile(d, 'e.png'), changes = {'x: 1 -> 2'});
G = struct('name', {'A', 'B'}, 'rs', {{r{3}}, {r{3}, r{2}}}, 'labels', {{'sqp'}, {'sqp', 'same'}});
figures.robustness(r{2}, 'reference', G, 'test', fullfile(d, 'f.png'));
figures.mortgage(r{2}, fullfile(d, 'g.png'));
assert(all(isfile(fullfile(d, {'a.png', 'b.png', 'c.png', 'd.png', 'e.png', 'f.png', 'g.png'}))), ...
    'a figure was not written');
end
