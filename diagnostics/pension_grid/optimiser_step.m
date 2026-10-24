function S = optimiser_step(arm, base, variants, ages, opts)
%OPTIMISER_STEP  The per-node search routines compared on one Bellman step.
%
%   From the repository root:
%       addpath diagnostics/pension_grid
%       S = optimiser_step('renter', 'pow3_32x32_lim_u3p2_cmin5000', ...
%                          {'', '_as', '_sqp', '_util', '_nosweep', '_nc11'}, [30 50 70 90])
%
%   base is a solved step-16 case (case_load); each variant is a suffix added
%   to it (case_params: _as, _sqp, _util, _nosweep, _nc<n>), '' being the
%   base's own routine. At each age the step is solved once per variant from
%   the same next-year value function and warm start, those of the solved
%   base, so the variants differ only in how they search (c, pi) at a node.
%   A higher value at a node is a better search: every value is the Bellman
%   objective at the policy the search returned.
%
%   Per variant and age:
%     sec        time of the step
%     loss_med, loss_p99, loss_max   shortfall of the node's value from the
%                best of all variants, in certainty-equivalent units,
%                1 - (V / V_best)^(1/(1-gamma)), over the nodes where the
%                household saves (c < 1 under the best variant)
%     loss_1e4   share of those nodes with a shortfall above 1e-4
%     flat_pi    share of the nodes within 1e-6 of the best value whose
%                equity share differs from the best variant's by more than 0.05
%     C_hh, pi_hh   the variant's policies read at the base's simulated
%                households at that age (as policy_gaps): mean consumption
%                over that of the best policy, minus 1, and the difference in
%                the mean liquid equity share of solvent households
%     reproduces whether the base's own routine ('') gave the solved step
%                again, value and consumption bit for bit
%   The best policy is, node by node, the policy of the variant with the
%   highest value. Saves S to <standard numerics dir>/pension_grid/
%   optimiser_step_16_<arm>_<base>.mat and prints one table per age.

arguments
    arm (1,:) char
    base (1,:) char
    variants (1,:) cell
    ages (1,:) double
    opts.save (1,1) logical = true
end

r = case_load(16, arm, base);
assert(~isempty(r), 'optimiser_step:missing', 'case %s %s is not solved.', arm, base);
P = cellfun(@(v) case_params(16, arm, [base v]), variants, 'UniformOutput', false);
p = r.p;
[profile, shocks, ann_price] = config.model_inputs(p);
s = figures.panel_data(r).sim;
gamma = p.gamma;

if isempty(gcp('nocreate')), utility.start_pool(); end
nthreads = maxNumCompThreads(1);
restore  = onCleanup(@() maxNumCompThreads(nthreads));

nv = numel(variants); na = numel(ages);
names = strrep(variants, '_', '');
names(cellfun(@isempty, names)) = {'default'};
S = struct('arm', arm, 'base', base, 'variants', {variants}, 'names', {names}, 'ages', ages);
f = {'sec', 'loss_med', 'loss_p99', 'loss_max', 'loss_1e4', 'flat_pi', 'C_hh', 'pi_hh'};
for k = 1:numel(f), S.(f{k}) = nan(nv, na); end
S.pol = cell(1, na);
S.reproduces = false(1, na);

for ia = 1:na
    t = ages(ia) - p.age0 + 1;
    V_next = r.sol.V(:, :, :, :, t+1);
    pol_next = struct('c', r.sol.c_pol(:, :, :, :, t+1), 'pi', r.sol.pi_pol(:, :, :, :, t+1));
    if ia == 1
        % One untimed step first, so that no routine's time carries the
        % first call's start-up cost.
        solver.bellman_step_lna(t, V_next, P{1}, profile, shocks, ann_price, pol_next);
    end
    V = cell(1, nv); C = V; PI = V;
    for k = 1:nv
        t0 = tic;
        [V{k}, C{k}, PI{k}] = solver.bellman_step_lna(t, V_next, P{k}, profile, shocks, ann_price, pol_next);
        S.sec(k, ia) = toc(t0);
    end
    Vs = cat(5, V{:});
    [V_best, kb] = max(Vs, [], 5);
    Cs = cat(5, C{:}); Ps = cat(5, PI{:});
    pick = @(X) X(sub2ind(size(X), (1:numel(V_best)).', kb(:)));
    c_best  = reshape(pick(reshape(Cs, [], nv)), size(V_best));
    pi_best = reshape(pick(reshape(Ps, [], nv)), size(V_best));
    saves = c_best(:) < 1;
    [Cb_hh, Pb_hh] = at_households(p, t, s, c_best, pi_best);
    for k = 1:nv
        loss = 1 - (V{k}(:) ./ V_best(:)) .^ (1 / (1 - gamma));
        loss = max(loss(saves), 0);
        S.loss_med(k, ia) = median(loss);
        S.loss_p99(k, ia) = prctile(loss, 99);
        S.loss_max(k, ia) = max(loss);
        S.loss_1e4(k, ia) = mean(loss > 1e-4);
        tie = loss < 1e-6;
        dpi = abs(PI{k}(saves) - pi_best(saves));
        S.flat_pi(k, ia) = mean(dpi(tie) > 0.05);
        [Ck, Pk] = at_households(p, t, s, C{k}, PI{k});
        S.C_hh(k, ia) = Ck / Cb_hh - 1;
        S.pi_hh(k, ia) = Pk - Pb_hh;
    end
    S.pol{ia} = struct('c_best', c_best, 'pi_best', pi_best, 'k_best', kb, 'C', {C}, 'PI', {PI});
    fprintf('\n%s %s, age %d (%d nodes, %d where the household saves)\n', arm, base, ages(ia), numel(V_best), nnz(saves));
    i0 = find(cellfun(@isempty, variants), 1);
    if ~isempty(i0)
        % The base's own routine from the base's own inputs reproduces the base.
        S.reproduces(ia) = isequal(V{i0}, r.sol.V(:, :, :, :, t)) && isequal(C{i0}, r.sol.c_pol(:, :, :, :, t));
        fprintf('the base''s routine reproduces the solved step: %d\n', S.reproduces(ia));
    end
    fprintf('%-10s %7s %10s %10s %10s %9s %8s %9s %8s\n', 'variant', 'sec', 'loss med', 'loss p99', 'loss max', '>1e-4', 'flat pi', 'C at hh', 'pi at hh');
    for k = 1:nv
        fprintf('%-10s %7.1f %10.2e %10.2e %10.2e %8.2f%% %7.2f%% %8.3f%% %+8.4f\n', names{k}, S.sec(k, ia), ...
            S.loss_med(k, ia), S.loss_p99(k, ia), S.loss_max(k, ia), 100 * S.loss_1e4(k, ia), ...
            100 * S.flat_pi(k, ia), 100 * S.C_hh(k, ia), S.pi_hh(k, ia));
    end
end

if opts.save
    num = ladder.numerics('standard');
    file = fullfile(num.dir, 'pension_grid', sprintf('optimiser_step_16_%s_%s.mat', arm, base));
    save(file, '-struct', 'S', '-v7.3');
    fprintf('Saved %s\n', file);
end
end

% ------------------------------------------------------------------------
function [Cm, Pm] = at_households(p, t, s, c_pol, pi_pol)
%AT_HOUSEHOLDS  Mean consumption and mean liquid equity share of the panel's
%   solvent households at period t under the policy (c_pol, pi_pol), read as
%   in policy_gaps.
q_grid = p.q_grid(:);
iq1 = find(q_grid == 1);
q_dep = numel(q_grid) > 1 && any(p.q_live(t:end));
[g1, g2] = utility.grid_at(p, t);
sAH = s.sA(:, t) + s.sH(:, t);
u1 = min(max(s.lambda(:, t), g1(1)), g1(end));
u2 = min(max(sAH ./ max(1 - s.lambda(:, t), 1e-12), g2(1)), g2(end));
u3 = min(max(s.sA(:, t) ./ max(sAH, 1e-12), 0), 1);
if q_dep
    ax = {g1, g2, p.u3_grid, q_grid};
    q  = min(max(s.q(:, t), q_grid(1)), q_grid(end));
    cf = griddedInterpolant(ax, c_pol, 'linear', 'nearest'); cf = cf(u1, u2, u3, q);
    pf = griddedInterpolant(ax, pi_pol, 'linear', 'nearest'); pf = pf(u1, u2, u3, q);
else
    ax = {g1, g2, p.u3_grid};
    cf = griddedInterpolant(ax, c_pol(:, :, :, iq1), 'linear', 'nearest'); cf = cf(u1, u2, u3);
    pf = griddedInterpolant(ax, pi_pol(:, :, :, iq1), 'linear', 'nearest'); pf = pf(u1, u2, u3);
end
LW = s.LW(:, t);
c  = max(min(cf, 1), 0) .* max(LW, 0);
pf = max(min(pf, 1), 0);
ok = true(size(c));
if model.floor_kind(p)
    c  = max(c, p.phi_path(t) * s.Y(:, t));
    ok = ~s.absorbed(:, t);
end
Cm = mean(c(ok));
Pm = mean(pf(ok));
end
