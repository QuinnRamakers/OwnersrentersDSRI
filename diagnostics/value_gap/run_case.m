function res = run_case(step, tenure, numerics, opts)
%RUN_CASE  The solver-simulation gap of one saved solve: decomposition and fresh policies.
%
%   res = run_case(18, 'owner', 'standard')
%   res = run_case(24, 'renter', 'standard', fresh=["all" "default"], N_fresh=20000)
%
%   Reads neural/data/solve_<step>_<tenure>_<numerics>.mat
%   (neural.make_testsets(..., keep_solve=true)) or opts.file, and writes
%   <out_dir>/gap_<step>_<tenure>_<numerics>.mat with
%     dec    decompose_gap on N_dec households (seed 303)
%     sims   the grid policy and each fresh policy (fresh_policy) simulated
%            on the same N_fresh households (seed 202): ce, its standard
%            error, the paired difference to the grid policy and its
%            standard error, years bankrupt, ever bankrupt, run time
%   Everything in multiples of entry income, as model.checks' ce_entry.

arguments
    step (1,1) double
    tenure char
    numerics char
    opts.file char = ''
    opts.out_dir char = fullfile(pwd, 'neural', 'data')
    opts.N_dec (1,1) double = 100000
    opts.n_rest (1,1) double = 5000
    opts.N_fresh (1,1) double = 20000
    opts.fresh string = "all"
    opts.decompose (1,1) logical = true
end
f = opts.file;
if isempty(f), f = fullfile(pwd, 'neural', 'data', sprintf('solve_%d_%s_%s.mat', step, tenure, numerics)); end
r = load(f).r;
p = r.p; g = p.gamma;
tag = sprintf('%d_%s_%s', step, tenure, numerics);
fprintf('\n=== %s: grid %dx%dx%dx%d, gh_n %d, ce_entry %.4f ===\n', tag, numel(p.u1_grid), numel(p.u2_grid), ...
    numel(p.u3_grid), numel(p.q_grid), p.gh_n, r.checks.ce_entry);
if isempty(gcp('nocreate')), utility.start_pool(); end
res = struct('tag', tag, 'ce_entry', r.checks.ce_entry, 'dims', [numel(p.u1_grid), numel(p.u2_grid), numel(p.u3_grid), numel(p.q_grid)], 'gh_n', p.gh_n);

if opts.decompose
    t0 = tic;
    res.dec = decompose_gap(r, N=opts.N_dec, seed=303, n_rest=opts.n_rest);
    res.dec_sec = toc(t0);
    fprintf('decomposition: %.0f s\n', res.dec_sec);
    disp(res.dec.sum);
    save(fullfile(opts.out_dir, ['gap_' tag '.mat']), '-struct', 'res');   % the decomposition, before the simulations
end

% The grid policy and the fresh policies on the same households
names = ["grid", opts.fresh];
rows = {};
U0 = [];
for k = 1:numel(names)
    t0 = tic;
    if names(k) == "grid"
        sol = r.sol;
    else
        sol = fresh_policy(r, char(names(k)));
    end
    sim = simulate.paths_lna(p, r.profile, sol, r.ann_price, opts.N_fresh, 202, p.b0);
    [U, ce, se] = realised_utility(p, r.profile, sim);
    sec = toc(t0);
    if k == 1, U0 = U; ce0 = ce; end
    % paired difference of the certainty equivalents (delta method)
    h = ce / ((1 - g) * mean(U)) * U - ce0 / ((1 - g) * mean(U0)) * U0;
    rows(end+1, :) = {char(names(k)), ce, se, ce - ce0, std(h) / sqrt(numel(h)), ...
        mean(sim.absorbed(:)), mean(any(sim.absorbed, 2)), median(sim.abs_age, 'omitnan'), sec}; %#ok<AGROW>
    fprintf('%-8s ce %.4f (s.e. %.4f), minus grid %+.4f (s.e. %.4f), years bankrupt %.4f, ever %.4f, median age %g, %.0f s\n', rows{end, :});
    if k == 1, dg = sim.diagnostics; res.sim_grid_offgrid = [dg.n_offgrid_u1, dg.n_offgrid_u2, dg.n_offgrid_u3, dg.n_offgrid_q]; end
end
res.sims = cell2table(rows, 'VariableNames', {'policy', 'ce', 'se', 'minus_grid', 'se_diff', 'years_bankrupt', 'ever_bankrupt', 'median_age', 'sec'});
disp(res.sims);
save(fullfile(opts.out_dir, ['gap_' tag '.mat']), '-struct', 'res');
end
