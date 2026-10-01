function k = index(step, S)
%INDEX  Step number from a number or a name.
if nargin < 2, S = ladder.steps(); end
names = {S.name};
assert(numel(unique(names)) == numel(names), 'ladder:duplicate_name', ...
    'Step names must be unique.');
if ischar(step) || isstring(step)
    k = find(strcmp(names, char(step)), 1);
    assert(~isempty(k), 'ladder:unknown_step', 'No step named %s. Steps: %s.', ...
        char(step), strjoin(names, ', '));
else
    k = step;
    assert(isscalar(k) && k == round(k) && k >= 1 && k <= numel(S), ...
        'ladder:step_range', 'Step must be 1..%d.', numel(S));
end
end
