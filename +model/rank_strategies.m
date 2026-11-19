function R = rank_strategies(folders, opts)
%RANK_STRATEGIES  Rank every strategy solve saved in one or more folders.
%
%   R = model.rank_strategies(folder)
%   R = model.rank_strategies(["night_medium_extra", "night_medium"])   % several folders together
%   R = model.rank_strategies(folder, reference="lifecycle", write=false)
%
%   Reads every <name>_<tenure>.mat that model.strategies saved in the
%   folders (a name relative to <output_dir>/strategies, or a full path),
%   and ranks the strategies. Nothing is solved. Each file carries its
%   strategy (name, label, set), its tenure, its calibration and its checks,
%   so the ranking needs no list.
%
%   The files must be comparable: every file must have the reference's
%   calibration apart from the fields its own strategy and the reference's
%   set (the numerics included, so solves on different grids are refused). A
%   strategy name may appear once per tenure; a copy of the same solve in
%   another folder (same calibration and value at entry) counts once.
%   Anything else is an error that names the file.
%
%   Welfare is certainty-equivalent consumption at entry (checks.ce_entry, in
%   multiples of entry income), and a strategy's gain is ce / ce_ref - 1 for
%   the same tenure. For strategies that change only the fund this is
%   (V / V_ref)^(1/(1-gamma)) - 1. The table is sorted by the lowest gain
%   across the tenures, the paper's max-min rule; a strategy not solved for
%   every tenure has no lowest gain and goes last.
%
%   Options
%     reference  the strategy the gains are measured against; by default the
%                one whose set is empty (production). "best" measures each
%                tenure against its own best strategy, so every gain is at
%                most 0 (R.reference then names them)
%     write      true (default) writes ranking.md in the first folder
%     title      the heading of ranking.md (default: the folder names)
%     exclude    names of strategies to leave out (e.g. ["free", "no_dc"]), so
%                that "best" is the best of the rest
%
%   R.table   one row per strategy, best first: rank, strategy, label, the
%             gain by tenure (%), the lowest gain (%), solve minutes by tenure
%   R.arms    one per file: name, tenure, file, ce_entry, solve_sec, sim_sec,
%             N_sim, checks
%   R.reference, R.maxmin, R.tenures, R.folders, R.lines (the report)

arguments
    folders {mustBeText}
    opts.reference (1,:) char = ''
    opts.write (1,1) logical = true
    opts.title (1,:) char = ''
    opts.exclude string = strings(1, 0)
end

folders = cellstr(string(folders));
for i = 1:numel(folders)
    if ~isfolder(folders{i})
        folders{i} = fullfile(utility.output_dir(), 'strategies', folders{i});
    end
    assert(isfolder(folders{i}), 'rank_strategies:folder', 'No folder %s.', folders{i});
end

% Read every file.
arms = struct('name', {}, 'label', {}, 'set', {}, 'tenure', {}, 'file', {}, 'p', {}, ...
              'ce_entry', {}, 'solve_sec', {}, 'sim_sec', {}, 'N_sim', {}, 'checks', {});
for i = 1:numel(folders)
    F = dir(fullfile(folders{i}, '*.mat'));
    for f = F.'
        file = fullfile(f.folder, f.name);
        w = whos('-file', file);
        if ~all(ismember({'strategy', 'tenure', 'p', 'checks', 'timing'}, {w.name}))
            continue                                 % not a model.strategies solve
        end
        L = load(file, 'strategy', 'tenure', 'p', 'checks', 'timing');
        a = struct('name', L.strategy.name, 'label', L.strategy.label, 'set', L.strategy.set, ...
                   'tenure', char(L.tenure), 'file', file, 'p', L.p, 'ce_entry', L.checks.ce_entry, ...
                   'solve_sec', L.timing.solve_sec, 'sim_sec', L.timing.sim_sec, ...
                   'N_sim', L.timing.N_sim, 'checks', L.checks);
        if isempty(a.set), a.set = struct(); end
        dup = find(strcmp({arms.name}, a.name) & strcmp({arms.tenure}, a.tenure), 1);
        if ~isempty(dup)
            % A copy of the same solve in another folder (same calibration,
            % same value at entry) counts once; anything else is an error.
            same = ~strcmp(arms(dup).file, file) && arms(dup).ce_entry == a.ce_entry && ...
                   ladder.same_calibration(arms(dup).p, a.p);
            assert(same, 'rank_strategies:duplicate', '%s %s is saved twice: %s and %s.', ...
                a.name, a.tenure, arms(dup).file, file);
            continue
        end
        arms(end+1) = a; %#ok<AGROW>
    end
end
arms = arms(~ismember({arms.name}, cellstr(opts.exclude)));
assert(~isempty(arms), 'rank_strategies:empty', 'No strategy solves in %s.', strjoin(folders, ', '));

% The reference. "best" measures each tenure against its best strategy; the
% calibration is then checked against the strategy with an empty set.
names = unique({arms.name}, 'stable');
ref = opts.reference;
best = strcmp(ref, 'best');
if best, ref = ''; end
if isempty(ref)
    plain = unique({arms(arrayfun(@(a) isempty(fieldnames(a.set)), arms)).name});
    assert(numel(plain) == 1, 'rank_strategies:reference', ...
        'Name the reference: %d strategies have an empty set (%s).', numel(plain), strjoin(plain, ', '));
    ref = plain{1};
end
assert(any(strcmp(ref, names)), 'rank_strategies:reference', 'The reference %s is not in the folders.', ref);
tenures = intersect(["renter", "owner"], string({arms.tenure}), 'stable');

% Every file has the reference's calibration but for the two strategies' sets.
for i = 1:numel(arms)
    r = arms(strcmp({arms.name}, ref) & strcmp({arms.tenure}, arms(i).tenure));
    assert(~isempty(r), 'rank_strategies:no_reference', 'The reference %s has no %s solve.', ref, arms(i).tenure);
    q = arms(i).p;
    f = union(fieldnames(arms(i).set), fieldnames(r.set));
    for k = 1:numel(f)
        if isfield(r.p, f{k}), q.(f{k}) = r.p.(f{k}); elseif isfield(q, f{k}), q = rmfield(q, f{k}); end
    end
    assert(ladder.same_calibration(q, r.p), 'rank_strategies:calibration', ...
        ['%s differs from the reference %s in more than the strategies'' settings ' ...
         '(another calibration or grid); rank it in a folder of its own.'], arms(i).file, r.file);
end

% Gains and the table.
nS = numel(names); nT = numel(tenures);
ce = nan(nS, nT); sec = nan(nS, nT);
for i = 1:numel(arms)
    s = strcmp(names, arms(i).name); t = tenures == arms(i).tenure;
    ce(s, t) = arms(i).ce_entry; sec(s, t) = arms(i).solve_sec;
end
if best
    [ce_ref, ib] = max(ce, [], 1, 'omitnan');
    ref = sprintf('best (%s)', strjoin(compose('%s %s', string(names(ib)).', tenures.'), ', '));
else
    ce_ref = ce(strcmp(names, ref), :);
end
gain = 100 * (ce ./ ce_ref - 1);
low = min(gain, [], 2);
low(any(isnan(gain), 2)) = NaN;
labels = cellfun(@(n) arms(find(strcmp({arms.name}, n), 1)).label, names, 'UniformOutput', false);
T = table(names(:), labels(:), 'VariableNames', {'strategy', 'label'});
for j = 1:nT, T.("gain_" + tenures(j)) = gain(:, j); end
T.lowest_gain = low;
for j = 1:nT, T.("solve_min_" + tenures(j)) = sec(:, j) / 60; end
key = low; key(isnan(key)) = -inf;
[~, order] = sortrows([key, mean(gain, 2, 'omitnan')], [-1 -2]);
T = T(order, :);
T = addvars(T, (1:height(T)).', 'Before', 1, 'NewVariableNames', 'rank');
maxmin = '';
if ~isnan(T.lowest_gain(1)), maxmin = T.strategy{1}; end

R = struct('table', T, 'arms', rmfield(arms, {'p', 'set'}), 'reference', ref, 'maxmin', maxmin, ...
           'tenures', tenures, 'folders', {folders}, 'lines', {{}});
R.lines = report(R, arms, opts.title);
if opts.write
    fid = fopen(fullfile(folders{1}, 'ranking.md'), 'w');
    fprintf(fid, '%s\n', R.lines{:});
    fclose(fid);
end
end

% ------------------------------------------------------------------------
function L = report(R, arms, title)
T = R.table; ten = R.tenures; p0 = arms(1).p;
if isempty(title)
    [~, nm] = cellfun(@fileparts, R.folders, 'UniformOutput', false);
    title = strjoin(nm, ', ');
end
L = {sprintf('# DC fund strategies, ranked (%s)', title), '', ...
     sprintf(['%d solves from %s. Base nodes %s on (u1, u2, u3, q), %d quadrature nodes a shock. ' ...
              'Gains are in certainty-equivalent consumption at entry, in percent, against `%s`, ' ...
              'by tenure. Ranked by the lowest gain across the tenures (max-min). Ranked %s.'], ...
             numel(arms), strjoin(R.folders, ', '), mat2str(p0.grid_dims), p0.gh_n, R.reference, now_utc()), ...
     '', '## Ranking', ''};
head = '| Rank | Strategy |'; rule = '|---:|---|';
for j = 1:numel(ten), head = [head sprintf(' %s gain (%%) |', ten(j))]; rule = [rule '---:|']; end %#ok<AGROW>
head = [head ' Lowest gain (%) |']; rule = [rule '---:|'];
for j = 1:numel(ten), head = [head sprintf(' %s solve (min) |', ten(j))]; rule = [rule '---:|']; end %#ok<AGROW>
L = [L, {head, rule}];
for k = 1:height(T)
    row = sprintf('| %d | %s (`%s`) |', T.rank(k), T.label{k}, T.strategy{k});
    for j = 1:numel(ten), row = [row sprintf(' %s |', num(T.("gain_" + ten(j))(k), '%+.3f'))]; end %#ok<AGROW>
    row = [row sprintf(' %s |', num(T.lowest_gain(k), '%+.3f'))]; %#ok<AGROW>
    for j = 1:numel(ten), row = [row sprintf(' %s |', num(T.("solve_min_" + ten(j))(k), '%.1f'))]; end %#ok<AGROW>
    L{end+1} = row; %#ok<AGROW>
end
if ~isempty(R.maxmin)
    L = [L, {'', sprintf('Max-min choice: `%s`.', R.maxmin)}];
end
L = [L, {'', sprintf('Solve time of the %d solves: %.1f min.', numel(arms), sum([arms.solve_sec]) / 60), ...
     '', '## Checks', '', ...
     '| Strategy | Tenure | Solve (min) | Panel (min) | ce_entry | c_bound_25_39 | Off-grid lookups | Bankrupt household-years (%) | Bankrupt at 67 and 100 (%) |', ...
     '|---|---|---:|---:|---:|---:|---:|---:|---:|'}];
for k = 1:height(T)
    for j = 1:numel(ten)
        i = find(strcmp({arms.name}, T.strategy{k}) & strcmp({arms.tenure}, ten(j)));
        if isempty(i), continue, end
        a = arms(i); c = a.checks;
        L{end+1} = sprintf('| `%s` | %s | %.1f | %.1f | %.4f | %.4f | %d | %.2f | %.2f, %.2f |', a.name, a.tenure, ...
            a.solve_sec / 60, a.sim_sec / 60, c.ce_entry, c.c_bound_25_39, sum(c.offgrid), ...
            100 * c.floored_share, 100 * c.abs_share(2), 100 * c.abs_share(3)); %#ok<AGROW>
    end
end
end

function s = num(x, fmt)
if isnan(x), s = ''; else, s = sprintf(fmt, x); end
end

function s = now_utc()
s = [char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd HH:mm')) ' UTC'];
end
