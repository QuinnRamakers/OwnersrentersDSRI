function [p, k, S] = params(step, S)
%PARAMS  The calibration at one step of the ladder.
%
%   p = ladder.params(k)          % k = step number (1 = CGM core)
%   p = ladder.params('housing')  % or step name
%   p = ladder.params(k, S)       % a ladder other than ladder.steps()
%   [p, k, S] = ladder.params(...)
%
%   Starts from the production primitives, applies the overrides of steps
%   1..k in order, and derives. An override naming a field that is not a
%   primitive of config.params is an error, so a misspelt parameter cannot
%   pass silently. p.ladder carries the step's index, name and label.

if nargin < 2 || isempty(S), S = ladder.steps(); end
k = ladder.index(step, S);
p = config.params(false);
for j = 1:k
    f = fieldnames(S(j).set);
    for i = 1:numel(f)
        assert(isfield(p, f{i}), 'ladder:unknown_field', ...
            'Step %d (%s) sets %s, which is not a primitive of config.params.', ...
            j, S(j).name, f{i});
        p.(f{i}) = S(j).set.(f{i});
    end
end
p = config.derive(p);
p.ladder = struct('index', k, 'name', S(k).name, 'label', S(k).label, 'note', S(k).note);
end
