function R = robustness(step, opts)
%ROBUSTNESS  Re-solve one ladder step under other optimisers and grids, and overlay them.
%
%   ladder.robustness(8)                        % against the step at standard numerics
%   ladder.robustness('corr_SL', numerics='quick')
%   ladder.robustness(k, force=true)            % re-solve variants already saved
%   R = ladder.robustness(...)                  % R.<arm>.<variant> = result
%
%   The reference is the step at the given numerics, as ladder.run saves it
%   (run if missing), with the default fmincon_algorithm and use_refine. Three
%   sets of variants are solved for every arm, with the reference's number of
%   households and seed, so differences come from the solution and not from
%   sampling:
%     optimisers   the other two fmincon algorithms, with the reference's sweep
%                  setting
%     search       the global sweep switched, for the reference's algorithm and
%                  for active-set (interior-point when the reference is
%                  active-set)
%     grids        [9 9 6 5] and quick [12 12 8 6] with 3 quadrature nodes,
%                  fine [20 20 12 8] and twice the reference's u1 nodes with 5,
%                  all with the reference's algorithm and sweep setting
%   Each variant is saved to <numerics dir>/robustness/NN_<step>_<arm>_<variant>.mat
%   and reused while its calibration is unchanged. All three sets are drawn on
%   one page per arm with figures.robustness, robust_NN_<step>_<arm>.png in the
%   same folder.
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
A0 = p0.fmincon_algorithm; S0 = p0.use_refine;
V = struct('name', {}, 'label', {}, 'set', {}, 'dims', {}, 'gh_n', {}, 'algorithm', {}, 'refine', {});
for alg = setdiff({'active-set', 'sqp', 'interior-point'}, A0, 'stable')
    V(end+1) = solver_variant(alg{1}, S0, 'optimisers', dims, num.gh_n); %#ok<AGROW>
end
partner = 'active-set';
if strcmp(A0, 'active-set'), partner = 'interior-point'; end
V(end+1) = solver_variant(A0, ~S0, 'search', dims, num.gh_n);
V(end+1) = solver_variant(partner, ~S0, 'search', dims, num.gh_n);
V(end+1) = variant('coarse',   'grid [9 9 6 5], 3 nodes',    'grids', [9 9 6 5],    3, A0, S0);
V(end+1) = variant('quick',    'grid [12 12 8 6], 3 nodes',  'grids', [12 12 8 6],  3, A0, S0);
V(end+1) = variant('fine',     'grid [20 20 12 8], 5 nodes', 'grids', [20 20 12 8], 5, A0, S0);
V(end+1) = variant('dense_u1', sprintf('grid [%d %d %d %d], 5 nodes', 2 * dims(1), dims(2:4)), ...
                   'grids', [2 * dims(1), dims(2:4)], 5, A0, S0);

ref = ladder.run(S(k).name, numerics = opts.numerics);
ref = ref{1};
ref_label = sprintf('fmincon %s, grid [%d %d %d %d], %d quadrature nodes', solver_text(A0, S0), dims, num.gh_n);
nk = ladder.number(k, S); fk = ladder.number(k, S, true);

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
        file = fullfile(dir, sprintf('%s_%s_%s_%s.mat', fk, S(k).name, a, v.name));
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
    sets  = {'optimisers', 'search', 'grids'};
    names = {'Local optimiser', 'Global search', 'Grid'};
    G = struct('name', names, 'rs', [], 'labels', []);
    for g = 1:numel(sets)
        w = strcmp({V.set}, sets{g});
        G(g).rs = arrayfun(@(x) R.(a).(x.name), V(w), 'UniformOutput', false);
        G(g).labels = {V(w).label};
    end
    ttl = sprintf('Step %s, %s: %s. Robustness to the optimiser, the global search and the grid', ...
        nk, S(k).label, a);
    out = fullfile(dir, sprintf('robust_%s_%s_%s.png', fk, S(k).name, a));
    figures.robustness(R.(a).reference, ref_label, G, ttl, out);
    fprintf('Wrote %s\n', out);
end
end

function v = solver_variant(algorithm, refine, set, dims, gh_n)
short = struct('active_set', 'as', 'sqp', 'sqp', 'interior_point', 'ip');
tag = {'nosweep', 'sweep'};
name = sprintf('%s_%s', short.(strrep(algorithm, '-', '_')), tag{refine + 1});
v = variant(name, solver_text(algorithm, refine), set, dims, gh_n, algorithm, refine);
end

function t = solver_text(algorithm, refine)
if refine, t = [algorithm ' with global sweep'];
else,      t = [algorithm ', no global sweep'];
end
end

function v = variant(name, label, set, dims, gh_n, algorithm, refine)
v = struct('name', name, 'label', label, 'set', set, 'dims', dims, 'gh_n', gh_n, ...
           'algorithm', algorithm, 'refine', refine);
end
