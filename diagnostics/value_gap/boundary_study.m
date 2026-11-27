function T = boundary_study(owner, opts)
%BOUNDARY_STUDY  Step 24 solved with each p.default_boundary mode, and its gap.
%
%   T = boundary_study(false)                                        % renters, tiny grid
%   T = boundary_study(true, grid=[16 16 10 8], gh_n=5, N=20000, modes={'off','extend'})
%
%   For each mode: ladder step 24 (production, default as a choice) on the
%   grid, solved by model.run; the solver's value at entry (ce_entry) and
%   simulated welfare under the simulator's rule ('grid') and the boundary
%   rule (compare_rules: the default decision solved at the state where the
%   cell's corners disagree), with the share ever defaulting and the worst
%   1%'s share of utility; the solve time and model.checks; and the shape of
%   the default boundary along u2 (boundary_lines). Saves the table (no
%   solution) to opts.out if given.

arguments
    owner (1,1) logical
    opts.grid (1,4) double = [8 6 6 4]
    opts.gh_n (1,1) double = 3
    opts.N (1,1) double = 4000
    opts.seed (1,1) double = 303
    opts.modes = {'off', 'cont', 'extend'}
    opts.rules = {'grid', 'boundary'}
    opts.out char = ''
end
rows = {};
for mode = string(opts.modes)
    p = ladder.params(24); p.is_owner = owner; p.grid_dims = opts.grid; p.gh_n = opts.gh_n;
    p.default_boundary = char(mode);
    p = config.derive(p);
    fprintf('\n=== step 24, owner %d, grid %s, gh_n %d, default_boundary %s ===\n', owner, mat2str(opts.grid), opts.gh_n, mode);
    t0 = tic;
    r = model.run(p, N_sim=2000, verbose=false);
    t_solve = r.timing.solve_sec;
    model.print_checks(r);
    ck = r.checks;
    B = boundary_lines(r);
    C = compare_rules(r, N=opts.N, seed=opts.seed, rules=string(opts.rules));
    for i = 1:height(C)
        rows(end + 1, :) = {char(mode), C.rule{i}, C.ce_entry(i), C.ce_sim(i), C.se(i), C.gap_pct(i), ...
            C.ever_default(i), C.worst1_share(i), t_solve, C.sec(i), ck.c_bound_25_39, sum(ck.offgrid), ...
            sum(B.T.more_than_one), sum(B.T.default_to_cont)}; %#ok<AGROW>
    end
    fprintf('mode %s done in %.0f s\n', mode, toc(t0));
    clear r
end
T = cell2table(rows, 'VariableNames', {'mode', 'rule', 'ce_entry', 'ce_sim', 'se', 'gap_pct', ...
    'ever_default', 'worst1_share', 'solve_sec', 'sim_sec', 'c_bound_25_39', 'offgrid', ...
    'lines_multi', 'lines_reverse'});
disp(T);
if ~isempty(opts.out), save(opts.out, 'T'); end
end
