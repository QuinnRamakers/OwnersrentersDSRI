function R = strategies(S, opts)
%STRATEGIES  Solve a set of DC fund strategies for each tenure and compare them.
%
%   R = model.strategies(S)                       % S from model.strategy_list, or your own
%   R = model.strategies(S, tag="night", grid_dims=[24 12 20 4], gh_n=3)
%   R = model.strategies(S, tag="night", solve=false)    % the table from the saved solves
%
%   S is a struct array with fields name, label and set (overrides of
%   primitives of config.params; model.strategy_list). Each strategy is
%   solved and simulated for each tenure with model.run, on the base
%   calibration (opts.base, production by default) with the strategy's
%   overrides, and saved to <out>/<name>_<tenure>.mat: p, summary, checks,
%   timing (with the solve time by age) and the value at entry; with
%   keep_sol also the solution. A saved solve of the same calibration and
%   numerics is reused, not solved again.
%
%   Options
%     tag        names the run; the folder is <output_dir>/strategies/<tag>
%     out        the folder itself, instead of tag
%     base       primitives to start from (config.params(false))
%     tenures    ["renter" "owner"]
%     grid_dims, gh_n   numerics for every solve; empty keeps the base's
%     N_sim, seed       the panel (10,000 households, seed 20260511)
%     reference  name of the strategy the gains are measured against (the first)
%     solve      false: no solving, the comparison from what is saved
%     deadline   a datetime; no solve starts that is expected to end after
%                it, by the longest solve of that tenure so far in this folder
%     keep_sol   true saves the value function and policies too (large)
%
%   Welfare is certainty-equivalent consumption at entry: with CRRA utility
%   the value at the entry state is W0^(1-gamma) V, and all strategies of a
%   tenure start from the same state, so a strategy's gain over the reference
%   is (V / V_ref)^(1/(1-gamma)) - 1. The paper's planner takes the strategy
%   whose lowest gain over the tenures is highest (max-min); R.maxmin names it
%   among the strategies solved for every tenure.
%
%   Returns R with fields: table (one row per strategy: the gain by tenure in
%   percent, the lowest of them, the solve minutes by tenure), arms (name,
%   tenure, file, V_entry, ce_entry, solve_sec, sim_sec, reused, status,
%   checks), reference, maxmin, total_sec, out. Prints the table and the
%   checks of every solve and writes them to <out>/comparison.md.

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
ref = opts.reference;
if isempty(ref), ref = names{1}; end
assert(any(strcmp(ref, names)), 'strategies:reference', 'the reference %s is not in the list.', ref);
out = opts.out;
if isempty(out), out = fullfile(utility.output_dir(), 'strategies', opts.tag); end
if ~isfolder(out), mkdir(out); end

t_all = tic;
nS = numel(S); nT = numel(opts.tenures);
arms = struct('name', {}, 'tenure', {}, 'file', {}, 'V_entry', {}, 'ce_entry', {}, 'solve_sec', {}, ...
              'sim_sec', {}, 'reused', {}, 'status', {}, 'checks', {});
longest = zeros(1, nT);                              % longest solve so far, by tenure
fprintf('=== strategies: %d strategies x %d tenures, folder %s, %s\n', nS, nT, out, now_utc());
for k = 1:nS
    for j = 1:nT
        ten = char(opts.tenures(j));
        a = struct('name', names{k}, 'tenure', ten, 'file', fullfile(out, sprintf('%s_%s.mat', names{k}, ten)), ...
                   'V_entry', NaN, 'ce_entry', NaN, 'solve_sec', NaN, 'sim_sec', NaN, 'reused', false, ...
                   'status', 'missing', 'checks', struct());
        try
            p = arm_params(opts.base, S(k), ten, opts.grid_dims, opts.gh_n);
            saved = [];
            if isfile(a.file)
                L = load(a.file, 'p', 'checks', 'timing', 'V_entry');
                if same_run(L.p, p), saved = L; end
            end
            if ~isempty(saved)
                a.reused = true; a.status = 'saved';
            elseif ~opts.solve
                a.status = 'not solved';
            elseif ~isempty(opts.deadline) && longest(j) > 0 && ...
                    datetime('now', 'TimeZone', 'UTC') + seconds(1.2 * longest(j)) > opts.deadline
                a.status = 'skipped (deadline)';
                fprintf('=== skipped %s %s: about %.0f min would run past %s\n', names{k}, ten, ...
                    1.2 * longest(j) / 60, char(opts.deadline));
            else
                fprintf('=== solving %s %s, %s\n', names{k}, ten, now_utc());
                r = model.run(p, N_sim = opts.N_sim, seed = opts.seed, verbose = false);
                saved = struct('p', r.p, 'checks', r.checks, 'timing', r.timing, 'V_entry', r.checks.V_entry);
                saved.timing.period_sec = r.sol.timing.period_sec;
                out_s = saved; out_s.summary = r.summary; out_s.strategy = S(k); out_s.tenure = ten;
                if opts.keep_sol, out_s.sol = r.sol; out_s.ann_price = r.ann_price; end
                save(a.file, '-struct', 'out_s', '-v7.3');
                a.status = 'solved';
                fprintf('=== solved %s %s in %.1f min (panel %.1f min)\n', names{k}, ten, ...
                    r.timing.solve_sec / 60, r.timing.sim_sec / 60);
                model.print_checks(r);
            end
            if ~isempty(saved)
                a.V_entry = saved.V_entry; a.ce_entry = saved.checks.ce_entry;
                a.solve_sec = saved.timing.solve_sec; a.sim_sec = saved.timing.sim_sec;
                a.checks = saved.checks;
                longest(j) = max(longest(j), a.solve_sec);
            end
        catch err
            a.status = ['FAILED: ' err.message];
            fprintf('=== FAILED %s %s: %s\n', names{k}, ten, err.message);
        end
        arms(end+1) = a; %#ok<AGROW>
    end
end

% Gains over the reference, by tenure, in certainty-equivalent consumption.
g = opts.base.gamma;
V = reshape([arms.V_entry], nT, nS).';               % strategies x tenures
sec = reshape([arms.solve_sec], nT, nS).';
gain = 100 * ((V ./ V(strcmp(names, ref), :)) .^ (1 / (1 - g)) - 1);
low = min(gain, [], 2);                              % NaN-free only where every tenure is solved
low(any(isnan(gain), 2)) = NaN;
T = table(names(:), {S.label}.', 'VariableNames', {'strategy', 'label'});
for j = 1:nT
    T.("gain_" + opts.tenures(j)) = gain(:, j);
end
T.lowest_gain = low;
for j = 1:nT
    T.("solve_min_" + opts.tenures(j)) = sec(:, j) / 60;
end
maxmin = '';
if any(~isnan(low))
    [~, i] = max(low);
    maxmin = names{i};
end

R = struct('table', T, 'arms', arms, 'reference', ref, 'maxmin', maxmin, 'total_sec', toc(t_all), 'out', out);
lines = report(R, S, opts, nT);
fprintf('%s\n', lines{:});
fid = fopen(fullfile(out, 'comparison.md'), 'w');
fprintf(fid, '%s\n', lines{:});
fclose(fid);
fprintf('=== strategies done in %.1f min, %s\n', R.total_sec / 60, now_utc());
end

% ------------------------------------------------------------------------
function p = arm_params(base, s, tenure, grid_dims, gh_n)
% The base primitives with the strategy's overrides, the tenure and the run's
% numerics, derived. An override must name a primitive.
p = rmfield_if(base, 'ladder');
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

function p = rmfield_if(p, f)
if isfield(p, f), p = rmfield(p, f); end
end

function tf = same_run(p1, p2)
% The same calibration (every primitive, the numerics among them) and tenure.
tf = ladder.same_calibration(p1, p2);
end

function s = now_utc()
s = char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd HH:mm:ss'));
s = [s ' UTC'];
end

function L = report(R, S, opts, nT)
T = R.table; arms = R.arms;
p0 = opts.base;
gd = opts.grid_dims; if isempty(gd), gd = p0.grid_dims; end
gh = opts.gh_n; if isempty(gh), gh = p0.gh_n; end
L = {sprintf('# DC fund strategies: welfare by tenure and runtime (%s)', opts.tag), '', ...
     sprintf(['Base nodes %s on (u1, u2, u3, q), %d quadrature nodes a shock, %d households. Gains are in ' ...
              'certainty-equivalent consumption at entry, in percent, against `%s`. Solved or read %s.'], ...
             mat2str(gd), gh, opts.N_sim, R.reference, now_utc()), '', ...
     '## Welfare', ''};
head = '| Strategy |'; rule = '|---|';
for j = 1:nT
    head = [head sprintf(' %s gain (%%) |', char(opts.tenures(j)))]; rule = [rule '---:|']; %#ok<AGROW>
end
head = [head ' Lowest gain (%) |']; rule = [rule '---:|'];
for j = 1:nT
    head = [head sprintf(' %s solve (min) |', char(opts.tenures(j)))]; rule = [rule '---:|']; %#ok<AGROW>
end
L = [L, {head, rule}];
for k = 1:height(T)
    row = sprintf('| %s (`%s`) |', S(k).label, S(k).name);
    for j = 1:nT, row = [row sprintf(' %s |', num(T.("gain_" + opts.tenures(j))(k), '%+.3f'))]; end %#ok<AGROW>
    row = [row sprintf(' %s |', num(T.lowest_gain(k), '%+.3f'))]; %#ok<AGROW>
    for j = 1:nT, row = [row sprintf(' %s |', num(T.("solve_min_" + opts.tenures(j))(k), '%.1f'))]; end %#ok<AGROW>
    L{end+1} = row; %#ok<AGROW>
end
if ~isempty(R.maxmin)
    L = [L, {'', sprintf('Highest lowest gain (max-min) among the strategies solved for every tenure: `%s`.', R.maxmin)}];
end
solved = ~isnan([arms.solve_sec]);
L = [L, {'', '## Runtime', '', ...
     sprintf('Solve time of the %d solves in the table: %.1f min in all, %.1f min of it solved in this call (the rest read from file); this call took %.1f min.', ...
        nnz(solved), sum([arms(solved).solve_sec]) / 60, ...
        sum([arms(solved & ~[arms.reused]).solve_sec]) / 60, R.total_sec / 60), ...
     '', '## Checks', '', ...
     '| Strategy | Tenure | Status | Solve (min) | Panel (min) | ce_entry | c_bound_25_39 | Off-grid lookups | Bankrupt household-years (%) | Bankrupt at 67 and 100 (%) |', ...
     '|---|---|---|---:|---:|---:|---:|---:|---:|---:|'}];
for i = 1:numel(arms)
    a = arms(i); c = a.checks;
    if isempty(fieldnames(c))
        L{end+1} = sprintf('| `%s` | %s | %s | | | | | | | |', a.name, a.tenure, a.status); %#ok<AGROW>
        continue
    end
    L{end+1} = sprintf('| `%s` | %s | %s | %.1f | %.1f | %.4f | %.4f | %d | %.2f | %.2f, %.2f |', a.name, a.tenure, ...
        a.status, a.solve_sec / 60, a.sim_sec / 60, c.ce_entry, c.c_bound_25_39, sum(c.offgrid), ...
        100 * c.floored_share, 100 * c.abs_share(2), 100 * c.abs_share(3)); %#ok<AGROW>
end
end

function s = num(x, fmt)
if isnan(x), s = ''; else, s = sprintf(fmt, x); end
end
