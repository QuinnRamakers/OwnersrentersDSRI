function solve_grids(opts)
%SOLVE_GRIDS  Solve step 7 (owner unless told otherwise) on candidate grids.
%
%   solve_grids()                                   the cases below
%   solve_grids(cases=["logwealth_16x16"], owner=false)
%   solve_grids(step="annuity", cases=..., out=folder)   another ladder step
%
%   Each case is the ladder step (default step 7, 'housing') at standard
%   numerics (gh_n 5, N_sim 10000, 8 base nodes on q), with the (u1, u2) grid
%   set by grid_rule. Saves the result as <out>/<tenure>_<case>.mat with field
%   r, skipping cases already saved.

arguments
    opts.cases (1,:) string = ["logwealth_16x16", "uniform_32x32", "logwealth_32x32", ...
                               "logwealth_64x48", "uniform_64x48"]
    opts.owner (1,1) logical = true
    opts.step (1,:) char = 'housing'
    opts.out (1,:) char = ''
end

repo = fileparts(fileparts(fileparts(mfilename('fullpath'))));
cd(repo);
out = opts.out;
if isempty(out), out = fullfile(repo, 'ladder', 'standard_16x16x10_gh5', 'grid_design'); end
if ~isfolder(out), mkdir(out); end
setenv('CGM_OUTPUT_DIR', ''); setenv('CGM_STATE_GRID', ''); setenv('CGM_GH_N', '');
ten = 'renter'; if opts.owner, ten = 'owner'; end

for c = opts.cases
    file = fullfile(out, sprintf('%s_%s.mat', ten, c));
    if isfile(file), fprintf('%s exists, skipped\n', file); continue; end
    tok = regexp(char(c), '^(\w+?)_(\d+)x(\d+)$', 'tokens', 'once');
    rule = tok{1}; N1 = str2double(tok{2}); N2 = str2double(tok{3});
    p = ladder.params(opts.step); p.is_owner = opts.owner;
    p.grid_dims = [N1 N2 10 8]; p.gh_n = 5;
    p.grid_nodes = grid_rule(rule, N1, N2, p);
    p = config.derive(p);
    r = model.run(p, N_sim = 10000, verbose = false);
    k = r.checks;
    fprintf('%s %s %-18s nodes %3dx%-3dx%-2d solve %5.0f s  floored %.4f  c_bound %.4f  offgrid %d  entry %.4f\n', ...
        opts.step, ten, c, p.N_u1, p.N_u2, p.N_q, r.timing.solve_sec, k.floored_share, k.c_bound_25_39, ...
        sum(k.offgrid), k.ce_entry);
    save(file, 'r');
end
end
