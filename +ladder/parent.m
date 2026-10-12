function j = parent(step, S)
%PARENT  The step a ladder step builds on.
%
%   j = ladder.parent(k)        % 0 for step 1
%   j = ladder.parent('aow')
%   j = ladder.parent(k, S)
%
%   A step's parent is the step named in its parent field, or the step before
%   it when that field is empty. A parent must come earlier in the ladder.

if nargin < 2 || isempty(S), S = ladder.steps(); end
k = ladder.index(step, S);
if k == 1
    j = 0;
elseif ~isfield(S, 'parent') || isempty(S(k).parent)
    j = k - 1;
else
    j = ladder.index(S(k).parent, S);
    assert(j < k, 'ladder:parent_order', ...
        'Step %d (%s) builds on %s, which does not come before it.', k, S(k).name, S(k).parent);
end
end
