function T = report(numerics)
%REPORT  One row per saved ladder arm: the main outputs and the checks.
%
%   ladder.report()            % standard numerics
%   T = ladder.report('quick') % also return the table
%
%   Levels are in multiples of entry income Y0. C25 and C45 are medians;
%   NW66 is mean net worth at 66; pi and equity are means of the liquid equity
%   share and of the equity share of financial wealth. ce_entry is the constant
%   consumption, in multiples of Y0, worth the value at entry (model.checks).

if nargin < 1 || isempty(numerics), numerics = 'standard'; end
S   = ladder.steps();
num = ladder.numerics(numerics);
rows = {};
for k = 1:numel(S)
    for tenure = {'nohousing', 'renter', 'owner'}
        file = ladder.result_file(num, k, S(k).name, tenure{1});
        if ~isfile(file), continue; end
        r = builtin('load', file, 'summary', 'checks', 'p', 'timing');
        s = r.summary; c = r.checks; a = s.ages; at = @(v, age) v(a == age);
        q = ladder.params(k); q.grid_dims = num.dims; q.gh_n = num.gh_n;
        q.is_owner = strcmp(tenure{1}, 'owner');
        rows(end+1, :) = {k, S(k).name, tenure{1}, ...
            at(s.C.p50, 25) / s.Y0, at(s.C.p50, 45) / s.Y0, at(s.C.p50, 75) / s.Y0, ...
            at(s.net_worth.mean, 66) / s.Y0, at(s.pi, 30), at(s.pi, 45), at(s.pi, 80), ...
            at(s.equity_share, 45), 100 * c.floored_share, 100 * c.c_bound_25_39, ...
            c.ce_entry, 100 * c.burden_25, sum(c.offgrid), 100 * c.thin_u1_40, ...
            r.timing.solve_sec, ~ladder.same_calibration(r.p, q)}; %#ok<AGROW>
    end
end
names = {'step', 'name', 'tenure', 'C25', 'C45', 'C75', 'NW66', 'pi30', 'pi45', 'pi80', ...
         'equity45', 'floored_pct', 'cbound_pct', 'ce_entry', 'burden25_pct', 'offgrid', ...
         'thin_u1_pct', 'solve_sec', 'stale'};
if isempty(rows)
    fprintf('No ladder results in %s.\n', num.dir);
    T = cell2table(cell(0, numel(names)), 'VariableNames', names);
    return
end
T = cell2table(rows, 'VariableNames', names);
fprintf('\nLadder results in %s\n', num.dir);
disp(T);
end
