function R = strategies(S, opts)
%STRATEGIES  Solve a set of DC fund strategies for each tenure, then rank the folder.
%
%   R = model.strategies(S)                       % S from model.strategy_list, or your own
%   R = model.strategies(S, tag="night", grid_dims=[24 12 20 4], gh_n=3)
%
%   S is a struct array with fields name, label and set (overrides of
%   primitives of config.params; model.strategy_list). Each strategy is
%   solved and simulated for each tenure with model.run, on the base
%   calibration (opts.base, production by default) with the strategy's
%   overrides, and saved to <out>/<name>_<tenure>.mat: the strategy, the
%   tenure, p, summary, checks, timing (with the solve time by age) and the
%   value at entry; with keep_sol also the solution. A saved solve of the
%   same calibration and numerics is reused, not solved again, so a list can
%   grow and a stopped run can be started again.
%
%   Solving and ranking are separate: at the end this calls
%   model.rank_strategies on the folder, which ranks every solve saved there,
%   also those of earlier calls. Rank a folder, or several, at any time with
%   model.rank_strategies alone.
%
%   Options
%     tag        names the run; the folder is <output_dir>/strategies/<tag>
%     out        the folder itself, instead of tag
%     base       primitives to start from (config.params(false))
%     tenures    ["renter" "owner"]
%     grid_dims, gh_n   numerics for every solve; empty keeps the base's
%     N_sim, seed       the panel (10,000 households, seed 20260511)
%     reference  passed to model.rank_strategies
%     solve      false: no solving, only the ranking of what is saved
%     deadline   a datetime; no solve starts that is expected to end after
%                it, by the longest solve of that tenure so far in this call
%     keep_sol   true saves the value function and policies too (large)
%
%   Returns the ranking (model.rank_strategies: table, arms, reference,
%   maxmin, ...; empty fields when the folder holds no solve) plus runs, one
%   per strategy and tenure of this call (name, tenure, file, status: solved,
%   saved, not solved, skipped (deadline) or FAILED: <message>; solve_sec),
%   and total_sec.

arguments
    S (1,:) struct
    opts.tag (1,:) char = 'run'
    opts.out (1,:) char = ''
    opts.base (1,1) struct = config.params(false)
    opts.tenures (1,:) string {mustBeMember(opts.tenures, ["renter", "owner"])} = ["renter", "owner"]
    opts.grid_dims double = []
    opts.gh_n double = []
    opts.N_sim (1,1) double = 10000
    opts.seed (1,1) double = 20260511
    opts.reference (1,:) char = ''
    opts.solve (1,1) logical = true
    opts.deadline = []
    opts.keep_sol (1,1) logical = false
end

assert(all(isfield(S, {'name', 'label', 'set'})), 'strategies:fields', ...
    'S needs the fields name, label and set (model.strategy_list).');
names = {S.name};
assert(numel(unique(names)) == numel(names), 'strategies:names', 'strategy names must be unique.');
out = opts.out;
if isempty(out), out = fullfile(utility.output_dir(), 'strategies', opts.tag); end
if ~isfolder(out), mkdir(out); end

t_all = tic;
nT = numel(opts.tenures);
runs = struct('name', {}, 'tenure', {}, 'file', {}, 'status', {}, 'solve_sec', {});
longest = zeros(1, nT);                              % longest solve so far, by tenure
fprintf('=== strategies: %d strategies x %d tenures, folder %s, %s\n', numel(S), nT, out, now_utc());
for k = 1:numel(S)
    for j = 1:nT
        ten = char(opts.tenures(j));
        a = struct('name', names{k}, 'tenure', ten, 'file', fullfile(out, sprintf('%s_%s.mat', names{k}, ten)), ...
                   'status', 'not solved', 'solve_sec', NaN);
        try
            p = arm_params(opts.base, S(k), ten, opts.grid_dims, opts.gh_n);
            if isfile(a.file)
                L = load(a.file, 'p', 'timing');
                if ladder.same_calibration(L.p, p)
                    a.status = 'saved'; a.solve_sec = L.timing.solve_sec;
                end
            end
            if ~strcmp(a.status, 'saved') && opts.solve
                if ~isempty(opts.deadline) && longest(j) > 0 && ...
                        datetime('now', 'TimeZone', 'UTC') + seconds(1.2 * longest(j)) > opts.deadline
                    a.status = 'skipped (deadline)';
                    fprintf('=== skipped %s %s: about %.0f min would run past %s\n', names{k}, ten, ...
                        1.2 * longest(j) / 60, char(opts.deadline));
                else
                    fprintf('=== solving %s %s, %s\n', names{k}, ten, now_utc());
                    r = model.run(p, N_sim = opts.N_sim, seed = opts.seed, verbose = false);
                    s = struct('strategy', S(k), 'tenure', ten, 'p', r.p, 'summary', r.summary, ...
                               'checks', r.checks, 'timing', r.timing, 'V_entry', r.checks.V_entry);
                    s.timing.period_sec = r.sol.timing.period_sec;
                    if opts.keep_sol, s.sol = r.sol; s.ann_price = r.ann_price; end
                    save(a.file, '-struct', 's', '-v7.3');
                    a.status = 'solved'; a.solve_sec = r.timing.solve_sec;
                    fprintf('=== solved %s %s in %.1f min (panel %.1f min)\n', names{k}, ten, ...
                        r.timing.solve_sec / 60, r.timing.sim_sec / 60);
                    model.print_checks(r);
                end
            end
            if ~isnan(a.solve_sec), longest(j) = max(longest(j), a.solve_sec); end
        catch err
            a.status = ['FAILED: ' err.message];
            fprintf('=== FAILED %s %s: %s\n', names{k}, ten, err.message);
        end
        runs(end+1) = a; %#ok<AGROW>
    end
end

R = struct('table', table(), 'arms', struct([]), 'reference', '', 'maxmin', '', 'tenures', strings(1, 0), ...
           'folders', {{out}}, 'lines', {{}});
try
    R = model.rank_strategies(out, reference = opts.reference);
    fprintf('%s\n', R.lines{:});
catch err
    fprintf('=== no ranking: %s\n', err.message);
end
R.runs = runs;
R.total_sec = toc(t_all);
fprintf('=== strategies done in %.1f min, %s; this call solved %d, reused %d, skipped %d, failed %d\n', ...
    R.total_sec / 60, now_utc(), sum(strcmp({runs.status}, 'solved')), sum(strcmp({runs.status}, 'saved')), ...
    sum(startsWith({runs.status}, 'skipped')), sum(startsWith({runs.status}, 'FAILED')));
end

% ------------------------------------------------------------------------
function p = arm_params(base, s, tenure, grid_dims, gh_n)
% The base primitives with the strategy's overrides, the tenure and the run's
% numerics, derived. An override must name a primitive.
p = base;
if isfield(p, 'ladder'), p = rmfield(p, 'ladder'); end
prim = fieldnames(config.params(false));
if ~isempty(s.set)
    f = fieldnames(s.set);
    for i = 1:numel(f)
        assert(any(strcmp(f{i}, prim)), 'strategies:unknown_field', ...
            'Strategy %s sets %s, which is not a primitive of config.params.', s.name, f{i});
        p.(f{i}) = s.set.(f{i});
    end
end
p.is_owner = strcmp(tenure, 'owner');
if ~isempty(grid_dims), p.grid_dims = grid_dims; end
if ~isempty(gh_n), p.gh_n = gh_n; end
p = config.derive(p);
end

function s = now_utc()
s = [char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd HH:mm:ss')) ' UTC'];
end
