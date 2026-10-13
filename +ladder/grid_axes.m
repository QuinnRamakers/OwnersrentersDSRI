function R = grid_axes(step, opts)
%GRID_AXES  Re-solve one ladder step with one grid axis refined at a time.
%
%   ladder.grid_axes(k)                     % each axis doubled, standard numerics
%   ladder.grid_axes(k, ladders=true)       % also refinement ladders on u1 and u2
%   ladder.grid_axes(k, numerics='quick', force=true)
%   R = ladder.grid_axes(...)               % R.<arm>.<variant> = result
%
%   The state grid has three axes and the shocks a fourth:
%     u1 = Y/W              income over total resources (liquid savings, pension
%                           account, house and this year's income); 1/u1 is total
%                           resources in years of income
%     u2 = (A+H)/(W-Y)      the share of wealth held in the pension account and the
%                           house rather than in liquid savings
%     u3 = A/(A+H)          the pension account's share of pension plus house
%     gh_n                  Gauss-Hermite nodes per shock (income, stocks, house)
%   Without housing u3 is 0 or 1 and its axis is collapsed to two nodes, so
%   refining it changes nothing; without housing and a DC pillar u2 is too.
%
%   Variants, all with the reference's solver, households and seed:
%     one axis doubled   u1, u2 and u3 base nodes doubled one at a time, and 7
%                        quadrature nodes instead of 5
%     ladders=true adds  u1 at 1.5, 2, 3 and 4 times its base nodes, and the
%                        base u1 nodes bunched toward its bottom (grid_pow 2);
%                        u2 at 1.5, 2 and 3 times, both doubled, and u1 x 4
%                        with u2 x 2
%   Each is saved to <numerics dir>/robustness/NN_<step>_<arm>_<name>.mat; a
%   run saved there for the same calibration under another name (for example
%   ladder.robustness's dense_u1) is reused. One page per arm, figures.robustness
%   with a row per set, robust_axes_NN_<step>_<arm>.png, and a table of the
%   largest gaps to the reference over ages 26-95.

arguments
    step
    opts.numerics (1,:) char = 'standard'
    opts.ladders (1,1) logical = false
    opts.force (1,1) logical = false
end

S   = ladder.steps();
num = ladder.numerics(opts.numerics);
[p0, k] = ladder.params(step);
p0.grid_dims = num.dims; p0.gh_n = num.gh_n;
p0 = config.derive(p0);
dir = fullfile(num.dir, 'robustness');
if ~isfolder(dir), mkdir(dir); end
b = num.dims; g = num.gh_n;

V = struct('name', {}, 'label', {}, 'set', {}, 'dims', {}, 'gh_n', {}, 'pow', {});
V(end+1) = variant('u1 x2', 'one', [2 * b(1), b(2:3)], g, 1);
V(end+1) = variant('u2 x2', 'one', [b(1), 2 * b(2), b(3)], g, 1);
V(end+1) = variant('u3 x2', 'one', [b(1:2), 2 * b(3)], g, 1);
V(end+1) = variant(sprintf('%d shock nodes', g + 2), 'one', b, g + 2, 1);
if opts.ladders
    for m = [1.5 2 3 4]
        V(end+1) = variant(sprintf('u1 x%g', m), 'u1', [round(m * b(1)), b(2:3)], g, 1); %#ok<AGROW>
    end
    V(end+1) = variant('u1 bunched low', 'u1', b, g, 2);
    for m = [1.5 2 3]
        V(end+1) = variant(sprintf('u2 x%g', m), 'u2', [b(1), round(m * b(2)), b(3)], g, 1); %#ok<AGROW>
    end
    V(end+1) = variant('u1 x2, u2 x2', 'u2', [2 * b(1), 2 * b(2), b(3)], g, 1);
    V(end+1) = variant('u1 x4, u2 x2', 'u2', [4 * b(1), 2 * b(2), b(3)], g, 1);
end

ref = ladder.run(k, numerics = opts.numerics);
ref = ref{1};
ref_label = sprintf('fmincon %s with global sweep %d, grid [%d %d %d], %d quadrature nodes', ...
    p0.fmincon_algorithm, p0.use_refine, b, g);

R = struct();
for arm = fieldnames(ref).'
    a = arm{1};
    R.(a).reference = ref.(a);
    saved = dir_runs(dir, k, S(k).name, a);
    for i = 1:numel(V)
        v = V(i);
        p = p0;
        p.is_owner = endsWith(a, 'owner');
        p.grid_dims = v.dims; p.gh_n = v.gh_n; p.grid_pow = v.pow;
        p = config.derive(p);
        file = fullfile(dir, sprintf('%02d_%s_%s_%s.mat', k, S(k).name, a, file_tag(v)));
        r = [];
        if ~opts.force
            for f = [{file}, saved]
                if ~isfile(f{1}), continue; end
                old = load(f{1}, 'p');
                if ladder.same_calibration(old.p, p)
                    fprintf('%s %s: reusing %s\n', a, v.label, f{1});
                    r = load(f{1});
                    break
                end
            end
        end
        if isempty(r)
            fprintf('%s %s: solving (grid [%d %d %d], %d nodes, grid_pow %g) ...\n', a, v.label, v.dims, v.gh_n, v.pow);
            r = model.run(p, N_sim = ref.(a).timing.N_sim, seed = ref.(a).timing.seed, verbose = false);
            fprintf('%s %s: %.0f s\n', a, v.label, r.timing.solve_sec);
            save(file, '-struct', 'r');
        end
        R.(a).(matlab.lang.makeValidName(v.label)) = r;
        V(i).r.(a) = r;
    end

    sets  = {'one', 'u1', 'u2'};
    names = {'One axis doubled', 'Income-share axis (u1)', 'Pension-share axis (u2)'};
    G = struct('name', {}, 'rs', {}, 'labels', {});
    for s = 1:numel(sets)
        w = find(strcmp({V.set}, sets{s}));
        if isempty(w), continue; end
        G(end+1) = struct('name', names{s}, 'rs', {arrayfun(@(j) V(j).r.(a), w, 'UniformOutput', false)}, ...
                          'labels', {arrayfun(@(j) describe(V(j)), w, 'UniformOutput', false)}); %#ok<AGROW>
    end
    ttl = sprintf('Step %d, %s: %s. Which grid axis matters', k, S(k).label, a);
    out = fullfile(dir, sprintf('robust_axes_%02d_%s_%s.png', k, S(k).name, a));
    figures.robustness(R.(a).reference, ref_label, G, ttl, out);
    fprintf('Wrote %s\n', out);
    print_gaps(R.(a).reference, V, a);
end
end

% ------------------------------------------------------------------------
function v = variant(label, set, dims, gh_n, pow)
v = struct('name', '', 'label', label, 'set', set, 'dims', dims, 'gh_n', gh_n, 'pow', pow);
end

function t = file_tag(v)
t = sprintf('g%dx%dx%d_gh%d', v.dims, v.gh_n);
if v.pow ~= 1, t = sprintf('%s_pow%g', t, v.pow); end
end

function s = describe(v)
s = sprintf('%s: grid [%d %d %d], %d nodes', v.label, v.dims, v.gh_n);
if v.pow ~= 1, s = sprintf('%s, grid_pow %g', s, v.pow); end
end

function F = dir_runs(dir, k, name, arm)
% Saved robustness runs of this step and arm, under any name.
L = dir_list(fullfile(dir, sprintf('%02d_%s_%s_*.mat', k, name, arm)));
F = fullfile(dir, L);
end

function L = dir_list(pattern)
d = builtin('dir', pattern);
L = {d.name};
end

function print_gaps(ref, V, a)
s0 = ref.summary; w = s0.ages >= 26 & s0.ages <= 95; ag = s0.ages(w);
fprintf('\n%s: largest gap to the reference, ages 26-95\n', a);
fprintf('  %-42s %14s %16s %18s\n', 'variant', 'pi', 'consumption %', 'liquid / income');
for i = 1:numel(V)
    s1 = V(i).r.(a).summary;
    [mp, ip] = max(abs(s1.pi(w) - s0.pi(w)));
    [mc, ic] = max(abs(s1.C.mean(w) ./ s0.C.mean(w) - 1));
    [mx, ix] = max(abs(s1.X.mean(w) - s0.X.mean(w)) ./ s0.Y.mean(w));
    fprintf('  %-42s %6.3f (age %d) %6.2f%% (age %d) %8.3f (age %d)\n', describe(V(i)), mp, ag(ip), ...
        100 * mc, ag(ic), mx, ag(ix));
end
end
