function R = robustness(step, opts)
%ROBUSTNESS  Re-solve one ladder step under other optimisers and grids, and overlay them.
%
%   ladder.robustness(k)                        % against the step at standard numerics
%   ladder.robustness('corr_SL', numerics='quick')
%   ladder.robustness(k, force=true)            % re-solve variants already saved
%   R = ladder.robustness(...)                  % R.<arm>.<variant> = result
%
%   The reference is the step at the given numerics, as ladder.run saves it
%   (run if missing). Three sets of variants are solved for every arm, with the
%   reference's number of households and seed, so differences come from the
%   solution and not from sampling:
%     optimisers   fmincon sqp and interior-point after the sweep
%     search       active-set without the global sweep (fmincon from the warm start)
%     grids        [9 9 6] and quick [12 12 8] with 3 quadrature nodes, fine
%                  [20 20 12] and twice the reference's u1 nodes with 5
%   Each variant is saved to <numerics dir>/robustness/NN_<step>_<arm>_<variant>.mat
%   and reused while its calibration is unchanged. Each set is drawn over the
%   reference with figures.compare, one PNG per arm and set, in the same folder.
%
%   The parallel pool is part of the result: at step 1, sqp gave different
%   answers on a thread pool and on a process pool, while active-set gave the
%   same on both. The settings box of each figure names the pool of each run.

arguments
    step
    opts.numerics (1,:) char = 'standard'
    opts.force (1,1) logical = false
end

S   = ladder.steps();
num = ladder.numerics(opts.numerics);
[p0, k] = ladder.params(step);
p0.grid_dims = num.dims; p0.gh_n = num.gh_n;
p0 = config.derive(p0);
dir = fullfile(num.dir, 'robustness');
if ~isfolder(dir), mkdir(dir); end

dims = num.dims;
V = struct('name', {}, 'label', {}, 'set', {}, 'dims', {}, 'gh_n', {}, 'algorithm', {}, 'refine', {});
V(end+1) = variant('sqp',      'fmincon sqp',                          'optimisers', dims, num.gh_n, 'sqp', true);
V(end+1) = variant('ip',       'fmincon interior-point',               'optimisers', dims, num.gh_n, 'interior-point', true);
V(end+1) = variant('nosweep',  'active-set, no global sweep',          'search', dims, num.gh_n, 'active-set', false);
V(end+1) = variant('coarse',   'grid [9 9 6], 3 nodes',                'grids', [9 9 6],   3, 'active-set', true);
V(end+1) = variant('quick',    'grid [12 12 8], 3 nodes',              'grids', [12 12 8], 3, 'active-set', true);
V(end+1) = variant('fine',     'grid [20 20 12], 5 nodes',             'grids', [20 20 12], 5, 'active-set', true);
V(end+1) = variant('dense_u1', sprintf('grid [%d %d %d], 5 nodes', 2 * dims(1), dims(2:3)), ...
                               'grids', [2 * dims(1), dims(2:3)], 5, 'active-set', true);

ref = ladder.run(k, numerics = opts.numerics);
ref = ref{1};
ref_label = sprintf('reference: grid [%d %d %d], %d nodes, active-set with sweep', dims, num.gh_n);

R = struct();
for arm = fieldnames(ref).'
    a = arm{1};
    R.(a).reference = ref.(a);
    for v = V
        p = p0;
        p.is_owner = endsWith(a, 'owner');
        p.grid_dims = v.dims; p.gh_n = v.gh_n;
        p.fmincon_algorithm = v.algorithm; p.use_refine = v.refine;
        p = config.derive(p);
        file = fullfile(dir, sprintf('%02d_%s_%s_%s.mat', k, S(k).name, a, v.name));
        if ~opts.force && isfile(file)
            old = load(file, 'p');
            if ladder.same_calibration(old.p, p)
                fprintf('%s %s: reusing %s\n', a, v.name, file);
                R.(a).(v.name) = load(file);
                continue
            end
        end
        fprintf('%s %s: solving (%s) ...\n', a, v.name, v.label);
        r = model.run(p, N_sim = ref.(a).timing.N_sim, seed = ref.(a).timing.seed, verbose = false);
        fprintf('%s %s: %.0f s\n', a, v.name, r.timing.solve_sec);
        save(file, '-struct', 'r');
        R.(a).(v.name) = r;
    end
    for grp = {'optimisers', 'search', 'grids'}
        w = strcmp({V.set}, grp{1});
        rs = [{R.(a).reference}, arrayfun(@(x) R.(a).(x.name), V(w), 'UniformOutput', false)];
        labels = [{ref_label}, {V(w).label}];
        what = struct('optimisers', 'local optimiser', 'search', 'global search', 'grids', 'grid');
        ttl = sprintf('Step %d, %s: %s. Robustness to the %s', k, S(k).label, a, what.(grp{1}));
        out = fullfile(dir, sprintf('robust_%02d_%s_%s_%s.png', k, S(k).name, a, grp{1}));
        figures.compare(rs, labels, ttl, out);
        fprintf('Wrote %s\n', out);
    end
end
end

function v = variant(name, label, set, dims, gh_n, algorithm, refine)
v = struct('name', name, 'label', label, 'set', set, 'dims', dims, 'gh_n', gh_n, ...
           'algorithm', algorithm, 'refine', refine);
end
