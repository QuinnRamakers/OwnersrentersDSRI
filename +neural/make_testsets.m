function files = make_testsets(steps, opts)
%MAKE_TESTSETS  Grid solves and their test panels, for training comparisons.
%
%   files = neural.make_testsets({1})
%   files = neural.make_testsets({1, 2}, numerics={'standard', 'fine'}, N=20000)
%
%   For each ladder step, each tenure where the tenures differ and each of the
%   ladder's numerics (ladder.numerics), solves the model on the grid,
%   simulates N households on fixed draws (seed) and writes
%   neural.export_replay to <out_dir>/testset_<step>_<tenure>_<numerics>.mat.
%   The same seed gives the same draws at every step with the same T and
%   correlations, so the network and the grid policy are compared on the
%   same households.

arguments
    steps cell = {1}
    opts.numerics cell = {'standard'}
    opts.N (1,1) double = 20000
    opts.seed (1,1) double = 202
    opts.out_dir char = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'neural', 'data')
end

if ~isfolder(opts.out_dir), mkdir(opts.out_dir); end
files = {};
for i = 1:numel(steps)
    p = ladder.params(steps{i});
    arms = {p.is_owner};
    if model.tenures_differ(p), arms = {false, true}; end
    for a = 1:numel(arms)
        for k = 1:numel(opts.numerics)
            n = ladder.numerics(opts.numerics{k});
            pa = p;
            pa.is_owner = arms{a};
            pa.grid_dims = n.dims;
            pa.gh_n = n.gh_n;
            pa = config.derive(pa);
            r = model.run(pa, N_sim=n.N_sim, verbose=false);
            name = sprintf('testset_%s_%s_%s.mat', p.ladder.number, model.tenure(pa), n.name);
            file = fullfile(opts.out_dir, name);
            neural.export_replay(r, opts.N, opts.seed, file);
            fprintf('%s: grid %dx%dx%dx%d, gh_n %d, solve %.1f s, ce_entry %.4f, offgrid [%s]\n', ...
                name, n.dims, n.gh_n, r.timing.solve_sec, r.checks.ce_entry, num2str(r.checks.offgrid));
            files{end+1} = file; %#ok<AGROW>
        end
    end
end
end
