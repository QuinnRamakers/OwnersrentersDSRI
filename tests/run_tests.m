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
          @reit_production, @reit_off_untouched, ...
          @income_profile, @income_table, @tenure_arms, @housing_corr_by_tenure, @q_axis_where_live, ...
          @nibud_rule, @floor_derive, @dc_choice_param, @glide_age100, @gross_rate_param, @fast_power_param, ...
          @paper_steps, @glide_knots_rule, @annuity_variable, @return_moments, @strategy_list_derives};
if opts.solve
    checks = [checks, {@default_choice_step, @default_choice_panel, @strategies_smoke, @dc_choice_dominates, @dc_choice_smoke, ...
                       @collapsed_axes_exact, @nohousing_ignores_housing, @smoke_both_tenures, ...
                       @nohousing_arms_corr, @annuity_flat_prices, @annuity_payment_pv, ...
                       @figures_render, @floor_off_identical, @floor_absorbing, @floor_node_test, ...
                       @bequest_off_identical, @bequest_last_year, @bequest_bankrupt, @fast_power_step}];
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
q.r = 0.02; q.retirement_age = 65; q.kappa_base = 0.2; q.h_rule = 'fixed'; q.h_fixed = 9;
q = config.derive(q);
assert(q.h_mult == 9, 'h_mult not rebuilt from h_fixed');
assert(abs(q.Rf - 1.02) < 1e-15, 'Rf not rebuilt');
assert(q.t_ret == 41 && numel(q.tau_S) == q.T - 1 && q.tau_S(41) == 0, 'glide not rebuilt');
assert(all(q.kappa(q.t_ret:end) == 0) && all(abs(q.kappa(1:q.t_ret-1) - 0.2) < 1e-15), 'kappa not rebuilt');
q.franchise = 18475; q = config.derive(q);
assert(all(q.kappa(q.t_ret:end) == 0) && max(q.kappa) < 0.2, 'kappa not rebuilt for the franchise');
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
% all stocks, and the production glide, whose risky share production splits
% between stocks and the REIT (step 19, the last). No step before it holds
% the REIT.
S = ladder.steps();
assert(ladder.parent('dc_bonds') == ladder.index('corr_SL'), 'dc_bonds parent');
assert(ladder.parent('pension') == ladder.index('housing_corr'), 'pension parent');
assert(ladder.parent('housing') == ladder.index('corr_SL'), 'housing parent');
assert(ladder.parent('annuity') == ladder.index('housing'), 'annuity parent');
assert(ladder.parent('housing_corr') == ladder.index('annuity'), 'housing_corr parent');
assert(ladder.index('7b') == ladder.index('annuity') && ladder.index(8) == ladder.index('housing_corr') ...
    && ladder.index(18) == ladder.index('floor') && ladder.index(19) == ladder.index('reit') ...
    && ladder.index(24) == numel(S) && strcmp(S(end).name, 'default_choice'), 'step numbers');
for k = 1:ladder.index('reit') - 1
    for owner = [false true]
        p = ladder.params(S(k).name); p.is_owner = owner;
        assert(~config.reit_active(p), '%s: a REIT before step 19', S(k).name);
    end
end
assert(~ladder.params('nibud').maint_on_purchase && ladder.params('maint_purchase').maint_on_purchase, ...
    'maintenance on the current value to step 16, on the purchase price at step 17');
assert(~ladder.params('maint_purchase').floor_absorbing && ladder.params('floor').c_min == 5000, ...
    'the yearly top-up to step 17, the absorbing floor at step 18');
assert(strcmp(ladder.params('housing').mortgage, 'proportional') && ...
    strcmp(ladder.params('annuity').mortgage, 'annuity') && ...
    strcmp(ladder.params('housing_corr').mortgage, 'annuity'), 'mortgage contract along the ladder');
for k = ladder.index('dc_bonds') : ladder.index('aow')
    p = ladder.params(S(k).name);
    assert(p.h_mult == 0 && p.kappa_base == 0.10, '%s: DC pillar without housing', S(k).name);
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
p = config.params();
assert(isequal(config.tau_effective(ladder.params('dc_glide')), config.tau_effective(p) + config.reit_effective(p)), ...
    'glide fund differs from production');
end

function reit_production()
% Production holds the REIT: the glide's risky share, min(0.8, years to
% retirement / 35) and 0 from 67, half in stocks and half in the REIT, so the
% risky share, the bond leg and the all-bond fund in retirement are step 18's
% and the annuity prices from 67 do not move. On the quadrature nodes, gh_n^4
% of them, the REIT has the tables' correlations with income, the stock and
% the tenure's H shock (house price 0.17, rent 0.59), and its mean gross
% return is 1 + r + mu_REIT_level.
for owner = [false true]
    p = config.params(false); p.is_owner = owner; p = config.derive(p);
    q = ladder.params('floor'); q.is_owner = owner; q = config.derive(q);
    assert(config.reit_active(p) && ~config.reit_active(q), 'owner %d: the REIT should be on at step 19 only', owner);
    g = config.tau_effective(q);
    tS = config.tau_effective(p); tR = config.reit_effective(p);
    assert(isequal(tS, 0.5 * g) && isequal(tR, 0.5 * g) && isequal(tS + tR, g), ...
        'owner %d: the fund is not the glide split in half', owner);
    assert(max(g) == 0.8 && all(g(p.t_ret:end) == 0) && all(config.reit_effective(q) == 0), ...
        'owner %d: the glide or the REIT share at step 18', owner);
    sk = grids.shock_grid(p); w = sk.joint.w(:) / sum(sk.joint.w);
    assert(numel(w) == p.gh_n ^ 4, 'owner %d: %d joint nodes, not gh_n^4', owner, numel(w));
    lr = log(sk.joint.R_REIT(:)); lh = log(sk.joint.R_H(:)); ly = sk.joint.eps_Y_unit(:); ls = log(sk.joint.R_S(:));
    wc = @(x, y) sum(w .* (x - sum(w .* x)) .* (y - sum(w .* y))) / ...
         sqrt(sum(w .* (x - sum(w .* x)).^2) * sum(w .* (y - sum(w .* y)).^2));
    [~, ~, cRH] = config.h_corr(p);
    assert(cRH == 0.17 * owner + 0.59 * ~owner, 'owner %d: corr_RH %.2f', owner, cRH);
    got = [wc(ly, lr), wc(ls, lr), wc(lh, lr)];
    assert(max(abs(got - [p.corr_RL, p.corr_RS, cRH])) < 1e-10, ...
        'owner %d: REIT node correlations %s against %s', owner, mat2str(got, 4), mat2str([p.corr_RL, p.corr_RS, cRH]));
    m = sum(w .* sk.joint.R_REIT(:));
    assert(abs(m / (1 + p.r + p.mu_REIT_level) - 1) < 1e-8, 'owner %d: REIT mean %.6f on the nodes', owner, m);
    [~, ~, an] = config.model_inputs(p); [~, ~, an0] = config.model_inputs(q);
    assert(isequal(an(p.t_ret:end), an0(p.t_ret:end)), 'owner %d: annuity prices from 67 moved', owner);
end
end

function reit_off_untouched()
% With the REIT off (step 18, both tenures) nothing reads its other fields:
% moving its moments, its quadrature nodes and the renters' correlation of an
% owner leaves the income profile, the joint quadrature nodes and the annuity
% prices bit-identical, and same_calibration ignores them, also for a result
% saved before the REIT fields existed, with the old placeholder moments.
% With the REIT on (step 19) the same moves make a different calibration.
for owner = [false true]
    p = ladder.params('floor'); p.is_owner = owner; p.gh_n = 3; p = config.derive(p);
    q = p; q.mu_REIT_level = 0.01; q.sigma_REIT_level = 0.4; q.gh_n_reit = 7;
    if owner, q.corr_RH_rent = 0.3; end
    q = config.derive(q);
    assert(~config.reit_active(q), 'owner %d: the moves turned the REIT on', owner);
    [pf, sk, an] = config.model_inputs(p); [qf, qk, qn] = config.model_inputs(q);
    assert(isequaln(pf, qf) && isequaln(sk.joint, qk.joint) && isequaln(an, qn), ...
        'owner %d: a REIT field moved a step without the REIT', owner);
    assert(ladder.same_calibration(p, q), 'owner %d: REIT fields compared with the REIT off', owner);
    old = rmfield(p, {'reit_risky', 'corr_RH_rent', 'reit_glide'});
    old.mu_REIT_level = 0.03; old.sigma_REIT_level = 0.12;
    assert(ladder.same_calibration(old, p), 'owner %d: a REIT-off result saved before the REIT fields', owner);
    r = ladder.params('reit'); r.is_owner = owner; r = config.derive(r);
    s = r; s.mu_REIT_level = 0.01;
    assert(~ladder.same_calibration(r, s) && ~ladder.same_calibration(old, r) && ~ladder.same_calibration(p, r), ...
        'owner %d: REIT fields not compared with the REIT on', owner);
end
end

function income_profile()
% The pooled DHS cubic, 2020 euros raised to 2025, the same for both tenures:
% the level at 25 and at the peak against the values computed from the
% published coefficients, the peak age, the shock std, and the step down by
% the replacement rate at retirement.
target = struct('owner',  struct('y25', 33829, 'peak', 48, 'ypeak', 60589, 'sigma', 0.0675), ...
                'renter', struct('y25', 33829, 'peak', 48, 'ypeak', 60589, 'sigma', 0.0675));
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
assert(strcmp(model.tenure(p), 'nohousing'), 'the pooled income step should keep one arm');
p.income_coef_rent(1) = p.income_coef_rent(1) - 0.3;                     % split the income, to test the labels
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
assert(isequal([a b c d], [0.05 0.43 0.03 0.24]), 'tenure selection of the housing correlations');
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
% The 2025 norms (production): cells of that workbook's maximum-mortgage table
% and its calculator's example (income 73,010 at 4.25%: share 0.255, EUR
% 315,376.44); the table starts at 28,000; the increase is refused.
cells = [28000 0.0325 96505.95168; 122000 0.0125 671164.4005; 125000 0.0675 521959.0814; ...
         124000 0.0175 679741.8822; 73010 0.0425 315376.4369];
for k = 1:size(cells, 1)
    M = config.nibud_lti(cells(k, 1), cells(k, 2), false, 2025) * cells(k, 1);
    assert(abs(M / cells(k, 3) - 1) < 1e-9, '2025 workbook cell %d: %.2f against %.2f', k, M, cells(k, 3));
end
assert(config.nibud_lti(20000, 0.0325, false, 2025) * 20000 / (0.18 * 20000 / 12) == ...
       config.nibud_lti(28000, 0.0325, false, 2025) * 28000 / (0.18 * 28000 / 12), 'incomes below 28,000 are not on the first row');
assert(threw_id(@() config.nibud_lti(40000, 0.0338, true, 2025), 'nibud_lti:extra_2025'), 'the increase accepted with the 2025 norms');
assert(config.nibud_lti(40000, 0.0338, false) == config.nibud_lti(40000, 0.0338, false, 2026), 'the default year is not 2026');
% Step 19 keeps the 2026 norms with the increase at 3.48%: 4.521 for both tenures.
for owner = [true false]
    p = config.params(false); p.is_owner = owner; p = config.derive(p);
    Y0 = exp(config.income_profile(p)); Y0 = Y0(1);
    assert(p.nibud_year == 2025 && ~p.nibud_extra && p.r_m == 0.0338, 'production is not the 2025 norms without the increase at 3.38%%');
    assert(p.h_mult == config.nibud_lti(Y0, p.r_m, false, 2025), 'owner %d: h_mult is not the lookup', owner);
    q = ladder.params('reit'); q.is_owner = owner; q = config.derive(q);
    assert(q.h_mult == config.nibud_lti(Y0, 0.0348, true, 2026) && abs(q.h_mult - 4.521) < 5e-4, ...
        'owner %d: step 19 h_mult %.4f against 4.521', owner, q.h_mult);
    for name = {'housing', 'box3'}
        q = ladder.params(name{1}); q.is_owner = owner; q = config.derive(q);
        assert(q.h_mult == 4, '%s, owner %d: house not at 4 times income', name{1}, owner);
    end
end
% h_mult is derived, so a calibration comparison does not depend on whether
% p was derived again after a tenure switch (ladder.load, ladder.report), and
% switching the rule on a derived p returns to h_fixed.
p = config.params();
ps = p; ps.income_coef_rent(1) = ps.income_coef_rent(1) - 0.3;           % poorer renters, so the two multiples differ
ps = config.derive(ps);
q = ps; q.is_owner = true;
o = config.derive(q);
assert(ladder.same_calibration(o, q) && o.h_mult ~= ps.h_mult, 'tenure switch: same_calibration depends on derive');
q = p; q.h_rule = 'fixed'; q = config.derive(q);
assert(q.h_mult == q.h_fixed, 'switching to fixed kept the Nibud multiple');
q = p; q.h_rule = 'none'; q = config.derive(q);
assert(q.h_mult == 0 && strcmp(model.tenure(q), 'nohousing'), 'h_rule none');
% model.run refuses a tenure switch without derive, also where kappa is the
% same for both tenures (no DC pillar)
q = ladder.params('housing_corr'); q.h_rule = 'nibud';
q.income_coef_rent(1) = q.income_coef_rent(1) - 0.3;                     % split the income, so the tenures derive differently
q = config.derive(q);
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
assert(p.chi == 32 && max(abs(p.D_beq ./ (p.D_abs + p.chi * p.beq_bankrupt ^ (1 - p.gamma) * p.G_abs) - 1)) < 1e-14, ...
    'D_beq is not D_abs + chi beq_bankrupt^(1-gamma) G_abs');
q = ladder.params('reit');
assert(q.chi == 0 && isequal(q.D_beq, q.D_abs), 'D_beq is not D_abs without a bequest motive');
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

function dc_choice_param()
% dc_choice is a primitive, off in production. A result saved before it
% existed is the same calibration as production; one with it on is not; and
% derive refuses anything but true or false.
p = config.params();
assert(isfield(config.params(false), 'dc_choice') && ~p.dc_choice, 'dc_choice is not an off primitive');
assert(ladder.same_calibration(rmfield(p, 'dc_choice'), p), 'a result without dc_choice is not production');
q = p; q.dc_choice = true;
assert(~ladder.same_calibration(q, p), 'dc_choice on is the same calibration as off');
q.dc_choice = 2;
assert(threw_id(@() config.derive(q), 'derive:dc_choice'), 'derive took dc_choice = 2');
end

function glide_age100()
% The 100-minus-age glide: production keeps the span glide; with 'age100' the
% fund's risky share is (100 - age)/100 at every age, retirement included,
% split at reit_risky, and the annuity is priced off it (a lower price in
% retirement than the all-bond fund's). Its mirror 'reverse' holds age/100,
% split the same way. A result without glide_rule is production; derive
% refuses an unknown rule.
p = config.params();
assert(strcmp(p.glide_rule, 'span'), 'production is not the span glide');
assert(ladder.same_calibration(rmfield(p, 'glide_rule'), p), 'a result without glide_rule is not production');
q = p; q.glide_rule = 'age100'; q = config.derive(q);
ages  = (q.age0 : q.age0 + q.T - 2).';
risky = config.tau_effective(q) + config.reit_effective(q);
assert(max(abs(risky - (100 - ages) / 100)) < 1e-12, 'the risky share is not (100 - age)/100');
assert(max(abs(config.reit_effective(q) - q.reit_risky * (100 - ages) / 100)) < 1e-12, 'the REIT split');
assert(~ladder.same_calibration(q, p), 'age100 is the same calibration as span');
[profile, shocks] = config.model_inputs(p);
a_span = pension.annuity_price(p, profile, shocks);
a_100  = pension.annuity_price(q, profile, shocks);
assert(all(a_100(q.t_ret : q.T - 1) < a_span(q.t_ret : q.T - 1)), 'the annuity is not priced off the risky fund');
q.glide_rule = 'reverse'; q = config.derive(q);
risky = config.tau_effective(q) + config.reit_effective(q);
assert(max(abs(risky - ages / 100)) < 1e-12, 'the reverse risky share is not age/100');
assert(max(abs(config.reit_effective(q) - q.reit_risky * ages / 100)) < 1e-12, 'the reverse REIT split');
assert(~ladder.same_calibration(q, p), 'reverse is the same calibration as span');
q.glide_rule = 'other';
assert(threw_id(@() config.derive(q), 'derive:glide_rule'), 'derive took an unknown glide rule');
end

function gross_rate_param()
% gross_rate is a primitive, off in production. A result saved before it
% existed is production; one with it on is not. On, working pay is Y plus
% gross_rate times pay above the franchise, (1 + gross_rate) Y without one,
% and the AOW follows grossed-up final pay. Production has no franchise since
% 9 November 2026, so the rule above one is checked at EUR 18,475.
p = config.params();
assert(isfield(config.params(false), 'gross_rate') && p.gross_rate == 0, 'gross_rate is not an off primitive');
assert(ladder.same_calibration(rmfield(p, 'gross_rate'), p), 'a result without gross_rate is not production');
p.franchise = 18475; p = config.derive(p);
Y0 = exp(config.income_profile(p));
q = p; q.gross_rate = 0.271; q = config.derive(q);
assert(~ladder.same_calibration(q, p), 'gross_rate on is the same calibration as off');
w = 1 : p.t_ret - 1;
Y = exp(config.income_profile(q));
assert(max(abs(Y(w) ./ (Y0(w) + 0.271 * max(Y0(w) - p.franchise, 0)) - 1)) < 1e-12, 'the gross-up above the franchise');
assert(abs(Y(q.t_ret) / Y(q.t_ret - 1) - p.replacement) < 1e-12, 'the AOW does not follow grossed-up final pay');
q.franchise = 0;
assert(max(abs(exp(config.income_profile(q)) ./ Y0 - 1.271)) < 1e-12, 'without a franchise the gross-up is not (1 + rate)');
end

function paper_steps()
% Steps 20-24 bring the ladder to the paper of 16 November 2026, one change
% each, and step 19 keeps what it had. The tax on the liquid stock return is
% on the return whatever its sign in production and on gains only at step 21.
% default_choice and nibud_year are primitives; a result saved before they
% existed is the forced rule and the 2026 norms, so it is step 19's
% calibration and not production's. derive refuses bad values.
old = ladder.params(19);
assert(old.r_m == 0.0348 && old.nibud_year == 2026 && old.nibud_extra && ~old.cg_loss_offset && ...
    old.chi == 0 && ~old.default_choice, 'step 19 does not keep its values');
assert(ladder.same_calibration(rmfield(old, {'default_choice', 'nibud_year', 'glide_knots'}), old), ...
    'a result saved before the new primitives is not step 19');
names = {'mortgage_rate', 'nibud2025', 'tax_symmetric', 'bequest', 'default_choice'};
vals  = [0.0338 2026 0 0 0; 0.0338 2025 0 0 0; 0.0338 2025 1 0 0; 0.0338 2025 1 32 0; 0.0338 2025 1 32 1];
for k = 1:numel(names)
    q = ladder.params(names{k});
    assert(ladder.index(names{k}) == ladder.index(19 + k), '%s is not step %d', names{k}, 19 + k);
    got = [q.r_m, q.nibud_year, q.cg_loss_offset, q.chi, q.default_choice];
    assert(isequal(got, vals(k, :)) && q.nibud_extra == (k == 1), '%s: %s', names{k}, mat2str(got));
end
p = config.params();
assert(p.chi == 2 ^ p.gamma, 'chi is not b^gamma at b = 2');
assert(~ladder.same_calibration(rmfield(p, 'default_choice'), p) && ~ladder.same_calibration(rmfield(p, 'nibud_year'), p), ...
    'a result without default_choice or nibud_year is production');
R = [0.7; 1; 1.3];
assert(max(abs(config.after_tax_stock(p, R) - (1 + (1 - p.tau_cg_stock) * (R - 1)))) < 1e-15, ...
    'production: the tax is not on the return whatever its sign');
q = ladder.params('nibud2025');
assert(isequal(config.after_tax_stock(q, R), R - q.tau_cg_stock * max(R - 1, 0)), 'step 21: the tax is not on gains only');
q = config.params(false); q.default_choice = 2;
assert(threw_id(@() config.derive(q), 'derive:default_choice'), 'derive took default_choice = 2');
q = config.params(false); q.nibud_year = 2024;
assert(threw_id(@() config.derive(q), 'derive:nibud_year'), 'derive took nibud_year = 2024');
q = config.params(false); q.nibud_extra = true;
assert(threw_id(@() config.derive(q), 'derive:nibud_extra'), 'derive took the increase with the 2025 norms');
end

function glide_knots_rule()
% Any fund strategy by age: with 'knots' the stock and the REIT share are each
% a monotone cubic through glide_knots, flat outside, at every age. Two knots
% on a line give the line, so [0 .5 .5; 100 0 0] is the 100-minus-age glide at
% reit_risky 0.5 to 1e-12; one knot is a constant fund, retirement included;
% a hump stays within its knots' range (no overshoot). It is another
% calibration than production, and derive refuses knots that are not shares.
p = config.params();
ages = (p.age0 : p.age0 + p.T - 2).';
q = p; q.glide_rule = 'knots'; q.glide_knots = [0 0.5 0.5; 100 0 0]; q = config.derive(q);
a = p; a.glide_rule = 'age100'; a.reit_risky = 0.5; a = config.derive(a);
assert(max(abs(config.tau_effective(q) - config.tau_effective(a))) < 1e-12 && ...
       max(abs(config.reit_effective(q) - config.reit_effective(a))) < 1e-12, 'two knots on a line are not the line');
assert(~ladder.same_calibration(q, p), 'knots is the same calibration as production');
q.glide_knots = [50 0.6 0.1]; q = config.derive(q);
assert(all(config.tau_effective(q) == 0.6) && all(config.reit_effective(q) == 0.1), 'one knot is not a constant fund');
q.glide_knots = [25 0.2 0; 45 0.9 0.1; 67 0.3 0.2; 100 0.3 0]; q = config.derive(q);
tS = config.tau_effective(q); tR = config.reit_effective(q);
assert(all(tS >= 0.2 - 1e-12 & tS <= 0.9 + 1e-12) && all(tR >= 0 & tR <= 0.2 + 1e-12) && all(tS + tR <= 1), 'the path leaves its knots'' range');
assert(abs(tS(ages == 45) - 0.9) < 1e-12 && abs(tR(ages == 67) - 0.2) < 1e-12 && abs(tS(ages == 80) - 0.3) < 1e-12, 'the path misses a knot');
[profile, shocks] = config.model_inputs(q);
a_k = pension.annuity_price(q, profile, shocks);
a_b = pension.annuity_price(p, profile, shocks);
assert(all(a_k(q.t_ret : q.T - 1) < a_b(q.t_ret : q.T - 1)), 'the annuity is not priced off the knots'' fund');
for bad = {[], [25 0.5], [25 0.7 0.5], [25 -0.1 0], [40 0.5 0; 30 0.5 0]}
    q.glide_knots = bad{1};
    assert(threw_id(@() config.derive(q), 'derive:glide_knots'), 'derive took glide_knots = %s', mat2str(bad{1}));
end
end

function annuity_variable()
% The annuity with a fund that holds risk in retirement, for several
% strategies and both tenures. The pot pays A/a_t, and what is left earns the
% fund's return with the survival credit. (1) The last payout is the whole pot
% (a_T = 1). (2) The expected payout is level: the mean over the joint
% quadrature nodes of next year's payout per euro of pot,
% R_A (1 - 1/a_t) / a_{t+1}, is this year's, 1/a_t, to 1e-8 at every retired
% age. (3) The payout moves with the fund's return when the fund holds risk
% (the variable annuity) and not at all when it is all bonds (production).
arms = {'production', 'age100', 'reverse', 'knots', 'stocks', 'reit'};
for owner = [false true]
    for k = 1:numel(arms)
        p = config.params(false); p.is_owner = owner;
        switch arms{k}
            case 'age100',  p.glide_rule = 'age100';
            case 'reverse', p.glide_rule = 'reverse';
            case 'knots',   p.glide_rule = 'knots'; p.glide_knots = [25 0.5 0.3; 67 0.3 0.2; 90 0.1 0];
            case 'stocks',  p.tau_decum = 1; p.reit_decum = 0;
            case 'reit',    p.tau_decum = 0.2; p.reit_decum = 0.8;
        end
        p = config.derive(p);
        [profile, shocks, a] = config.model_inputs(p);
        tS = config.tau_effective(p); tR = config.reit_effective(p);
        w = shocks.joint.w(:);
        assert(a(p.T) == 1, '%s: the last payout is not the whole pot', arms{k});
        risky = false;
        for t = p.t_ret : p.T - 1
            R_A  = ((1 - tS(t) - tR(t)) * p.Rf + tS(t) * shocks.joint.R_S(:) + tR(t) * shocks.joint.R_REIT(:)) / profile.p_surv(t);
            next = R_A * (1 - 1 / a(t)) / a(t + 1);
            assert(abs(sum(w .* next) * a(t) - 1) < 1e-8, '%s, owner %d, t = %d: the expected payout moves by %.2g', ...
                arms{k}, owner, t, sum(w .* next) * a(t) - 1);
            sd = sqrt(sum(w .* (next - sum(w .* next)) .^ 2));
            if tS(t) + tR(t) > 0
                risky = true;
                assert(sd > 0, '%s, t = %d: a risky fund pays a fixed annuity', arms{k}, t);
            else
                assert(sd < 1e-12 / a(t), '%s, t = %d: an all-bond fund pays a variable annuity', arms{k}, t);
            end
        end
        assert(risky == ~strcmp(arms{k}, 'production'), '%s: risk in retirement', arms{k});
    end
end
end

function return_moments()
% The four lognormal processes take the same inputs, the arithmetic mean and
% standard deviation of the yearly return (Table 1 of the paper), and are
% converted to log moments the same way: the mean of the gross return is
% 1 + r + premium for the stock and the REIT and 1 + growth for the house
% price and the rent, and its standard deviation is the input, to 1e-12.
p = config.params();
[mR, sR] = config.reit_process(p);
o = p; o.is_owner = true; o = config.derive(o);
[mH, sH] = config.h_process(o);
[mN, sN] = config.h_process(p);
rows = {'stock', p.mu_S, p.sigma_S, 1 + p.r + p.mu_S_level,    p.sigma_S_level; ...
        'REIT',  mR,     sR,        1 + p.r + p.mu_REIT_level, p.sigma_REIT_level; ...
        'house', mH,     sH,        1 + p.mu_H_level,          p.sigma_H_level; ...
        'rent',  mN,     sN,        1 + p.mu_R_level,          p.sigma_R_level};
for k = 1:size(rows, 1)
    [mu, sg, m, s] = rows{k, 2:5};
    E  = exp(mu + sg ^ 2 / 2);
    sd = E * sqrt(exp(sg ^ 2) - 1);
    assert(abs(E - m) < 1e-12 && abs(sd - s) < 1e-12, '%s: mean %.12f against %.12f, sd %.12f against %.12f', rows{k, 1}, E, m, sd, s);
end
end

function default_choice_step()
% Default as a choice against the forced rule, from one continuation (the
% forced solve of step 23 on a small grid, c_min = 10,000 so that default is
% near), at a working and a retired age, both tenures. With the choice: the
% value is the larger of continuing and defaulting at every node, exactly; it
% is at least the forced rule's value (the forced rule is one of the things the
% household can do), to the search's precision (fewer than 2% of
% nodes more than 1e-4 lower in consumption units, none more than 1%; the
% two searches run over different ranges of c); default is taken at some
% node and refused at some; and continuing is closed only where resources do
% not exceed phi_floor * Y. With the floor off the choice changes nothing.
for owner = [false true]
    p = ladder.params('bequest'); p.is_owner = owner; p.c_min = 10000;
    p.grid_dims = [8 6 6 4]; p.gh_n = 3; p = config.derive(p);
    q = p; q.default_choice = true; q = config.derive(q);
    [pf, sk, an] = config.model_inputs(p);
    B = solver.solve(p, pf, sk, an, false);
    for t = [10, p.t_ret + 5]
        pol = struct('c', B.c_pol(:,:,:,:,t+1), 'pi', B.pi_pol(:,:,:,:,t+1));
        [Vf, ~, ~, ~, ~, none] = solver.bellman_step_lna(t, B.V(:,:,:,:,t+1), p, pf, sk, an, pol);
        [Vc, c, pi_, ~, ~, Vcont] = solver.bellman_step_lna(t, B.V(:,:,:,:,t+1), q, pf, sk, an, pol);
        assert(isempty(none), 'the forced rule returned a value of continuing');
        g1 = utility.grid_at(q, t);
        Vd = (q.phi_path(t) * g1(:)) .^ (1 - q.gamma) / (1 - q.gamma) * q.D_beq(t) + zeros(size(Vc));
        assert(isequal(Vc, max(Vcont, Vd)), 'owner %d, t = %d: V is not max(V_continue, V_default)', owner, t);
        ce = @(V) ((1 - q.gamma) * V) .^ (1 / (1 - q.gamma));
        gap = min(ce(Vc(:)) ./ ce(Vf(:)) - 1);
        fprintf('      default_choice_step: owner %d, t = %d: lowest gain over the forced rule %.2g, nodes more than 1e-6 below it %d of %d\n', ...
            owner, t, gap, sum(ce(Vc(:)) ./ ce(Vf(:)) - 1 < -1e-6), numel(Vc));
        % In theory the gain is never negative. On this grid the objective has
        % two peaks in (c, pi) at a few nodes, most at the top of the q axis,
        % and the two searches (over different ranges of c) can settle on
        % different ones: 18 of 2,400 owner nodes more than 1e-4 below, the
        % lowest -0.34% (DSRI, 16 November 2026). Bound both.
        low = mean(ce(Vc(:)) ./ ce(Vf(:)) - 1 < -1e-4);
        assert(gap > -1e-2 && low < 0.02, 'owner %d, t = %d: the choice is worth up to %.2g less than the forced rule, %.1f%% of nodes more than 1e-4 less', ...
            owner, t, gap, 100 * low);
        assert(any(Vc(:) == Vd(:)) && any(Vc(:) > Vd(:)), 'owner %d, t = %d: default never or always taken', owner, t);
        assert(all(isfinite(c(:)) & c(:) > 0 & c(:) <= 1 + 1e-6) && all(pi_(:) >= -1e-3 & pi_(:) <= 1 + 1e-3), 'policy out of range');
    end
end
p = ladder.params('maint_purchase'); p.grid_dims = [6 5 4 3]; p.gh_n = 3; p = config.derive(p);
q = p; q.default_choice = true; q = config.derive(q);
[pf, sk, an] = config.model_inputs(p);
A = solver.solve(p, pf, sk, an, false);
B = solver.solve(q, pf, sk, an, false);
assert(isequaln(A.V, B.V) && isequaln(A.c_pol, B.c_pol) && ~isfield(B, 'V_cont'), 'default_choice changed a solve without the absorbing floor');
end

function default_choice_panel()
% Production with default as a choice, small grid, c_min = 10,000, both
% tenures: the solve is finite and in range and keeps the value of continuing;
% in the panel a household that defaults stays bankrupt, consumes phi_t Y of
% its year of entry every year after, holds nothing and leaves nothing; a
% solvent household consumes its policy's share of its resources, with no
% floor under it; and floored marks the bankrupt.
for owner = [false true]
    p = config.params(false); p.is_owner = owner; p.c_min = 10000;
    p.grid_dims = [8 6 6 4]; p.gh_n = 3; p = config.derive(p);
    assert(p.default_choice, 'production does not have default as a choice');
    r = model.run(p, N_sim = 2000, keep_sim = true, verbose = false);
    assert(all(isfinite(r.sol.V(:))) && isequal(size(r.sol.V_cont), size(r.sol.V)) && all(r.sol.V_cont(:) <= r.sol.V(:)), ...
        'owner %d: the value of continuing', owner);
    assert(all(r.sol.c_pol(:) > 0 & r.sol.c_pol(:) <= 1 + 1e-6) && ...
        all(r.sol.pi_pol(:) >= -1e-3 & r.sol.pi_pol(:) <= 1 + 1e-3), 'owner %d: policy out of range', owner);
    s = r.sim; ab = s.absorbed;
    assert(all(isfinite(s.C(:))) && all(s.C(:) > 0), 'owner %d: consumption', owner);
    assert(all(diff(ab, 1, 2) >= 0, 'all') && isequal(s.floored, ab), 'owner %d: bankrupt households', owner);
    for i = find(any(ab, 2)).'
        t0 = find(ab(i, :), 1);
        F0 = p.phi_path(t0) * s.Y(i, t0);
        assert(abs(s.C(i, t0) / F0 - 1) < 1e-12 && all(s.C(i, t0:end) == s.C(i, t0)), 'household %d: consumption after default', i);
        assert(all(s.X(i, t0+1:end) == 0 & s.A(i, t0+1:end) == 0 & s.H(i, t0+1:end) == 0) && s.bequest(i) == 0, ...
            'household %d holds wealth after default', i);
    end
    ok = ~ab;
    assert(max(abs(s.C(ok) - s.c_frac(ok) .* s.LW(ok))) < 1e-9 * max(s.C(ok)), 'owner %d: a solvent household does not consume its policy', owner);
end
end

function strategy_list_derives()
% Every strategy of model.strategy_list derives for both tenures from
% production, names are unique, the first is production itself, the fund's (and of model.spline_menu)
% shares lie in the simplex at every age, and an override that is not a
% primitive is refused by model.strategies.
S = model.strategy_list();
assert(numel(unique({S.name})) == numel(S) && isempty(fieldnames(S(1).set)), 'names or the reference');
% The spline menu too: 84 strategies, names of their own, and the knots as
% asked (s80_20h_r25: 80% to 39, 20% at 67 and 100, a quarter in the REIT).
M = model.spline_menu();
assert(numel(M) == 84 && numel(unique({M.name})) == 84 && ~any(ismember({M.name}, {S.name})), 'spline menu names');
K = M(strcmp({M.name}, 's80_20h_r25')).set.glide_knots;
assert(max(abs(K - [25 0.6 0.2; 39 0.6 0.2; 67 0.15 0.05; 100 0.15 0.05]), [], "all") < 1e-12, 'spline menu knots');
assert(numel(model.spline_menu(young = 1, at67 = 0, reit = 0)) == 1, 'at67 = 0 has one tail');
S = [S, M];
for k = 1:numel(S)
    for owner = [false true]
        p = config.params(false); p.is_owner = owner;
        f = fieldnames(S(k).set);
        for i = 1:numel(f)
            assert(isfield(p, f{i}), '%s sets %s, not a primitive', S(k).name, f{i});
            p.(f{i}) = S(k).set.(f{i});
        end
        p = config.derive(p);
        tS = config.tau_effective(p); tR = config.reit_effective(p);
        assert(all(tS >= 0 & tR >= 0 & tS + tR <= 1 + 1e-12), '%s: shares outside the simplex', S(k).name);
    end
end
bad = struct('name', 'x', 'label', 'x', 'set', struct('glide_kap', 1));
d = tempname; cleanup = onCleanup(@() rmdir(d, 's'));
R = model.strategies(bad, out = d, solve = false, tenures = "renter");
assert(startsWith(R.runs(1).status, 'FAILED') && contains(R.runs(1).status, 'not a primitive'), 'a misspelt override was accepted');
end

function strategies_smoke()
% model.strategies on a small grid: the production fund and all bonds, both
% tenures, solved and saved with their timing; the ranking of the folder
% (model.rank_strategies) gives the reference a gain of 0, the other
% strategy (V/V_ref)^(1/(1-gamma)) - 1 to 1e-10 and a lowest gain that is the
% smaller of its two; a second call reuses the saved solves; a solve in
% another calibration (another grid) is refused in the same ranking; two
% folders rank together; the figure draws; a saved solve resimulates.
S = model.strategy_list(); S = S(ismember({S.name}, {'lifecycle', 'bonds'}));
d = tempname; cleanup = onCleanup(@() rmdir(d, 's'));
R = model.strategies(S, out = d, grid_dims = [6 5 4 3], gh_n = 3, N_sim = 300);
assert(all(strcmp({R.runs.status}, 'solved')) && all([R.runs.solve_sec] > 0) && isfile(fullfile(d, 'ranking.md')), 'solved, timed, written');
T = R.table; i0 = strcmp(T.strategy, 'lifecycle'); i1 = strcmp(T.strategy, 'bonds');
assert(height(T) == 2 && T.gain_renter(i0) == 0 && T.gain_owner(i0) == 0, 'the reference gain is not 0');
for ten = ["renter", "owner"]
    A = load(fullfile(d, "lifecycle_" + ten + ".mat"), 'V_entry', 'p'); B = load(fullfile(d, "bonds_" + ten + ".mat"), 'V_entry');
    g = 100 * ((B.V_entry / A.V_entry) ^ (1 / (1 - A.p.gamma)) - 1);
    assert(abs(T.("gain_" + ten)(i1) - g) < 1e-10, '%s: the gain is not the value ratio', ten);
end
assert(T.lowest_gain(i1) == min(T.gain_renter(i1), T.gain_owner(i1)) && any(strcmp(R.maxmin, {S.name})), 'lowest gain, max-min');
R2 = model.strategies(S, out = d, grid_dims = [6 5 4 3], gh_n = 3, N_sim = 300);
assert(all(strcmp({R2.runs.status}, 'saved')) && isequaln(R2.table, T), 'the saved solves were not reused');
R3 = model.strategies(S, out = d, grid_dims = [7 5 4 3], gh_n = 3, N_sim = 300, solve = false);
assert(all(strcmp({R3.runs.status}, 'not solved')), 'a solve on another grid was taken for this one');
e = tempname; c2 = onCleanup(@() rmdir(e, 's'));
model.strategies(S(2), out = e, grid_dims = [7 5 4 3], gh_n = 3, N_sim = 300, tenures = "renter");
copyfile(fullfile(d, 'lifecycle_renter.mat'), e);
assert(threw_id(@() model.rank_strategies(e, write = false), 'rank_strategies:calibration'), 'solves on two grids ranked together');
f = tempname; c3 = onCleanup(@() rmdir(f, 's')); mkdir(f);
movefile(fullfile(d, 'bonds_*.mat'), f);
Q = model.rank_strategies({d, f}, write = false);
assert(isequaln(Q.table, T), 'two folders do not rank as one');
copyfile(fullfile(d, 'lifecycle_owner.mat'), f);            % the same solve in both folders counts once
Q = model.rank_strategies({d, f}, write = false);
assert(isequaln(Q.table, T), 'a copy of a solve in a second folder was not counted once');
B = model.rank_strategies({d, f}, reference = 'best', write = false);
assert(all(max([B.table.gain_renter, B.table.gain_owner], [], 1) == 0) && all(B.table.lowest_gain <= 0) ...
    && startsWith(B.reference, 'best'), 'the best reference');
assert(threw_id(@() model.rank_strategies({d, d}, write = false), 'rank_strategies:duplicate'), 'a solve counted twice');
files = figures.strategies({d, f}, out = d);
assert(numel(files) == 2 && all(isfile(files)), 'the figures were not written');
% The solution is kept by default: the saved seed reproduces the summary
% exactly, another seed and panel size give another one.
sfile = fullfile(f, 'bonds_owner.mat'); L = load(sfile, 'summary');
r1 = model.resimulate(sfile);
assert(isequaln(r1.summary, L.summary), 'resimulating with the saved seed does not reproduce the summary');
r2 = model.resimulate(sfile, N_sim = 500, seed = 7);
assert(r2.summary.N == 500 && ~isequaln(r2.summary.C, L.summary.C), 'another seed gave the same panel');
g = tempname; c4 = onCleanup(@() rmdir(g, 's'));
model.strategies(S(2), out = g, grid_dims = [6 5 4 3], gh_n = 3, N_sim = 300, tenures = "renter", keep_sol = false);
assert(threw_id(@() model.resimulate(fullfile(g, 'bonds_renter.mat')), 'resimulate:no_sol'), 'resimulated a file without a solution');
end

function dc_choice_dominates()
% Free DC choice against the fund's shares from one continuation: production
% on a small grid, both tenures, at 40 (working) and 75 (retired). The
% continuation and the warm start are the fund's solve a year later. The
% fund's shares are a candidate of the free search, so the free value is at
% least the fund's at every node, exactly; it is higher somewhere, and the
% shares lie on tau_S, tau_R >= 0, tau_S + tau_R <= 1.
for owner = [false true]
    p = config.params();
    p.grid_dims = [6 5 4 3]; p.gh_n = 3; p.is_owner = owner;
    p = config.derive(p);
    [profile, shocks, ann_price] = config.model_inputs(p);
    sol = solver.solve(p, profile, shocks, ann_price, false);
    pf = p; pf.dc_choice = true;
    for age = [40 75]
        t = age - p.age0 + 1;
        pol = struct('c', sol.c_pol(:,:,:,:,t+1), 'pi', sol.pi_pol(:,:,:,:,t+1));
        Vg = sol.V(:,:,:,:,t);
        [Vf, ~, ~, tS, tR] = solver.bellman_step_lna(t, sol.V(:,:,:,:,t+1), pf, profile, shocks, ann_price, pol);
        short = max(Vg(:) - Vf(:));
        assert(short <= 0, '%s at %d: the free value falls short of the fund''s by %.3g', model.tenure(p), age, short);
        assert(any(Vf(:) > Vg(:)), '%s at %d: free choice is never better', model.tenure(p), age);
        assert(all(tS(:) >= 0 & tR(:) >= 0 & tS(:) + tR(:) <= 1 + 1e-12), '%s at %d: shares off the simplex', model.tenure(p), age);
    end
end
end

function dc_choice_smoke()
% A small free-choice solve and panel for each tenure: finite values, the
% shares on the simplex in the policies and the panel, households that hold
% different shares, and no off-grid lookups.
for owner = [false true]
    p = config.params();
    p.grid_dims = [6 5 4 3]; p.gh_n = 3; p.is_owner = owner; p.dc_choice = true;
    p = config.derive(p);
    r = model.run(p, N_sim = 500, keep_sim = true, verbose = false);
    assert(all(isfinite(r.sol.V(:))), 'non-finite value');
    tS = r.sol.tau_pol; tR = r.sol.reit_pol;
    assert(all(tS(:) >= 0 & tR(:) >= 0 & tS(:) + tR(:) <= 1 + 1e-12), 'policy shares off the simplex');
    s = r.sim;
    assert(all(s.tau_A(:) >= 0 & s.reit_A(:) >= 0 & s.tau_A(:) + s.reit_A(:) <= 1 + 1e-12), 'panel shares off the simplex');
    ok = ~s.absorbed(:, 1:end-1);
    assert(std(s.tau_A(ok)) > 0 || std(s.reit_A(ok)) > 0, 'every household holds the same shares');
    assert(isfield(r.summary, 'dc_share_p50'), 'no share percentiles in the summary');
    assert(sum(r.checks.offgrid) == 0, 'off-grid lookups');
end
end

function fast_power_param()
% fast_power is a numerics primitive, on in production. A result saved before
% it existed took the powers with MATLAB's power: it is the same calibration
% as production with fast_power off, and not as production. derive refuses
% anything but true or false.
p = config.params();
assert(isfield(config.params(false), 'fast_power') && p.fast_power, 'fast_power is not an on primitive');
old = rmfield(p, 'fast_power');
assert(~ladder.same_calibration(old, p), 'a result without fast_power is production');
q = p; q.fast_power = false;
assert(ladder.same_calibration(old, q), 'a result without fast_power is not production with it off');
q.fast_power = 2;
assert(threw_id(@() config.derive(q), 'derive:fast_power'), 'derive took fast_power = 2');
end

function fast_power_step()
% The powers of the objective by multiplication. Owner with a bequest motive
% on a small grid; the ages 99 and 98 are solved with fast_power off and on
% from the same continuation. With gamma = 5 the two differ (the rule is in
% use), the value agrees to rounding at the median node, and it differs by
% more than 1e-6 at under 2% of the nodes: the search can settle on another
% point where two choices tie. With gamma = 5.5 the rule does not apply and
% the two are identical in every bit.
for g = [5 5.5]
    p = config.params(false); p.is_owner = true; p.gamma = g; p.chi = 2.5 ^ g;
    p.grid_dims = [6 5 4 3]; p.gh_n = 3; p.fast_power = false; p = config.derive(p);
    q = p; q.fast_power = true;
    [pf, sk, an] = config.model_inputs(p);
    [V, c, pi_] = solver.bellman_step_lna(p.T, [], p, pf, sk, an);
    for t = p.T - 1 : -1 : p.T - 2
        pol = struct('c', c, 'pi', pi_);
        [Va, ca, pa] = solver.bellman_step_lna(t, V, p, pf, sk, an, pol);
        [Vb, cb, pb] = solver.bellman_step_lna(t, V, q, pf, sk, an, pol);
        same = isequaln(Va, Vb) && isequaln(ca, cb) && isequaln(pa, pb);
        if g == 5
            d = abs(Vb(:) ./ Va(:) - 1);
            assert(~same, 't = %d: fast_power changed nothing at gamma = 5', t);
            assert(all(isfinite(Vb(:))) && median(d) < 1e-12 && mean(d > 1e-6) < 0.02, ...
                't = %d: median gap %.2g, share over 1e-6 %.3f', t, median(d), mean(d > 1e-6));
        else
            assert(same, 't = %d: fast_power changed the step at gamma = 5.5', t);
        end
        V = Va; c = ca; pi_ = pa;
    end
end
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
    assert(p.h_mult == config.nibud_lti(Y0, p.r_m, p.nibud_extra, p.nibud_year), 'not the Nibud multiple');
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
% The step that adds the income-stock correlation, on a small grid: one arm,
% since owners and renters share the income process, and the correlation on
% the quadrature nodes and in the panel equal to corr_SL.
p = ladder.params('corr_SL');
p.grid_dims = [6 5 4 3]; p.gh_n = 3;
p = config.derive(p);
assert(strcmp(model.tenure(p), 'nohousing'), 'one arm without housing');
r = model.run(p, N_sim = 2000, verbose = false);
assert(all(isfinite(r.sol.V(:))), 'non-finite value');
assert(abs(r.checks.corr_SL_nodes - p.corr_SL) < 1e-10, 'nodes correlation %.4f', r.checks.corr_SL_nodes);
assert(abs(r.checks.corr_SL_sim - p.corr_SL) < 0.01, 'panel correlation %.4f', r.checks.corr_SL_sim);
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
% saved, the default until 26 October 2026) and MATLAB's power (fast_power
% off, the only rule until 13 November 2026).
file = getenv('CGM_FLOOR_BASELINE');
if isempty(file) || ~isfile(file)
    error('run_tests:skip', 'CGM_FLOOR_BASELINE does not name the solve saved at 7b5143d');
end
B = load(file);
for owner = [false true]
    p = ladder.params(16); p.is_owner = owner;
    p.grid_dims = [8 6 6 4]; p.gh_n = 3;
    p.fmincon_algorithm = 'interior-point'; p.N_c = 41;
    p.grid_pow = 1; p.grid_pow_u2 = 1; p.pi_nothing_saved = 'one'; p.fast_power = false;
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
% the last period took the bequest as any other period, with MATLAB's power
% (fast_power off, the only rule until 13 November 2026).
file = getenv('CGM_BEQUEST_BASELINE');
if isempty(file) || ~isfile(file)
    error('run_tests:skip', 'CGM_BEQUEST_BASELINE does not name the solve saved at 3433323');
end
B = load(file);
cases = {18, false; 18, true; 1, false};
for k = 1:size(cases, 1)
    p = ladder.params(cases{k, 1}); p.is_owner = cases{k, 2};
    p.grid_dims = [8 6 6 4]; p.gh_n = 3; p.fast_power = false; p = config.derive(p);
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
