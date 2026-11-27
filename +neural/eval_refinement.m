function T = eval_refinement(r, net_file, grids, opts)
%EVAL_REFINEMENT  The solver's value of two fixed policies on finer and finer grids.
%
%   r = load('neural/data/solve_18_renter_standard.mat').r;
%   T = neural.eval_refinement(r, 'net_step18_renter_k3000_run1.mat', ...
%           {[16 16 10 8], 5; [32 16 40 4], 5; [64 32 40 4], 5})
%
%   For each grid (dims on u1, u2, u3, q and gh_n), the value at entry that
%   solver.bellman_step_lna gives, with nothing searched, to the grid policy
%   of r (read off r's grid as the simulator reads it, neural.grid_policy_fn)
%   and to the network (neural.net_policy). Each policy is the same function
%   on every grid, so as the grid refines both values should approach what
%   the policy delivers in simulation, and their difference the simulated
%   difference. ce in multiples of entry income, as model.checks.

arguments
    r struct
    net_file char
    grids cell
    opts.data char = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'neural', 'data')
end

net = load(fullfile(opts.data, net_file));
gpol = neural.grid_policy_fn(r);
base = ladder.params(r.p.ladder.number);
base.is_owner = r.p.is_owner;
rows = {};
for i = 1:size(grids, 1)
    p = base;
    p.grid_dims = grids{i, 1};
    p.gh_n = grids{i, 2};
    p = config.derive(p);
    eg = neural.evaluate_policy(p, gpol);
    en = neural.evaluate_policy(p, net);
    rows(end+1, :) = {mat2str(grids{i, 1}), grids{i, 2}, ...
        sprintf('%dx%dx%dx%d', numel(p.u1_grid), numel(p.u2_grid), numel(p.u3_grid), numel(p.q_grid)), ...
        eg.ce_entry, en.ce_entry, en.ce_entry - eg.ce_entry, eg.sec + en.sec}; %#ok<AGROW>
    fprintf('%s gh %d: grid policy %.4f, network %.4f, network - grid %+.4f (%.0f s)\n', ...
        mat2str(grids{i, 1}), grids{i, 2}, eg.ce_entry, en.ce_entry, en.ce_entry - eg.ce_entry, eg.sec + en.sec);
end
T = cell2table(rows, 'VariableNames', {'dims', 'gh_n', 'nodes', 'ce_grid_policy', 'ce_network', 'diff', 'sec'});
end
