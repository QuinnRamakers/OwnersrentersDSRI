function out = load(step, numerics)
%LOAD  Saved results of one ladder step, one field per tenure.
%
%   out = ladder.load(k)                     % standard numerics
%   out = ladder.load('housing', 'quick')
%
%   Returns a struct with fields nohousing, or renter and owner. Errors if the
%   step has not been run at these numerics, and warns if the saved run is for
%   a calibration that no longer matches the step.

if nargin < 2 || isempty(numerics), numerics = 'standard'; end
S   = ladder.steps();
num = ladder.numerics(numerics);
[p, k] = ladder.params(step);
p.grid_dims = num.dims; p.gh_n = num.gh_n;
out = struct();
for tenure = {'nohousing', 'renter', 'owner'}
    file = ladder.result_file(num, k, S(k).name, tenure{1});
    if isfile(file)
        out.(tenure{1}) = builtin('load', file);
        q = p; q.is_owner = strcmp(tenure{1}, 'owner');
        if ~ladder.same_calibration(out.(tenure{1}).p, q)
            warning('ladder:stale', ['%s was solved for a different calibration than ' ...
                'step %d now specifies; re-run ladder.run(%d).'], file, k, k);
        end
    end
end
assert(~isempty(fieldnames(out)), 'ladder:not_run', ...
    'Step %d (%s) has no saved results in %s; run ladder.run(%d, numerics=''%s'') first.', ...
    k, S(k).name, num.dir, k, numerics);
end
