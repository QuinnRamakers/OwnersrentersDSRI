function T = grid_study(cases, opts)
%GRID_STUDY  The value at entry against simulated welfare, case by case.
%
%   T = grid_study({ {18, 'owner', [64 32 40 8], 5, 'edge'}, ... }, tag='weekend')
%
%   Each case is {step, tenure, dims, gh_n, u2_coord} with an optional sixth
%   element, a struct of further numerics overrides (interp_method,
%   grid_pow_u2, ...). For each: ladder.params(step) with those numerics,
%   model.run (the solve), then simulate.paths_lna on N households (seed)
%   from the welfare anchor, scored by realised_utility (with the bequest
%   when chi > 0). One file per case,
%   <out_dir>/<tag>/<step>_<tenure>_<dims>_gh<gh>_<coord>[_<extra>].mat, with
%   the row and the age profiles (consumption, liquid wealth, the equity
%   share, the share bankrupt, by age; medians and means in entry income);
%   the solution itself is not kept (disk). A case whose file exists is
%   skipped, so a run can be started again after a stop. The table of all
%   cases in the folder is returned and written to <tag>/summary.md.

arguments
    cases cell
    opts.tag char = 'grid_study'
    opts.out_dir char = fullfile(utility.output_dir(), 'value_gap')
    opts.N (1,1) double = 100000
    opts.seed (1,1) double = 303
    opts.boundary (1,1) logical = true   % also score the boundary default rule (default as a choice)
end
d = fullfile(opts.out_dir, opts.tag);
if ~isfolder(d), mkdir(d); end
for i = 1:numel(cases)
    c = cases{i};
    [st, ten, dims, gh, crd] = c{1:5};
    extra = struct();
    if numel(c) >= 6, extra = c{6}; end
    name = sprintf('%d_%s_%dx%dx%dx%d_gh%d_%s', st, ten, dims, gh, crd);
    fx = fieldnames(extra);
    for k = 1:numel(fx), name = [name '_' fx{k} '-' strrep(num2str(extra.(fx{k})), ' ', '')]; end %#ok<AGROW>
    f = fullfile(d, [name '.mat']);
    if isfile(f), fprintf('%s: saved, skipped\n', name); continue, end
    fprintf('\n=== %s, started %s UTC ===\n', name, char(datetime('now', 'TimeZone', 'UTC')));
    p = ladder.params(st);
    p.is_owner = strcmp(ten, 'owner');
    p.grid_dims = dims; p.gh_n = gh; p.u2_coord = crd;
    for k = 1:numel(fx), p.(fx{k}) = extra.(fx{k}); end
    p = config.derive(p);
    t0 = tic;
    try
        r = model.run(p, N_sim = 2000, verbose = false);
    catch err
        fprintf('%s FAILED: %s\n', name, err.message);
        continue
    end
    solve_sec = r.timing.solve_sec;
    sim = simulate.paths_lna(p, r.profile, r.sol, r.ann_price, opts.N, opts.seed, p.b0);
    [U, ce, se] = realised_utility(p, r.profile, sim);
    Y0 = sim.Y(1, 1);
    prof = struct('age', sim.ages, ...
        'C_mean', mean(sim.C / Y0), 'C_med', median(sim.C / Y0), ...
        'X_mean', mean(sim.X / Y0), 'X_med', median(sim.X / Y0), ...
        'pi_mean', mean(sim.pi, 'omitnan'), 'bankrupt', mean(sim.absorbed));
    % the share of utility in the worst 1% of households (how far single households set the number)
    Us = sort(U); top = Us(1:ceil(0.01 * numel(U)));
    row = struct('name', name, 'step', st, 'tenure', ten, 'dims', dims, 'nodes', ...
        [numel(p.u1_grid), numel(p.u2_grid), numel(p.u3_grid), numel(p.q_grid)], 'gh_n', gh, 'u2_coord', crd, ...
        'ce_entry', r.checks.ce_entry, 'ce_sim', ce, 'se_sim', se, 'gap_pct', 100 * (r.checks.ce_entry / ce - 1), ...
        'ever_bankrupt', mean(any(sim.absorbed, 2)), 'worst1_share', sum(top) / sum(U), ...
        'c_bound_25_39', r.checks.c_bound_25_39, 'offgrid', r.checks.offgrid, ...
        'offgrid_sim', [sim.diagnostics.n_offgrid_u1, sim.diagnostics.n_offgrid_u2, sim.diagnostics.n_offgrid_u3, sim.diagnostics.n_offgrid_q], ...
        'solve_sec', solve_sec, 'total_sec', toc(t0), 'N', opts.N, 'seed', opts.seed, 'pool', r.sol.timing.pool.num_workers);
    save(f, 'row', 'prof', 'extra');
    fprintf(['%s: ce_entry %.4f, simulated %.4f (s.e. %.4f), value above simulation %+.1f%%, ever bankrupt %.4f, ' ...
        'worst 1%% hold %.2f of utility; c_bound_25_39 %.4g, offgrid [%s]; solve %.0f s\n'], name, row.ce_entry, ce, se, ...
        row.gap_pct, row.ever_bankrupt, row.worst1_share, row.c_bound_25_39, num2str(row.offgrid), solve_sec);
    % With default as a choice, the same households under the boundary rule
    % (the default decision solved at the state where the cell's corners
    % disagree; compare_rules), in the share coordinate.
    if opts.boundary && p.floor_absorbing && p.default_choice && strcmp(crd, 'share')
        Tb = compare_rules(r, N = opts.N, seed = opts.seed, rules = "boundary");
        row.ce_sim_boundary = Tb.ce_sim; row.se_boundary = Tb.se; row.gap_boundary = Tb.gap_pct;
        row.ever_boundary = Tb.ever_default; row.worst1_boundary = Tb.worst1_share;
        row.boundary_solved = Tb.solved; row.boundary_sec = Tb.sec;
        save(f, 'row', 'prof', 'extra');
    end
    clear r sim U
end
T = summarize(d);
end

function T = summarize(d)
fs = dir(fullfile(d, '*.mat'));
rows = {};
for i = 1:numel(fs)
    s = load(fullfile(d, fs(i).name), 'row'); w = s.row;
    b = [NaN NaN NaN];
    if isfield(w, 'ce_sim_boundary'), b = [w.ce_sim_boundary, w.se_boundary, w.gap_boundary]; end
    rows(end+1, :) = {w.name, w.ce_entry, w.ce_sim, w.se_sim, w.gap_pct, w.ever_bankrupt, w.worst1_share, w.solve_sec / 60, b(1), b(2), b(3)}; %#ok<AGROW>
end
if isempty(rows), T = table(); return, end
T = cell2table(rows, 'VariableNames', {'case', 'ce_entry', 'ce_sim', 'se_sim', 'gap_pct', 'ever_bankrupt', 'worst1_share', 'solve_min', ...
    'ce_sim_boundary', 'se_boundary', 'gap_boundary'});
disp(T);
fid = fopen(fullfile(d, 'summary.md'), 'w');
fprintf(fid, ['| case | ce_entry | simulated (s.e.) | value above simulation | ever bankrupt | worst 1%% share | solve min | ' ...
    'simulated, boundary rule (s.e.) | value above, boundary rule |\n|---|---|---|---|---|---|---|---|---|\n']);
for i = 1:height(T)
    fprintf(fid, '| %s | %.4f | %.4f (%.4f) | %+.1f%% | %.4f | %.2f | %.0f | %.4f (%.4f) | %+.1f%% |\n', T.case{i}, T.ce_entry(i), T.ce_sim(i), ...
        T.se_sim(i), T.gap_pct(i), T.ever_bankrupt(i), T.worst1_share(i), T.solve_min(i), ...
        T.ce_sim_boundary(i), T.se_boundary(i), T.gap_boundary(i));
end
fclose(fid);
end
