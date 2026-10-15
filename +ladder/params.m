function [p, k, S] = params(step, S)
%PARAMS  The calibration at one step of the ladder.
%
%   p = ladder.params(8)          % the step numbered 8 (1 = CGM core)
%   p = ladder.params('7b')       % a number with a letter
%   p = ladder.params('housing')  % or step name
%   p = ladder.params(step, S)    % a ladder other than ladder.steps()
%   [p, k, S] = ladder.params(...)   % k is the step's position in S
%
%   Starts from the production primitives, applies the overrides of the steps
%   from step 1 to this one along its line of parents (ladder.parent), in
%   order, and derives. Steps on another branch are not applied. An override
%   naming a field that is not a primitive of config.params is an error, so a
%   misspelt parameter cannot pass silently. p.ladder carries the step's
%   position (index), number, name, label and the positions applied.

if nargin < 2 || isempty(S), S = ladder.steps(); end
k = ladder.index(step, S);
line = k;
while line(1) > 1
    line = [ladder.parent(S(line(1)).name, S), line]; %#ok<AGROW>
end
p = config.params(false);
for j = line
    f = fieldnames(S(j).set);
    for i = 1:numel(f)
        assert(isfield(p, f{i}), 'ladder:unknown_field', ...
            'Step %s (%s) sets %s, which is not a primitive of config.params.', ...
            ladder.number(j, S), S(j).name, f{i});
        p.(f{i}) = S(j).set.(f{i});
    end
end
p = config.derive(p);
p.ladder = struct('index', k, 'number', ladder.number(k, S), 'name', S(k).name, ...
                  'label', S(k).label, 'note', S(k).note, 'line', line);
end
