function smoke_fill_fix()
%SMOKE_FILL_FIX  Acceptance checks for the phantom-penalty fill fix.
%
%   Diagnosis being tested: solver.bellman_step used to fill every INFEASIBLE
%   node of the continuation interpolant with the GLOBAL MINIMUM feasible z.
%   That minimum was the z-image of the ruin assignment (~1e-4, against
%   ~0.02-0.07 at face-adjacent nodes), so any legitimate query landing in a
%   cell that touches the sX = 0 face was blended with ruin -- an artificial
%   penalty one cell wide along the whole face, at every age. Negative liquid
%   wealth is unreachable in this model, so the fill had no protective role.
%   It is now a nearest-feasible fill (solver.build_fill_map).
%
%   This file runs with the floor off (phi_floor = 0), which is where the
%   -1e15 ruin sentinel it refers to still exists. Under a positive floor
%   there is no sentinel: states short of resources take an ordinary value
%   built on u(phi_floor * Y) and the region has a gradient. The fill fix is
%   independent of that -- it is about infeasible cube nodes, not about how
%   ruined feasible states are priced -- so the checks below are unaffected,
%   but the specific z magnitudes quoted here are the phi_floor = 0 ones.
%
%   Checks:
%     (a) Monotonicity. The fill only RAISES z pointwise; linear interpolation
%         is monotone in its node values, the queries never leave the cube (see
%         check (b), which is what rules out 'linear' EXTRAPOLATION and its
%         negative weights), and the Bellman operator is monotone. So
%         V_new >= V_old at every feasible state and every t, with a strict
%         increase somewhere face-adjacent. Split in two:
%           (a1) one step from an identical V_next -- exact, tolerance-free;
%                this is the real test of the fill.
%           (a2) the full 76-period solve -- same claim, but the per-state
%                fmincon polish is not itself monotone (its basin shifts with
%                small continuation changes), so a small drift accumulates and
%                the tolerance is set to catch regressions, not round-off.
%         Reports the size of the correction in CEV units as a DISTRIBUTION
%         (median / p90 / p99 per sX band) plus the CEV at the t=1 welfare
%         anchors. Not the max: the max always lands on a near-ruin state
%         where |V| ~ 1e13 and (V_new/V_old)^(1/(1-gamma)) is hypersensitive
%         to economically empty changes, so it overstates the correction by
%         two orders of magnitude.
%     (b) The Task-2 feasibility assert (bellman_step:infeasible_query) never
%         fires during those solves.
%     (c) The calibrated welfare anchors (b0, b_alt) are exact grid members
%         after config.params, and remain so when a run script overrides N.
%     (d) welfare_dc_vs_nodc.m runs against the committed .mat files and
%         prints rows at b0 and b_alt.
%
%   Usage:  cd <repo>; tests/smoke_fill_fix   (or run tests.smoke_fill_fix)

repo = fileparts(fileparts(mfilename('fullpath')));
addpath(repo);

fprintf('=== smoke_fill_fix: acceptance checks for the phantom-penalty fix ===\n');
fprintf('repo: %s\n', repo);

pool = gcp('nocreate');
if isempty(pool)
    % On the laptop both the Threads AND Processes profiles default to
    % NumWorkers = 2 (MATLAB counts only P-cores on hybrid CPUs), so the
    % cluster object's NumWorkers has to be RAISED before asking for more --
    % parpool('Processes', n) alone just errors. On the cluster pod process
    % workers fail to spawn at all, hence the Threads fallback.
    try
        clus = parcluster('local');
        clus.NumWorkers = max(clus.NumWorkers, feature('numcores'));
        pool = parpool(clus, clus.NumWorkers);
    catch
        try, pool = parpool('Threads'); catch, warning('smoke_fill_fix:nopool', 'no pool'); end
    end
end
if ~isempty(pool)
    fprintf('pool: %s, %d workers\n', class(pool), pool.NumWorkers);
end

check_c(repo);
res = check_ab(repo);
check_d(repo);

fprintf('\n=== summary ===\n');
fprintf('(a) size of the correction, in CEV units:\n');
fprintf('    %-8s %10s %10s %10s   %12s %12s\n', ...
    'tenure', 'median', 'p90', 'p99', 'anchor b0', 'anchor b_alt');
for i = 1:numel(res)
    fprintf('    %-8s %+9.3f%% %+9.3f%% %+9.3f%%   %+11.3f%% %+11.3f%%\n', ...
        res(i).tenure, 100*res(i).med, 100*res(i).p90, 100*res(i).p99, ...
        100*res(i).cev_b0, 100*res(i).cev_balt);
end
fprintf(['    The t=1 anchor columns are the quotable numbers. The pooled max\n' ...
         '    (renter %+.0f%%, owner %+.0f%%) is a near-ruin tail artefact of the CEV\n' ...
         '    ratio, NOT a welfare gain -- see the per-band output above.\n'], ...
        100*res(1).mx, 100*res(2).mx);
fprintf('All acceptance checks passed.\n');
end

% -------------------------------------------------------------------------
function check_c(~)
fprintf('\n--- (c) welfare anchors are exact grid members ---\n');
p = config.params();
% Pinned to the simplex: this file drives the simplex solver/simulator
% directly, and config.params now defaults to the cube (utility.active_grid).
p.grid_type = 'simplex';
assert_anchor(p, 'config.params defaults');
fprintf('    config.params: N_lambda=%d N_sA=%d N_sH=%d\n', p.N_lambda, p.N_sA, p.N_sH);

% Simulate a run-script override of N followed by the mandatory re-insertion.
q = p;
q.N_lambda = 25; q.N_sA = 15; q.N_sH = 15;
q.lambda_grid = linspace(0, 1, q.N_lambda).';
q.sA_grid     = linspace(0, 1, q.N_sA).';
q.sH_grid     = linspace(0, 1, q.N_sH).';
q = config.insert_anchor_nodes(q);
assert_anchor(q, '25/15/15 override + insert_anchor_nodes');
fprintf('    after override: N_lambda=%d N_sH=%d\n', q.N_lambda, q.N_sH);

% And the failure mode the solve_lifecycle guard exists to catch.
r = p;
r.lambda_grid = linspace(0, 1, 25).'; r.N_lambda = 25;
r.sA_grid     = linspace(0, 1, 15).'; r.N_sA     = 15;
r.sH_grid     = linspace(0, 1, 15).'; r.N_sH     = 15;
fired = false;
try
    solver.solve_lifecycle(r, struct('mu_growth', 0, 'sigma_l_log', 0, 'p_surv', 1), ...
                           struct(), ones(r.T, 1));
catch ME
    fired = strcmp(ME.identifier, 'solve_lifecycle:anchor_missing');
end
assert(fired, 'smoke_fill_fix:guard_silent', ...
    'solve_lifecycle did not reject a grid rebuild that dropped the anchors.');
fprintf('    guard fires on a rebuild that drops the anchors: OK\n');
fprintf('(c) PASS\n');
end

function assert_anchor(p, tag)
b = [p.b0, p.b_alt]; nm = {'b0', 'b_alt'};
for a = 1:2
    den = 1 + p.h_mult + b(a);
    e1 = min(abs(p.lambda_grid - 1/den));
    e2 = min(abs(p.sH_grid - p.h_mult/den));
    assert(e1 == 0 && e2 == 0, 'smoke_fill_fix:anchor', ...
        '%s: anchor %s not exact (lambda err %g, sH err %g)', tag, nm{a}, e1, e2);
end
end

% -------------------------------------------------------------------------
function res = check_ab(~)
fprintf('\n--- (a)/(b) old vs new fill on a smoke solve ---\n');
tenures = {'renter', 'owner'};
res = struct('tenure', {}, 'med', {}, 'p90', {}, 'p99', {}, 'mx', {}, ...
             'cev_b0', {}, 'cev_balt', {});

for i = 1:numel(tenures)
    p = smoke_params(strcmp(tenures{i}, 'owner'));
    [~, mu_growth, sigma_l_log] = config.income_profile(p);
    profile = struct('mu_growth', mu_growth, 'sigma_l_log', sigma_l_log, ...
                     'p_surv', config.survival(p));
    shocks    = grids.shock_grid(p);
    ann_price = pension.annuity_price(p, profile, shocks);

    p_old = p; p_old.legacy_fill = true;

    % (a1) Tolerance-free check of the claim the fix actually rests on: from
    % an IDENTICAL V_next, one Bellman step under the new fill is >= the old
    % one at every feasible state, exactly. No optimiser path-dependence can
    % have accumulated yet, so this must hold at tol 0. If it ever fails, the
    % fill itself is wrong; the lifecycle check below cannot distinguish that
    % from polish noise.
    VT = solver.bellman_step(p.T, [], p, profile, shocks, ann_price);
    V1o = solver.bellman_step(p.T-1, VT, p_old, profile, shocks, ann_price);
    V1n = solver.bellman_step(p.T-1, VT, p,     profile, shocks, ann_price);
    [Lam0, SA0, SH0] = ndgrid(p.lambda_grid, p.sA_grid, p.sH_grid);
    f0 = (Lam0 + SA0 + SH0) <= 1 + 1e-12;
    ok0 = f0 & isfinite(V1o) & isfinite(V1n);
    d1  = (V1n(ok0) - V1o(ok0)) ./ abs(V1o(ok0));
    assert(min(d1) >= 0, 'smoke_fill_fix:onestep', ...
        ['%s: a SINGLE Bellman step from identical V_next lowered V by %g ' ...
         '(relative). The fill does not dominate pointwise -- this is a real ' ...
         'defect, not optimiser noise.'], tenures{i}, -min(d1));
    fprintf('  %s: one-step monotonicity exact (worst %g, best %+.3f, %d/%d states raised)\n', ...
        tenures{i}, min(d1), max(d1), sum(d1 > 0), numel(d1));

    % (b) rides along: bellman_step:infeasible_query would abort either solve.
    fprintf('  %s: solving with OLD (global-min) fill ...\n', tenures{i});
    s_old = solver.solve_lifecycle(p_old, profile, shocks, ann_price);
    fprintf('  %s: solving with NEW (nearest-feasible) fill ...\n', tenures{i});
    s_new = solver.solve_lifecycle(p,     profile, shocks, ann_price);

    [Lam, SA, SH] = ndgrid(p.lambda_grid, p.sA_grid, p.sH_grid);
    feas = (Lam + SA + SH) <= 1 + 1e-12;

    % Monotonicity, and the size of the correction in CEV units. V is CRRA
    % with gamma > 1 (V < 0), so the certainty-equivalent ratio is
    % (V_new/V_old)^(1/(1-gamma)) - 1. Ruin states (V = -1e15) are excluded
    % from the CEV ranking: they are set before interpolation and carry no
    % fill information, but they would otherwise dominate the max.
    % Violations are measured RELATIVE to the local |V| scale: V is CRRA with
    % gamma=5, so |V| spans many orders of magnitude across the grid and a
    % flat 1e-10 would be meaninglessly tight at one end and loose at the
    % other. Anything above optimiser noise is a real monotonicity failure.
    % CEV gain grouped by distance from the sX = 0 face. The phantom penalty
    % was one interpolation cell wide, so the gain should be largest on the
    % face and fade in the interior -- that shape is what identifies the
    % diagnosis. Collect the VALUES per band, not just the max: within any
    % band the max is dominated by near-ruin states and says nothing about
    % the typical correction (see the pooled distribution below).
    sX_all = 1 - Lam - SA - SH;
    % First edge is -inf, not 0: sX on the face evaluates to a tiny negative
    % (~-1e-17) in floating point, and those states belong in the "on face" bin.
    edges  = [-inf 1e-12 0.05 0.15 0.35 inf];
    blab   = {'sX = 0 (on face)', '0 < sX <= 0.05', '0.05 < sX <= 0.15', ...
              '0.15 < sX <= 0.35', 'sX > 0.35'};
    bvals  = repmat({[]}, 1, numel(blab));

    worst_rel = 0; n_viol = 0; n_tot = 0; best = -inf; best_idx = []; best_t = NaN;
    for t = 1:p.T
        Vo = s_old.V(:,:,:,t); Vn = s_new.V(:,:,:,t);
        good = feas & isfinite(Vo) & isfinite(Vn);
        if ~any(good(:)), continue; end
        rel  = (Vn(good) - Vo(good)) ./ max(abs(Vo(good)), realmin);
        worst_rel = min(worst_rel, min(rel));
        n_viol = n_viol + sum(rel < -1e-12);
        n_tot  = n_tot + numel(rel);

        % Ruin states (V = -1e15) are set BEFORE any interpolation, so they
        % carry no fill information; excluded from the CEV ranking.
        ok = good & ~(Vo < -1e14) & ~(Vn < -1e14);
        if ~any(ok(:)), continue; end
        cev = nan(size(Vo));
        cev(ok) = (Vn(ok) ./ Vo(ok)) .^ (1/(1 - p.gamma)) - 1;
        [m, k] = max(cev(:));
        if isfinite(m) && m > best
            best = m; best_idx = k; best_t = t;
        end
        for bb = 1:numel(blab)
            sel = ok & sX_all >= edges(bb) & sX_all < edges(bb+1) & isfinite(cev);
            if any(sel(:)), bvals{bb} = [bvals{bb}; cev(sel)]; end
        end
    end

    % Over a full 76-period backward induction the EXACT operator is still
    % monotone, but the per-state fmincon polish is not: bellman_step's own
    % comments note that the basin it reaches from a single argmax start
    % shifts with small continuation changes, and the rhs surface is
    % multimodal in c with narrow interpolation-kink ridges. So tiny
    % violations accumulate that are optimiser path-dependence, not fill
    % defects -- (a1) above is the tolerance-free test of the fill itself.
    % The tolerance here is set to catch a real regression (orders of
    % magnitude larger) while tolerating that drift.
    tol = 1e-3;
    fprintf('  %s: worst relative decrease %.3g in %d/%d state-periods (tol %.0e)\n', ...
        tenures{i}, worst_rel, n_viol, n_tot, tol);
    assert(worst_rel >= -tol, 'smoke_fill_fix:monotone', ...
        ['%s: new fill LOWERED V by %g (relative) at some feasible state -- far ' ...
         'beyond fmincon basin drift, so the fill or the operator is wrong.'], ...
        tenures{i}, -worst_rel);
    assert(best > 0, 'smoke_fill_fix:no_change', ...
        '%s: new fill changed nothing -- expected a strict increase near the sX=0 face.', ...
        tenures{i});

    fprintf('  %s: median CEV gain by distance from the sX=0 face:\n', tenures{i});
    for bb = 1:numel(blab)
        if ~isempty(bvals{bb})
            fprintf('       %-20s median %+8.3f%%   p90 %+9.3f%%   (n=%d)\n', ...
                blab{bb}, 100*median(bvals{bb}), 100*prctile(bvals{bb}, 90), ...
                numel(bvals{bb}));
        end
    end

    % Pooled distribution. The MAX is reported last and deliberately not as
    % the headline: it always lands on a near-ruin state where |V| ~ 1e13 and
    % the CEV ratio (V_new/V_old)^(1/(1-gamma)) is hypersensitive to changes
    % that carry no economic content. The median is the honest summary.
    allc = vertcat(bvals{:});
    fprintf('  %s: pooled CEV -- median %+.3f%%  p90 %+.3f%%  p99 %+.3f%%  max %+.1f%% (near-ruin tail)\n', ...
        tenures{i}, 100*median(allc), 100*prctile(allc,90), ...
        100*prctile(allc,99), 100*max(allc));

    % The number that actually gets quoted: welfare at the t=1 anchor states.
    % Read AT the grid node (Task 3 made these exact members), so this is a
    % solved value with no interpolation and no NaN-fill in the way.
    ia0 = find(p.sA_grid == 0, 1);
    anc = [p.b0, p.b_alt]; cev_a = nan(1, 2);
    for a = 1:2
        den = 1 + p.h_mult + anc(a);
        il0 = find(p.lambda_grid == 1/den, 1);
        ih0 = find(p.sH_grid == p.h_mult/den, 1);
        vo = s_old.V(il0, ia0, ih0, 1); vn = s_new.V(il0, ia0, ih0, 1);
        cev_a(a) = (vn/vo)^(1/(1-p.gamma)) - 1;
        fprintf('  %s: t=1 anchor b=%.4f -> CEV %+.3f%%  (V %.4e -> %.4e)\n', ...
            tenures{i}, anc(a), 100*cev_a(a), vo, vn);
    end

    res(i) = struct('tenure', tenures{i}, 'med', median(allc), ...
                    'p90', prctile(allc, 90), 'p99', prctile(allc, 99), ...
                    'mx', max(allc), 'cev_b0', cev_a(1), 'cev_balt', cev_a(2));
end
fprintf('(a) PASS  (b) PASS -- bellman_step:infeasible_query never fired\n');
end

function p = smoke_params(is_owner)
% Sized so the four solves (2 tenures x old/new fill) finish in well under an
% hour on a 2-worker laptop pool. The per-state fmincon polish dominates the
% cost, so the number of FEASIBLE STATES is the knob that matters -- N_c/N_pi
% barely move it. Raise N to 12+ on the cluster for a sharper reading; the
% monotonicity property being tested is grid-independent.
p = config.params();
% Pinned to the simplex: this file drives the simplex solver/simulator
% directly, and config.params now defaults to the cube (utility.active_grid).
p.grid_type = 'simplex';
p.phi_floor    = 0;        % the fill fix is a phi_floor = 0 result; see the header
p.is_owner     = is_owner;
p.kappa        = 0;        % nodc regime: fastest, and the Task-4 benchmark
p.choose_tau_S = false;
p.gh_n         = 3;
p.N_lambda = 10; p.N_sA = 10; p.N_sH = 10;
p.lambda_grid = linspace(0, 1, p.N_lambda).';
p.sA_grid     = linspace(0, 1, p.N_sA).';
p.sH_grid     = linspace(0, 1, p.N_sH).';
p = config.insert_anchor_nodes(p);   % (c) again, on the grid actually solved
p.N_c = 11; p.N_pi = 11;
end

% -------------------------------------------------------------------------
function check_d(repo)
fprintf('\n--- (d) welfare_dc_vs_nodc.m on the committed .mat files ---\n');
need = {'combined_renter_nodc.mat', 'combined_renter_freetau.mat', ...
        'combined_owner_nodc.mat',  'combined_owner_freetau.mat'};
for i = 1:numel(need)
    if ~isfile(fullfile(repo, need{i}))
        warning('smoke_fill_fix:no_mat', ...
            '%s missing -- skipping (d).', need{i});
        return
    end
end
out = run_isolated(fullfile(repo, 'welfare_dc_vs_nodc.m'));
disp(out);
n_cal = numel(strfind(out, 'calibrated (b0)'));
n_sen = numel(strfind(out, 'sensitivity (b_alt)'));
assert(n_cal == 2 && n_sen == 2, 'smoke_fill_fix:no_anchor_rows', ...
    'expected one b0 and one b_alt row per tenure, got %d and %d', n_cal, n_sen);
fprintf('(d) PASS -- b0 and b_alt rows printed for both tenures\n');
end

function out = run_isolated(script_path)
% run() executes the script in the CALLER's workspace; keep that pollution
% inside this one-variable helper rather than in check_d.
out = evalc('run(script_path)');
end
