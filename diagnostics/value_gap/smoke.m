% Smoke test of the point mode and the edge coordinate (27 November 2026).
% Run from the repository root with diagnostics/value_gap on the path and the
% committed step of 69150f1 as runs/old/bellman_step_lna_old.m (identity check).
%  1. Grid mode equals the committed step in every bit (steps 18 and 24, both
%     tenures, small grid, four ages).
%  2. The point mode at every node equals the grid mode.
%  3. The edge coordinate: a small solve of step 18, both tenures, with the
%     share and the edge coordinate, value function against simulation.
%  4. decompose_gap and fresh_policy run.
addpath(fullfile(pwd, 'diagnostics', 'value_gap'));
addpath(fullfile(pwd, 'runs', 'old'));   % bellman_step_lna_old: the committed step of 69150f1, renamed (the current folder would shadow a +solver on the path)
if isempty(gcp('nocreate')), utility.start_pool(); end
fprintf('\n== 1-2: grid mode against the committed step; point mode against the grid ==\n');
for st = [18 24]
    for own = [false true]
        p = ladder.params(st); p.is_owner = own; p.grid_dims = [8 6 6 4]; p.gh_n = 3; p = config.derive(p);
        [profile, shocks, ann_price] = config.model_inputs(p);
        t0 = tic; sol = solver.solve_lifecycle_lna(p, profile, shocks, ann_price, false);
        fprintf('step %d owner %d: solve %.0f s\n', st, own, toc(t0));
        for t = [p.T, 60, 43, 30, 5]
            Vn = []; pn = [];
            if t < p.T, Vn = sol.V(:,:,:,:,t+1); pn = struct('c', sol.c_pol(:,:,:,:,t+1), 'pi', sol.pi_pol(:,:,:,:,t+1)); end
            [V1, c1, p1, ~, ~, Vc1] = solver.bellman_step_lna(t, Vn, p, profile, shocks, ann_price, pn);
            [V0, c0, p0, ~, ~, Vc0] = bellman_step_lna_old(t, Vn, p, profile, shocks, ann_price, pn);
            [g1, g2] = utility.grid_at(p, t); [U1, U2, U3, Q] = ndgrid(g1, g2, p.u3_grid, p.q_grid);
            pts = struct('lam', U1(:), 'sA', U2(:).*(1-U1(:)).*U3(:), 'sH', U2(:).*(1-U1(:)).*(1-U3(:)), 'q', Q(:));
            if ~isempty(pn), pts.c = pn.c(:); pts.pi = pn.pi(:); end
            [Vp, cp] = solver.bellman_step_lna(t, Vn, p, profile, shocks, ann_price, [], [], pts);
            same = isequaln(V1, V0) && isequaln(c1, c0) && isequaln(p1, p0) && isequaln(Vc1, Vc0);
            fprintf('  t %2d: grid = committed in every bit: %d | point vs grid: max rel V %.2g, max |c| %.2g\n', t, same, ...
                max(abs(Vp(:) - V1(:)) ./ abs(V1(:))), max(abs(cp(:) - c1(:))));
        end
    end
end

fprintf('\n== 3: share against edge coordinate, step 18, grid 12x12x8x6, gh_n 3 ==\n');
for own = [false true]
    for crd = ["share", "edge"]
        p = ladder.params(18); p.is_owner = own; p.grid_dims = [12 12 8 6]; p.gh_n = 3; p.u2_coord = char(crd); p = config.derive(p);
        t0 = tic; r = model.run(p, N_sim = 2000, verbose = false); ts = toc(t0);
        sim = simulate.paths_lna(p, r.profile, r.sol, r.ann_price, 20000, 202, p.b0);
        [~, ce, se] = realised_utility(p, r.profile, sim);
        fprintf('owner %d %-5s: ce_entry %.4f, simulated %.4f (s.e. %.4f), gap %+.1f%%, ever bankrupt %.4f, offgrid [%s], %.0f s\n', ...
            own, crd, r.checks.ce_entry, ce, se, 100 * (r.checks.ce_entry / ce - 1), mean(any(sim.absorbed, 2)), ...
            num2str(r.checks.offgrid), ts);
        if own && crd == "edge", r_edge = r; end
        if own && crd == "share", r_share = r; end
    end
end

fprintf('\n== 4: decompose_gap and fresh_policy on the small owner solves ==\n');
for rr = {r_share, r_edge}
    r = rr{1};
    o = decompose_gap(r, N = 20000, n_rest = 1000);
    disp(o.sum);
    sim = simulate.paths_lna(r.p, r.profile, fresh_policy(r, 'all'), r.ann_price, 2000, 202, r.p.b0);
    [~, ce_f] = realised_utility(r.p, r.profile, sim);
    sim = simulate.paths_lna(r.p, r.profile, r.sol, r.ann_price, 2000, 202, r.p.b0);
    [~, ce_g] = realised_utility(r.p, r.profile, sim);
    fprintf('2,000 households: grid policy %.4f, fresh policy %.4f\n', ce_g, ce_f);
end
