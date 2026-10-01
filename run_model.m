function R = run_model(p, opts)
%RUN_MODEL  Solve and simulate one calibration, every tenure it has.
%
%   run_model                          % the production calibration, renter and owner
%   run_model(p)                       % any derived p: config.params, ladder.params, ...
%   run_model(p, tag='floor010')       % suffix for the output files
%   R = run_model(...)                 % R.renter and R.owner, or R.nohousing
%
%   Writes <output_dir>/results_<tenure>[_<tag>].mat with a dashboard PNG
%   beside it (figures.dashboard). The output directory is CGM_OUTPUT_DIR, or
%   the current folder. To take the calibration through a sequence of changes,
%   use the ladder instead (README.md).
%
%   Options: N_sim (10000), seed (20260511), tag (''), keep_sim (false).

arguments
    p (1,1) struct = config.params()
    opts.N_sim (1,1) double = 10000
    opts.seed (1,1) double = 20260511
    opts.tag (1,:) char = ''
    opts.keep_sim (1,1) logical = false
end

[dims, gh] = utility.grid_override(p.grid_dims, p.gh_n);
if ~isequal(dims, p.grid_dims) || gh ~= p.gh_n
    p.grid_dims = dims; p.gh_n = gh;
    p = config.derive(p);
    fprintf('Grid set by the environment: %s, gh_n %d.\n', mat2str(dims), gh);
end

arms = {false};
if p.h_mult > 0, arms = {false, true}; end
R = struct();
for a = 1:numel(arms)
    pa = p; pa.is_owner = arms{a};
    r = model.run(pa, N_sim = opts.N_sim, seed = opts.seed, keep_sim = opts.keep_sim);
    name = ['results_' r.tenure];
    if ~isempty(opts.tag), name = [name '_' opts.tag]; end
    file = fullfile(utility.output_dir(), [name '.mat']);
    if opts.keep_sim
        save(file, '-struct', 'r', '-v7.3');
    else
        save(file, '-struct', 'r');
    end
    figures.dashboard(r, strrep(file, '.mat', '.png'));
    fprintf('Saved %s\n', file);
    R.(r.tenure) = r;
end
end
