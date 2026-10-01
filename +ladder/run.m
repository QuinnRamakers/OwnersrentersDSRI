function R = run(steps, opts)
%RUN  Solve and simulate ladder steps at fixed numerics, and save them.
%
%   ladder.run(k)                         % one step: number or name
%   ladder.run(1:9)                       % several, in order
%   ladder.run('all')
%   ladder.run(k, numerics='quick')       % 'quick' | 'standard' (default) | 'fine'
%   ladder.run(k, force=true)             % re-solve even if a current result exists
%   ladder.run(k, keep_sim=true)          % also save the simulated panel
%   R = ladder.run(...)                   % the results, R{i}.<tenure>
%
%   Steps without housing solve one arm ('nohousing'); with housing, a renter
%   and an owner. Each arm is saved to
%       <output_dir>/ladder/<numerics>/NN_<name>_<tenure>.mat
%   with a dashboard figure next to it. A saved arm is reused unless its
%   calibration no longer matches the step -- editing a step re-solves it and
%   every step after it, since the ladder is cumulative.

arguments
    steps
    opts.numerics (1,:) char = 'standard'
    opts.force (1,1) logical = false
    opts.keep_sim (1,1) logical = false
    opts.figures (1,1) logical = true
end

S = ladder.steps();
if ischar(steps) || isstring(steps)
    if strcmp(char(steps), 'all')
        steps = num2cell(1:numel(S));
    else
        steps = {char(steps)};
    end
elseif isnumeric(steps)
    steps = num2cell(steps);
end
num = ladder.numerics(opts.numerics);
if ~isfolder(num.dir), mkdir(num.dir); end

R = cell(numel(steps), 1);
for i = 1:numel(steps)
    [p, k] = ladder.params(steps{i});
    p.grid_dims = num.dims;
    p.gh_n = num.gh_n;
    p = config.derive(p);
    fprintf('\n=== Step %d: %s (%s) ===\n%s\n', k, S(k).name, S(k).label, S(k).note);

    arms = {false};
    if p.h_mult > 0, arms = {false, true}; end
    out = struct();
    for a = 1:numel(arms)
        pa = p; pa.is_owner = arms{a};
        tenure = model.tenure(pa);
        file = ladder.result_file(num, k, S(k).name, tenure);
        if ~opts.force && isfile(file)
            old = load(file, 'p');
            if ladder.same_calibration(old.p, pa)
                fprintf('%s: reusing %s\n', tenure, file);
                out.(tenure) = load(file);
                continue
            end
            fprintf('%s: the saved result is for a different calibration; re-solving.\n', tenure);
        end
        r = model.run(pa, N_sim = num.N_sim, keep_sim = opts.keep_sim);
        r.step = struct('index', k, 'name', S(k).name, 'label', S(k).label, ...
                        'note', S(k).note, 'set', S(k).set);
        r.numerics = num;
        if opts.keep_sim
            save(file, '-struct', 'r', '-v7.3');
        else
            save(file, '-struct', 'r');
        end
        fprintf('%s: saved %s\n', tenure, file);
        if opts.figures
            figures.dashboard(r, strrep(file, '.mat', '.png'));
        end
        out.(tenure) = r;
    end
    R{i} = out;
end
end
