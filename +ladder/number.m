function s = number(k, S, pad)
%NUMBER  The number a ladder step shows in titles, tables and file names.
%
%   s = ladder.number(k)            % k a position in the ladder: '7', '7b', '12'
%   s = ladder.number(k, S)
%   s = ladder.number(k, S, true)   % with a leading zero for file names: '07', '07b', '12'
%
%   The number is the step's num field (ladder.steps), or its position when a
%   ladder has none. ladder.index goes the other way.
if nargin < 2 || isempty(S), S = ladder.steps(); end
if nargin < 3, pad = false; end
if isfield(S, 'num') && ~isempty(S(k).num), s = S(k).num; else, s = sprintf('%d', k); end
if pad && numel(regexp(s, '^\d+', 'match', 'once')) == 1, s = ['0' s]; end
end
