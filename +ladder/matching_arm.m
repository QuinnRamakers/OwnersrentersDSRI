function tp = matching_arm(t, prev)
%MATCHING_ARM  The arm of another step's results to set against arm t.
%
%   tp = ladder.matching_arm('nohousing_owner', ladder.load(6))
%
%   The same label, then the same tenure with or without housing, then the
%   single no-housing arm, then the first arm.

side = erase(t, 'nohousing_');
for c = {t, ['nohousing_' side], side, 'nohousing'}
    if isfield(prev, c{1}), tp = c{1}; return; end
end
tp = fieldnames(prev); tp = tp{1};
end
