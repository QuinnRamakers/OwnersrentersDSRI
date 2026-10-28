function solve_cases(cases, opts)
%SOLVE_CASES  Solve DC-branch ladder steps on the grid study's numerics.
%
%   solve_cases(["12:owner:pow2_32x32", "9:renter:uniform_64x64"])
%
%   Each case is <step>:<arm>:<numerics name> (case_params). Results are saved
%   as <standard numerics dir>/pension_grid/NN_<step>_<arm>_<name>.mat, with
%   the households and seed of the ladder's standard numerics, and skipped
%   when a result for the same calibration is already there. One line per
%   solve with its time and model.checks.
%
%   solve_cases(..., verbose = true) also prints the clock time when each case
%   starts, the solver's progress lines (every 10th age, with that age's solve
%   time) and the checks, so a log on the pod shows how far a solve is.

arguments
    cases (1,:) string
    opts.force (1,1) logical = false
    opts.verbose (1,1) logical = false
end

num = ladder.numerics('standard');
out = fullfile(num.dir, 'pension_grid');
if ~isfolder(out), mkdir(out); end
S = ladder.steps();
for c = cases
    parts = split(c, ':');
    step = parts(1); if ~isnan(str2double(step)), step = str2double(step); end
    arm = char(parts(2)); name = char(parts(3));
    k = ladder.index(step, S);
    file = fullfile(out, sprintf('%s_%s_%s_%s.mat', ladder.number(k, S, true), S(k).name, arm, name));
    p = case_params(S(k).name, arm, name);
    if ~opts.force && isfile(file)
        old = load(file, 'p');
        if ladder.same_calibration(old.p, p)
            fprintf('%s exists, skipped\n', file);
            continue
        end
    end
    if opts.verbose, fprintf('%s start %s\n', char(datetime('now')), c); end
    r = model.run(p, N_sim = num.N_sim, verbose = opts.verbose);
    k2 = r.checks;
    fprintf('%-6s %-10s %-6s %-22s nodes %3dx%-3d solve %6.0f s  floored %.4f  offgrid %s  entry %.4f  thin_u1 %.2f\n', ...
        ladder.number(k, S), S(k).name, arm, name, p.N_u1, p.N_u2, r.timing.solve_sec, k2.floored_share, ...
        mat2str(k2.offgrid), k2.ce_entry, k2.thin_u1_40);
    save(file, '-struct', 'r');
end
end
