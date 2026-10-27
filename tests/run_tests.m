function n_fail = run_tests(opts)
%RUN_TESTS  Checks on the calibration machinery and the solver.
%
%   run_tests                 % everything (a few minutes on a small grid)
%   run_tests(solve=false)    % only the checks that need no solve
%   n = run_tests(...)        % return the failure count instead of erroring
%
%   From the repository root:  addpath tests; run_tests
%   Headless:                  matlab -batch "addpath tests; run_tests"
%
%   floor_off_identical compares against a solve saved before the absorbing
%   floor was added; it runs only when CGM_FLOOR_BASELINE names that file, and
%   is reported as SKIP otherwise. bequest_off_identical does the same with
%   CGM_BEQUEST_BASELINE, the solve saved before the last period took the
%   bequest as any other (on the DSRI pod, /Solutionstorage/cgm_baselines).

arguments
    opts.solve (1,1) logical = true
end

checks = {@params_derive, @ladder_reaches_production, @ladder_fields, @ladder_branches, ...
          @income_profile, @income_table, @tenure_arms, @housing_corr_by_tenure, @q_axis_where_live, ...
          @nibud_rule, @floor_derive};
if opts.solve
    checks = [checks, {@collapsed_axes_exact, @nohousing_ignores_housing, @smoke_both_tenures, ...
                       @nohousing_arms_corr, @annuity_flat_prices, @annuity_payment_pv, ...
                       @figures_render, @floor_off_identical, @floor_absorbing, @floor_node_test, ...
                       @bequest_off_identical, @bequest_last_year, @bequest_bankrupt}];
    % Some checks call the solver without model.run, so parfor would open
    % MATLAB's default pool: processes, which run out of memory on the DSRI
    % pod. Open the thread pool model.run uses instead.
    if isempty(gcp('nocreate')), utility.start_pool(); end
end
n_fail = 0; n_skip = 0;
for i = 1:numel(checks)
    name = func2str(checks{i});
    t0 = tic;
    try
        checks{i}();
        fprintf('PASS  %-28s %6.1f s\n', name, toc(t0));
    catch err
        if strcmp(err.identifier, 'run_tests:skip')
            n_skip = n_skip + 1;
            fprintf('SKIP  %-28s %6.1f s  %s\n', name, toc(t0), err.message);
            continue
        end
        n_fail = n_fail + 1;
        fprintf('FAIL  %-28s %6.1f s  %s\n', name, toc(t0), err.message);
    end
end
fprintf('%d of %d checks failed, %d skipped.\n', n_fail, numel(checks), n_skip);
if nargout == 0 && n_fail > 0
    error('run_tests:failed', '%d checks failed.', n_fail);
end
end

% ------------------------------------------------------------------------
function params_derive()
% derive is idempotent and every derived field is rebuilt from primitives,
% also when the primitives change on an already-derived p.
p = config.params();
assert(isequaln(config.derive(p), p), 'derive changed an already-derived p');
q = config.params();
q.r = 0.02; q.retirement_age = 65; q.kappa_base = 0.1; q.h_rule = 'fixed'; q.h_fixed = 9;
q = config.derive(q);
assert(q.h_mult == 9, 'h_mult not rebuilt from h_fixed');
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
    && ladder.index(18) == numel(S), 'step numbers');
assert(~ladder.params('nibud').maint_on_purchase && ladder.params('maint_purchase').maint_on_purchase, ...
    'maintenance on the current value to step 16, on the purchase price at step 17');
assert(~ladder.params('maint_purchase').floor_absorbing && ladder.params('floor').c_min == 5000, ...
    'the yearly top-up to step 17, the absorbing floor at step 18');
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
% h_mult is derived, so a calibration comparison does not depend on whether
% p was derived again after a tenure switch (ladder.load, ladder.report), and
% switching the rule on a derived p returns to h_fixed.
p = config.params();
q = p; q.is_owner = true;
o = config.derive(q);
assert(ladder.same_calibration(o, q) && o.h_mult ~= p.h_mult, 'tenure switch: same_calibration depends on derive');
q = p; q.h_rule = 'fixed'; q = config.derive(q);
assert(q.h_mult == q.h_fixed, 'switching to fixed kept the Nibud multiple');
q = p; q.h_rule = 'none'; q = config.derive(q);
assert(q.h_mult == 0 && strcmp(model.tenure(q), 'nohousing_renter'), 'h_rule none');
% model.run refuses a tenure switch without derive, also where kappa is the
% same for both tenures (no DC pillar)
q = ladder.params('housing_corr'); q.h_rule = 'nibud'; q = config.derive(q);
q.is_owner = true;
assert(threw_id(@() model.run(q, verbose = false), 'model:run_not_derived'), ...
    'model.run accepted an underived tenure switch');
% refusals: Nibud with income not in euros, 'fixed' without a multiple, an unknown rule
q = ladder.params('cgm'); q.h_rule = 'nibud';
assert(threw_id(@() config.derive(q), 'derive:poly_nibud'), 'the Nibud rule accepted income not in euros');
q = config.params(false); q.h_rule = 'fixed'; q.h_fixed = 0;
assert(threw_id(@() config.derive(q), 'derive:h_fixed'), 'fixed with h_fixed = 0 accepted');
q = config.params(false); q.h_rule = 'nibud2025';
assert(threw_id(@() config.derive(q), 'derive:h_rule'), 'unknown h_rule accepted');
end

function floor_derive()
% The absorbing floor's derived paths. D_abs is the explicit discounted
% survival sum, G_abs the explicit discounted chance of dying at the end of
% each year, and D_beq is D_abs without a bequest motive; derive refuses a
% bankrupt bequest that is not positive. With c_min the share is the same for both tenures and the
% floor at the owners' deterministic profile is c_min at every age; with
% phi_abs the share is phi_abs to 66 and phi_abs / replacement after; off, it
% is phi_floor. derive refuses both positive, c_min with income not in euros,
% negative values and a floor not above phi_floor.
p = config.params();
assert(p.floor_absorbing && p.c_min == 5000 && numel(p.phi_path) == p.T, ...
    'production: the absorbing floor is not at EUR 5,000');
q = ladder.params('maint_purchase');
assert(~q.floor_absorbing && all(q.phi_path == q.phi_floor), 'step 17: the absorbing floor is not off');
pv = config.survival(p);
S = cumprod([1; pv]);
for t = 1:p.T
    k = (t:p.T).';
    D = sum(p.beta .^ (k - t) .* S(k) / S(t));
    G = sum(p.beta .^ (k - t + 1) .* S(k) / S(t) .* (1 - pv(k)));
    assert(abs(p.D_abs(t) / D - 1) < 1e-12, 'D_abs(%d) = %.15g against %.15g', t, p.D_abs(t), D);
    assert(abs(p.G_abs(t) / G - 1) < 1e-12, 'G_abs(%d) = %.15g against %.15g', t, p.G_abs(t), G);
end
assert(p.chi == 0 && isequal(p.D_beq, p.D_abs), 'D_beq is not D_abs without a bequest motive');
q = config.params(false); q.beq_bankrupt = 0;
assert(threw_id(@() config.derive(q), 'derive:beq_bankrupt'), 'a zero bankrupt bequest accepted');
o = config.params(false); o.is_owner = true;  o.c_min = 8000; o = config.derive(o);
r = config.params(false); r.is_owner = false; r.c_min = 8000; r = config.derive(r);
dev = max(abs(o.phi_path .* exp(config.income_profile(o)) / 8000 - 1));
assert(o.floor_absorbing && r.floor_absorbing && dev < 1e-12, 'the floor at the owners'' profile is not c_min (%.2g)', dev);
assert(isequal(o.phi_path, r.phi_path), 'the share differs between the tenures');
q = config.params(false); q.c_min = 0; q.phi_abs = 0.2; q = config.derive(q);
work = 1 : q.t_ret - 1; ret = q.t_ret : q.T;
assert(q.floor_absorbing && all(q.phi_path(work) == 0.2) && ...
    max(abs(q.phi_path(ret) * q.replacement / 0.2 - 1)) < 1e-12, 'phi_abs path');
q = config.params(false); q.c_min = 8000; q.phi_abs = 0.2;
assert(threw_id(@() config.derive(q), 'derive:floor_both'), 'c_min and phi_abs both accepted');
q = ladder.params('cgm'); q.c_min = 8000;
assert(threw_id(@() config.derive(q), 'derive:poly_cmin'), 'c_min accepted with income not in euros');
q = config.params(false); q.c_min = -1;
assert(threw_id(@() config.derive(q), 'derive:floor_negative'), 'negative c_min accepted');
q = config.params(false); q.phi_abs = -0.1;
assert(threw_id(@() config.derive(q), 'derive:floor_negative'), 'negative phi_abs accepted');
q = config.params(false); q.c_min = 1e-3;
assert(threw_id(@() config.derive(q), 'derive:floor_low'), 'a floor below phi_floor accepted');
end

function tf = threw_id(f, id)
tf = false;
try
    f();
catch err
    tf = strcmp(err.identifier, id);
end
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
    q.mortgage = 'proportional'; q.maint_on_purchase = true; q.h_fixed = 9; q.nibud_extra = false;
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
% Households enter with the house (owner) or rent index (renter) at the
% tenure's Nibud multiple, at an exact node of the grid; the owner's first
% payment is the annuity on that house.
for owner = [false true]
    p = config.params();
    p.grid_dims = [6 5 4 3]; p.gh_n = 3; p.is_owner = owner;
    p = config.derive(p);
    r = model.run(p, N_sim = 500, keep_sim = true, verbose = false);
    Y0 = exp(config.income_profile(p)); Y0 = Y0(1);
    assert(p.h_mult == config.nibud_lti(Y0, p.r_m, p.nibud_extra), 'not the Nibud multiple');
    s = r.sim;
    assert(max(abs(s.H(:, 1) ./ (p.h_mult * s.Y(:, 1)) - 1)) < 1e-12, 'H0 is not h_mult * Y0');
    assert(any(abs(p.u1_grid - 1 / (1 + p.h_mult + p.b0)) < 1e-14) && ...
           any(abs(p.u2_grid - p.h_mult / (p.h_mult + p.b0)) < 1e-14), 'entry state is not a node');
    if owner
        assert(max(abs(s.m_pay(:, 1) ./ (p.m_rate_path(1) * s.H(:, 1)) - 1)) < 1e-12, 'first payment');
    end
    r.sim = [];
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
% optimisers, also in its bequest view. The mortgage figure draws for the owner.
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
figures.compare(r([1 2]), {'cgm', 'production'}, 'test', fullfile(d, 'h.png'), view = 'bequest');
figures.step_dashboard(r{1}, r{2}, {'cgm', 'production'}, 'test', fullfile(d, 'e.png'), changes = {'x: 1 -> 2'});
G = struct('name', {'A', 'B'}, 'rs', {{r{3}}, {r{3}, r{2}}}, 'labels', {{'sqp'}, {'sqp', 'same'}});
figures.robustness(r{2}, 'reference', G, 'test', fullfile(d, 'f.png'));
figures.mortgage(r{2}, fullfile(d, 'g.png'));
assert(all(isfile(fullfile(d, {'a.png', 'b.png', 'c.png', 'd.png', 'e.png', 'f.png', 'g.png', 'h.png'}))), ...
    'a figure was not written');
end

function floor_off_identical()
% With the absorbing floor off, step 16 on the small grid, both tenures: the
% value, the policies and every panel field that existed before the change
% are bit-identical to the solve saved at 7b5143d (CGM_FLOOR_BASELINE), with
% that solve's search routine (interior-point, N_c 41, the default until 24
% October 2026) and grid placement (even u1 and u2, pi = 1 where nothing is
% saved, the default until 26 October 2026).
file = getenv('CGM_FLOOR_BASELINE');
if isempty(file) || ~isfile(file)
    error('run_tests:skip', 'CGM_FLOOR_BASELINE does not name the solve saved at 7b5143d');
end
B = load(file);
for owner = [false true]
    p = ladder.params(16); p.is_owner = owner;
    p.grid_dims = [8 6 6 4]; p.gh_n = 3;
    p.fmincon_algorithm = 'interior-point'; p.N_c = 41;
    p.grid_pow = 1; p.grid_pow_u2 = 1; p.pi_nothing_saved = 'one';
    p = config.derive(p);
    r = model.run(p, N_sim = 500, keep_sim = true, verbose = false);
    b = B.(model.tenure(p));
    assert(isequaln(r.sol.V, b.V) && isequaln(r.sol.c_pol, b.c_pol) && isequaln(r.sol.pi_pol, b.pi_pol), ...
        '%s: the solution differs from the baseline', model.tenure(p));
    f = fieldnames(b.sim);
    for i = 1:numel(f)
        assert(isequaln(r.sim.(f{i}), b.sim.(f{i})), '%s: panel field %s differs', model.tenure(p), f{i});
    end
end
end

function bequest_off_identical()
% With chi = 0, production (step 18) for both tenures and the CGM core (step 1)
% on the small grid: the value, the policies and every panel field are
% bit-identical to the solve saved at 3433323 (CGM_BEQUEST_BASELINE), before
% the last period took the bequest as any other period.
file = getenv('CGM_BEQUEST_BASELINE');
if isempty(file) || ~isfile(file)
    error('run_tests:skip', 'CGM_BEQUEST_BASELINE does not name the solve saved at 3433323');
end
B = load(file);
cases = {18, false; 18, true; 1, false};
for k = 1:size(cases, 1)
    p = ladder.params(cases{k, 1}); p.is_owner = cases{k, 2};
    p.grid_dims = [8 6 6 4]; p.gh_n = 3; p = config.derive(p);
    r = model.run(p, N_sim = 500, keep_sim = true, verbose = false);
    name = matlab.lang.makeValidName(sprintf('s%d_%s', cases{k, 1}, model.tenure(p)));
    b = B.(name);
    assert(isequaln(r.sol.V, b.V) && isequaln(r.sol.c_pol, b.c_pol) && isequaln(r.sol.pi_pol, b.pi_pol), ...
        '%s: the solution differs from the baseline', name);
    f = fieldnames(b.sim);
    for i = 1:numel(f)
        assert(isequaln(r.sim.(f{i}), b.sim.(f{i})), '%s: panel field %s differs', name, f{i});
    end
end
end

function bequest_last_year()
% The last period with a bequest motive. (1) Step 1 (no housing, DC pillar or
% taxes) at b = 2.5, chi = b^gamma: death at its end is certain, so the
% household maximises u(c L) + beta chi E[(R(pi) (1-c) L)^(1-gamma)]/(1-gamma).
% The equity share minimises M(pi) = E[R(pi)^(1-gamma)] whatever c, and
% c = 1/(1 + (beta chi M)^(1/gamma)) at every node; the solve matches to 1e-5
% (c) and 1e-3 (pi), and the value at the solved nodes to 1e-8 relative.
% (2) Production owner at b = 2.5, a small solve and panel: finite and in
% range, and solvent households leave a bequest at 100.
p = ladder.params(1); p.chi = 2.5 ^ p.gamma;
p.grid_dims = [8 6 6 4]; p.gh_n = 3; p = config.derive(p);
[profile, shocks, ann_price] = config.model_inputs(p);
[V, c, pi_] = solver.bellman_step_lna(p.T, [], p, profile, shocks, ann_price);
w   = shocks.joint.w(:);
R_S = config.after_tax_stock(p, shocks.joint.R_S(:));
Rf  = (1 + p.r * (1 - p.tau_cg_bond)) * (1 - p.tau_wealth);
M   = @(x) sum(w .* ((1 - x) * Rf + x * R_S) .^ (1 - p.gamma));
pi_star = fminbnd(M, 0, 1, optimset('TolX', 1e-12));
k = p.beta * p.chi * M(pi_star);
c_star = 1 / (1 + k ^ (1 / p.gamma));
assert(max(abs(c(:) - c_star)) < 1e-5, 'c off the closed form %.6f by %.2g', c_star, max(abs(c(:) - c_star)));
assert(max(abs(pi_(:) - pi_star)) < 1e-3, 'pi off the closed form %.4f by %.2g', pi_star, max(abs(pi_(:) - pi_star)));
[g1, g2] = utility.grid_at(p, p.T);
[U1, U2, U3] = ndgrid(g1, g2, p.u3_grid);
sA = U2 .* (1 - U1) .* U3; sX = (1 - U1) .* (1 - U2);
L  = sX + (1 - p.tau_inc) * (U1 + sA / ann_price(p.T));
Vc = L .^ (1 - p.gamma) / (1 - p.gamma) * (c_star ^ (1 - p.gamma) + k * (1 - c_star) ^ (1 - p.gamma));
m  = U2 == 0 | U3 == 1;                       % solved; the rest are copies (no house)
err = max(abs(V(m) ./ Vc(m) - 1));
assert(err < 1e-8, 'the value is off the closed form by %.2g', err);

p = config.params(); p.is_owner = true; p.chi = 2.5 ^ p.gamma;
p.grid_dims = [6 5 4 3]; p.gh_n = 3; p = config.derive(p);
r = model.run(p, N_sim = 500, keep_sim = true, verbose = false);
assert(all(isfinite(r.sol.V(:))), 'non-finite value');
assert(all(r.sol.c_pol(:) > 0 & r.sol.c_pol(:) <= 1 + 1e-6), 'c out of range');
assert(all(r.sol.pi_pol(:) >= -1e-6 & r.sol.pi_pol(:) <= 1 + 1e-6), 'pi out of range');
ok = ~r.sim.absorbed(:, end);
assert(any(ok) && all(r.sim.bequest(ok) > 0), 'a solvent household left no bequest');
end

function bequest_bankrupt()
% The bankrupt household with a bequest motive: step 18, renter, small grid,
% c_min = 10,000, b = 2.5. At every node whose liquid resources fall short of
% the floor, the value is the closed form
% (phi_t u1)^(1-gamma)/(1-gamma) [D_t + chi beq_bankrupt^(1-gamma) G_t] to
% 1e-12 relative, with D_t and G_t summed here from the survival table, at a
% working age, a retired age and the last. The solve is finite and in range
% (pi to 1e-3: active-set can step slightly past its bounds, floor_node_test).
p = ladder.params(18); p.is_owner = false; p.c_min = 10000; p.chi = 2.5 ^ p.gamma;
p.grid_dims = [8 6 6 4]; p.gh_n = 3; p = config.derive(p);
[pf, sk, an] = config.model_inputs(p);
sol = solver.solve(p, pf, sk, an, false);
assert(all(isfinite(sol.V(:))) && all(sol.c_pol(:) > 0 & sol.c_pol(:) <= 1 + 1e-6) && ...
    all(sol.pi_pol(:) >= -1e-3 & sol.pi_pol(:) <= 1 + 1e-3), 'solve out of range');
pv = config.survival(p);
S  = cumprod([1; pv]);
net = 1 - p.tau_inc;
w  = p.chi * p.beq_bankrupt ^ (1 - p.gamma);
for t = [10, p.t_ret + 5, p.T]
    [g1, g2] = utility.grid_at(p, t);
    [U1, U2, U3] = ndgrid(g1, g2, p.u3_grid);
    sA = U2 .* (1 - U1) .* U3; sH = U2 .* (1 - U1) .* (1 - U3); sX = (1 - U1) .* (1 - U2);
    if t >= p.t_ret
        LW = sX + net * U1 + net * sA / an(t) - p.alpha * sH;
    else
        LW = sX + (1 - p.kappa(t)) * net * U1 - p.alpha * sH;
    end
    F = p.phi_path(t) * U1;
    k = (t:p.T).';
    D = sum(p.beta .^ (k - t) .* S(k) / S(t));
    G = sum(p.beta .^ (k - t + 1) .* S(k) / S(t) .* (1 - pv(k)));
    m = LW < F * (1 - 1e-9);
    assert(any(m(:)), 'no node below the floor at t = %d', t);
    V  = sol.V(:, :, :, 1, t);
    Vb = F .^ (1 - p.gamma) / (1 - p.gamma) * (D + w * G);
    err = max(abs(V(m) ./ Vb(m) - 1));
    assert(err < 1e-12, 't = %d: value at the bankrupt nodes off the closed form by %.2g', t, err);
end
end

function floor_node_test()
% The bankruptcy test at the quadrature nodes (abs_node_test, on by default),
% against the same solve with it off. Without the
% absorbing floor it changes nothing, bit for bit (renter). With it (step 16,
% renter and owner, small grid, c_min = 10,000) it changes the solution, the
% bankrupt nodes and their closed-form values stay as they are, and the
% solve stays finite, in range and on the grid (owner panel).
for owner = [false true]
    p = ladder.params(16); p.is_owner = owner;
    p.grid_dims = [6 5 4 3]; p.gh_n = 3; p = config.derive(p);
    [pf, sk, an] = config.model_inputs(p);
    assert(p.abs_node_test, 'abs_node_test is not on by default');
    p.abs_node_test = false; p = config.derive(p);
    if ~owner
        q = p; q.abs_node_test = true; q = config.derive(q);
        A = solver.solve(p, pf, sk, an, false);
        B = solver.solve(q, pf, sk, an, false);
        assert(isequaln(A.V, B.V) && isequaln(A.c_pol, B.c_pol) && isequaln(A.pi_pol, B.pi_pol), ...
            'abs_node_test changed a solve without the absorbing floor');
    end
    p.c_min = 10000; p = config.derive(p);
    q = p; q.abs_node_test = true; q = config.derive(q);
    A = solver.solve(p, pf, sk, an, false);
    B = solver.solve(q, pf, sk, an, false);
    assert(~isequaln(A.V, B.V), 'owner %d: abs_node_test changed nothing with the absorbing floor', owner);
    assert(all(isfinite(B.V(:))) && all(B.c_pol(:) > 0 & B.c_pol(:) <= 1 + 1e-6) && ...
        all(B.pi_pol(:) >= -1e-6 & B.pi_pol(:) <= 1 + 1e-6), 'owner %d: solve out of range', owner);
    for t = [10, q.t_ret + 5]
        g1 = utility.grid_at(q, t);
        Vb = (q.phi_path(t) * g1(:)) .^ (1 - q.gamma) / (1 - q.gamma) * q.D_abs(t);
        bA = abs(A.V(:, :, :, :, t) ./ Vb - 1) < 1e-12;
        bB = abs(B.V(:, :, :, :, t) ./ Vb - 1) < 1e-12;
        assert(isequal(bA, bB) && any(bB(:)), 'owner %d, t = %d: the bankrupt nodes moved', owner, t);
    end
    if owner
        sim = simulate.forward(q, pf, B, an, 500);
        assert(sum([sim.diagnostics.n_offgrid_u1, sim.diagnostics.n_offgrid_u2, sim.diagnostics.n_offgrid_u3, ...
            sim.diagnostics.n_offgrid_q]) == 0 && all(isfinite(sim.C(:))), 'owner panel with abs_node_test');
    end
end
end

function floor_absorbing()
% Step 16, renter, small grid, c_min = 10,000. (1) At every node whose liquid
% resources fall short of the floor, the solved value is the closed form
% (phi_t u1)^(1-gamma)/(1-gamma) D_t to 1e-12 relative, with D_t summed here
% from the survival table: at a working age, a retired age and the last.
% (2) In the panel a bankrupt household stays bankrupt, entered with resources
% below the floor, consumes phi_t Y at entry and the same every year after,
% holds no wealth after entry and leaves no bequest; only solvent households
% are counted off the grid. (3) The dashboard draws.
p = ladder.params(16); p.is_owner = false; p.c_min = 10000;
p.grid_dims = [8 6 6 4]; p.gh_n = 3; p = config.derive(p);
r = model.run(p, N_sim = 2000, keep_sim = true, verbose = false);
S = cumprod([1; config.survival(p)]);
net = 1 - p.tau_inc;
for t = [10, p.t_ret + 5, p.T]
    [g1, g2] = utility.grid_at(p, t);
    [U1, U2, U3] = ndgrid(g1, g2, p.u3_grid);
    sA = U2 .* (1 - U1) .* U3; sH = U2 .* (1 - U1) .* (1 - U3); sX = (1 - U1) .* (1 - U2);
    if t >= p.t_ret
        LW = sX + net * U1 + net * sA / r.ann_price(t) - p.alpha * sH;
    else
        LW = sX + (1 - p.kappa(t)) * net * U1 - p.alpha * sH;
    end
    F = p.phi_path(t) * U1;
    k = (t:p.T).';
    D = sum(p.beta .^ (k - t) .* S(k) / S(t));
    m = LW < F * (1 - 1e-9);
    assert(any(m(:)), 'no node below the floor at t = %d', t);
    V  = r.sol.V(:, :, :, 1, t);
    Vb = F .^ (1 - p.gamma) / (1 - p.gamma) * D;
    err = max(abs(V(m) ./ Vb(m) - 1));
    assert(err < 1e-12, 't = %d: value at the bankrupt nodes off the closed form by %.2g', t, err);
end

s = r.sim; ab = s.absorbed;
assert(any(ab(:)), 'no household went bankrupt');
assert(all(diff(ab, 1, 2) >= 0, 'all'), 'a bankrupt household became solvent');
assert(all(isnan(s.abs_age(~any(ab, 2)))), 'abs_age set for a household never bankrupt');
for i = find(any(ab, 2)).'
    t0 = find(ab(i, :), 1);
    F0 = p.phi_path(t0) * s.Y(i, t0);
    assert(s.abs_age(i) == p.age0 + t0 - 1, 'household %d: abs_age', i);
    assert(s.LW(i, t0) < F0, 'household %d entered with resources above the floor', i);
    assert(abs(s.C(i, t0) / F0 - 1) < 1e-12 && all(s.C(i, t0:end) == s.C(i, t0)), ...
        'household %d: consumption is not the floor at entry, constant after', i);
    assert(all(s.X(i, t0+1:end) == 0 & s.A(i, t0+1:end) == 0 & s.H(i, t0+1:end) == 0), ...
        'household %d holds wealth after entry', i);
    assert(s.bequest(i) == 0, 'household %d left a bequest', i);
end
assert(isequal(r.summary.floored, mean(ab, 1)), 'floored is not the bankrupt share');
n = zeros(1, 3);
for t = 1:p.T
    [g1, g2] = utility.grid_at(p, t);
    ok  = ~ab(:, t);
    sAH = s.sA(ok, t) + s.sH(ok, t);
    u1  = s.lambda(ok, t);
    u2  = sAH ./ max(1 - u1, 1e-12);
    u3  = min(max(s.sA(ok, t) ./ max(sAH, 1e-12), 0), 1);
    n = n + [sum(u1 < g1(1) - 1e-12 | u1 > g1(end) + 1e-12), sum(u2 < g2(1) - 1e-12 | u2 > g2(end) + 1e-12), ...
             sum(u3 < p.u3_grid(1) - 1e-12 | u3 > p.u3_grid(end) + 1e-12)];
end
d = s.diagnostics;
assert(isequal(n, [d.n_offgrid_u1, d.n_offgrid_u2, d.n_offgrid_u3]), ...
    'off-grid counts %s, solvent households only %s', mat2str([d.n_offgrid_u1, d.n_offgrid_u2, d.n_offgrid_u3]), mat2str(n));
h = r.summary.abs_hazard;
assert(numel(h) == p.T && all(h >= 0 & h <= 1) && any(h > 0), 'abs_hazard');
dd = tempname; mkdir(dd); cleanup = onCleanup(@() rmdir(dd, 's'));
figures.dashboard(r, fullfile(dd, 'a.png'));
assert(isfile(fullfile(dd, 'a.png')), 'the dashboard was not written');
end
