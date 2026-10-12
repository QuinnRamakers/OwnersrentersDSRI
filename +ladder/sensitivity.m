function R = sensitivity(step, opts)
%SENSITIVITY  Re-solve one ladder step with single primitives moved, and draw them against it.
%
%   ladder.sensitivity('aow')                    % the step's own vary list, standard numerics
%   ladder.sensitivity(k, numerics='quick')
%   ladder.sensitivity(k, vary=struct('replacement', [0.2 0.4]))
%   ladder.sensitivity(k, force=true)            % re-solve variants already saved
%   R = ladder.sensitivity(...)                  % R.<arm>.<variant> = result
%
%   Each field of vary is a primitive of config.params and each of its values
%   one variant: the step with that primitive set to that value and everything
%   else as in the step. Without vary, the step's own vary field in
%   ladder.steps is used. The reference is the step as ladder.run saves it (run
%   if missing). Every variant is solved for every arm at the reference's
%   numerics, number of households and seed, saved to
%       <numerics dir>/sensitivity/NN_<step>_<arm>_<field>_<value>.mat
%   and reused while its calibration is unchanged. Pages, in the same folder:
%     sens_NN_<step>_<arm>_<field>.png          the step in black and every value
%                                               of one primitive (figures.compare)
%     sens_NN_<step>_<arm>_<field>_<value>.png  the step against one variant, both
%                                               with their bands (figures.step_dashboard)
%   view is passed to figures.compare.

arguments
    step
    opts.numerics (1,:) char = 'standard'
    opts.vary = []
    opts.force (1,1) logical = false
    opts.view (1,:) char = 'pension'
end

S = ladder.steps();
[p0, k] = ladder.params(step);
vary = opts.vary;
if isempty(vary), vary = S(k).vary; end
assert(isstruct(vary) && ~isempty(fieldnames(vary)), 'ladder:no_vary', ...
    'Step %d (%s) lists nothing to vary; pass vary=struct(...).', k, S(k).name);
prim = config.params(false);
for f = fieldnames(vary).'
    assert(isfield(prim, f{1}), 'ladder:unknown_field', ...
        '%s is not a primitive of config.params.', f{1});
end
num = ladder.numerics(opts.numerics);
p0.grid_dims = num.dims; p0.gh_n = num.gh_n;
p0 = config.derive(p0);
dir = fullfile(num.dir, 'sensitivity');
if ~isfolder(dir), mkdir(dir); end

ref = ladder.run(k, numerics = opts.numerics);
ref = ref{1};
R = struct();
for arm = fieldnames(ref).'
    a = arm{1};
    R.(a).reference = ref.(a);
    for f = fieldnames(vary).'
        fld = f{1};
        ref_label = sprintf('%d %s: %s = %s (the step)', k, S(k).name, fld, val(p0.(fld)));
        rs = {ref.(a)}; labels = {ref_label};
        for v = vary.(fld)(:).'
            name = sprintf('%s_%s', fld, strrep(sprintf('%g', v), '.', 'p'));
            p = p0;
            p.is_owner = endsWith(a, 'owner');
            p.(fld) = v;
            p = config.derive(p);
            file = fullfile(dir, sprintf('%02d_%s_%s_%s.mat', k, S(k).name, a, name));
            r = [];
            if ~opts.force && isfile(file)
                old = load(file, 'p');
                if ladder.same_calibration(old.p, p)
                    fprintf('%s %s: reusing %s\n', a, name, file);
                    r = load(file);
                end
            end
            if isempty(r)
                fprintf('%s %s: solving (%s = %s) ...\n', a, name, fld, val(v));
                r = model.run(p, N_sim = ref.(a).timing.N_sim, seed = ref.(a).timing.seed, verbose = false);
                fprintf('%s %s: %.0f s\n', a, name, r.timing.solve_sec);
                save(file, '-struct', 'r');
            end
            R.(a).(name) = r;
            label = sprintf('%s = %s', fld, val(v));
            rs{end+1} = r; labels{end+1} = label; %#ok<AGROW>
            figures.step_dashboard(ref.(a), r, {ref_label, label}, ...
                sprintf('Step %d, %s: %s with %s against the step', k, S(k).label, a, label), ...
                fullfile(dir, sprintf('sens_%02d_%s_%s_%s.png', k, S(k).name, a, name)), ...
                changes = {sprintf('%s: %s -> %s', fld, val(p0.(fld)), val(v))});
        end
        out = fullfile(dir, sprintf('sens_%02d_%s_%s_%s.png', k, S(k).name, a, fld));
        figures.compare(rs, labels, sprintf('Step %d, %s: %s, sensitivity to %s', ...
            k, S(k).label, a, fld), out, view = opts.view);
        fprintf('Wrote %s\n', out);
    end
end
end

function s = val(v)
if ischar(v) || isstring(v), s = char(v); else, s = mat2str(v, 6); end
end
