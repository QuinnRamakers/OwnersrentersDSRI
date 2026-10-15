function k = index(step, S)
%INDEX  Position of a step in the ladder, from its number or its name.
%
%   k = ladder.index(8)           % the step numbered 8
%   k = ladder.index('7b')        % a number with a letter, as text
%   k = ladder.index('housing')   % or its name
%
%   Numbers are the ones shown in titles, tables and file names
%   (ladder.number), not positions: step 7b sits at position 8, and the step
%   numbered 8 at position 9. Positions index S.
if nargin < 2 || isempty(S), S = ladder.steps(); end
names = {S.name};
nums  = arrayfun(@(j) ladder.number(j, S), 1:numel(S), 'UniformOutput', false);
assert(numel(unique(names)) == numel(names), 'ladder:duplicate_name', ...
    'Step names must be unique.');
assert(numel(unique(nums)) == numel(nums), 'ladder:duplicate_number', ...
    'Step numbers must be unique.');
list = strjoin(strcat(nums, {' '}, names), ', ');
if ischar(step) || isstring(step)
    k = find(strcmp(names, char(step)), 1);
    if isempty(k), k = find(strcmp(nums, char(step)), 1); end
    assert(~isempty(k), 'ladder:unknown_step', 'No step named or numbered %s. Steps: %s.', ...
        char(step), list);
else
    assert(isscalar(step) && step == round(step), 'ladder:step_range', ...
        'A step number must be a whole number, or text such as ''7b''.');
    k = find(strcmp(nums, sprintf('%d', step)), 1);
    assert(~isempty(k), 'ladder:step_range', 'No step numbered %d. Steps: %s.', step, list);
end
end
