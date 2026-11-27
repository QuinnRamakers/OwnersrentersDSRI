function T = eval_grids(r, grids, opts)
%EVAL_GRIDS  The solver's value of r's grid policy on other grids.
%
%   T = eval_grids(r, {[64 16 40 17], 5; [128 32 40 17], 5})
%   T = eval_grids(r, grids, interp_method='makima')
%
%   As neural.eval_refinement for the grid policy alone (no network): each
%   row of grids is base dims on (u1, u2, u3, q) and gh_n; r's policy, read
%   off r's grid as the simulator reads it, is valued by backward induction
%   with nothing searched (neural.evaluate_policy). As the evaluation grid
%   refines, the value at entry should approach what the policy delivers in
%   simulation; if it does only when several axes refine together, the edge
%   the interpolation misses is curved across them. opts.grid_pow etc. may
%   change the node placement of the evaluation grids. Prints and returns a
%   table; opts.save_to writes it.

arguments
    r struct
    grids cell
    opts.interp_method char = ''
    opts.interp_space char = ''
    opts.grid_pow double = []
    opts.grid_pow_u2 double = []
    opts.grid_pow_q double = []
    opts.save_to char = ''
end
gpol = neural.grid_policy_fn(r);
base = ladder.params(r.p.ladder.number);
base.is_owner = r.p.is_owner;
if ~isempty(opts.interp_method), base.interp_method = opts.interp_method; end
if ~isempty(opts.interp_space), base.interp_space = opts.interp_space; end
if ~isempty(opts.grid_pow), base.grid_pow = opts.grid_pow; end
if ~isempty(opts.grid_pow_u2), base.grid_pow_u2 = opts.grid_pow_u2; end
if ~isempty(opts.grid_pow_q), base.grid_pow_q = opts.grid_pow_q; end
rows = {};
for i = 1:size(grids, 1)
    p = base;
    p.grid_dims = grids{i, 1};
    p.gh_n = grids{i, 2};
    p = config.derive(p);
    e = neural.evaluate_policy(p, gpol);
    nodes = sprintf('%dx%dx%dx%d', numel(p.u1_grid), numel(p.u2_grid), numel(p.u3_grid), numel(p.q_grid));
    rows(end+1, :) = {mat2str(grids{i, 1}), grids{i, 2}, nodes, e.ce_entry, e.sec}; %#ok<AGROW>
    fprintf('eval %s gh %d (%s): grid policy %.4f (%.0f s)\n', mat2str(grids{i, 1}), grids{i, 2}, nodes, e.ce_entry, e.sec);
    clear e
end
T = cell2table(rows, 'VariableNames', {'dims', 'gh_n', 'nodes', 'ce_policy', 'sec'});
disp(T);
if ~isempty(opts.save_to), save(opts.save_to, 'T'); end
end
