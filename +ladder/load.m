function out = load(step, numerics)
%LOAD  Saved results of one ladder step, one field per tenure.
%
%   out = ladder.load(8)                     % standard numerics
%   out = ladder.load('housing', 'quick')    % or '7b', or a name
%
%   Returns a struct with one field per arm (model.tenure): nohousing,
%   nohousing_renter and nohousing_owner, or renter and owner. Errors if the
%   step has not been run at these numerics, and warns if the saved run is for
%   a calibration that no longer matches the step.

if nargin < 2 || isempty(numerics), numerics = 'standard'; end
S   = ladder.steps();
num = ladder.numerics(numerics);
[p, k] = ladder.params(step);
p.grid_dims = num.dims; p.gh_n = num.gh_n;
out = struct();
for tenure = {'nohousing', 'nohousing_renter', 'nohousing_owner', 'renter', 'owner'}
    file = ladder.result_file(num, k, S(k).name, tenure{1});
    if isfile(file)
        out.(tenure{1}) = builtin('load', file);
        q = p; q.is_owner = endsWith(tenure{1}, 'owner');
        if ~ladder.same_calibration(out.(tenure{1}).p, q)
            warning('ladder:stale', ['%s was solved for a different calibration than ' ...
                'step %s now specifies; re-run ladder.run(''%s'').'], file, ...
                ladder.number(k, S), S(k).name);
        end
    end
end
assert(~isempty(fieldnames(out)), 'ladder:not_run', ...
    'Step %s (%s) has no saved results in %s; run ladder.run(''%s'', numerics=''%s'') first.', ...
    ladder.number(k, S), S(k).name, num.dir, S(k).name, numerics);
end
