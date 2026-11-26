function files = make_replays(steps, opts)
%MAKE_REPLAYS  Quick-grid solves and their panels, for the Julia replay test.
%
%   files = neural.make_replays()
%   files = neural.make_replays({1, 6, '7b', 13}, N=2000, seed=101)
%
%   For each ladder step, and each tenure where the tenures differ, solves on
%   a small grid (grid_dims, gh_n), simulates N households and writes
%   neural.export_replay to <out_dir>/replay_<step>_<tenure>.mat. The panels
%   test the Julia year, not the model, so the grid only has to be the same
%   for MATLAB and Julia, not converged.

arguments
    steps cell = {1, 6, 12, 13, 18, 23}
    opts.N (1,1) double = 2000
    opts.seed (1,1) double = 101
    opts.grid_dims (1,4) double = [8 6 6 4]
    opts.gh_n (1,1) double = 3
    opts.out_dir char = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'neural', 'data')
end

if ~isfolder(opts.out_dir), mkdir(opts.out_dir); end
files = {};
for i = 1:numel(steps)
    p = ladder.params(steps{i});
    arms = {p.is_owner};
    if model.tenures_differ(p), arms = {false, true}; end
    for a = 1:numel(arms)
        pa = p;
        pa.is_owner = arms{a};
        pa.grid_dims = opts.grid_dims;
        pa.gh_n = opts.gh_n;
        pa = config.derive(pa);
        r = model.run(pa, N_sim=200, verbose=false);
        name = sprintf('replay_%s_%s.mat', p.ladder.number, model.tenure(pa));
        file = fullfile(opts.out_dir, name);
        neural.export_replay(r, opts.N, opts.seed, file);
        fprintf('%s: step %s, %s, solve %.1f s, ce_entry %.4f\n', name, ...
            p.ladder.number, model.tenure(pa), r.timing.solve_sec, r.checks.ce_entry);
        files{end+1} = file; %#ok<AGROW>
    end
end
end
