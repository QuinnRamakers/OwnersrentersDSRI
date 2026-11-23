function d = describe_strategy(strategy)
%DESCRIBE_STRATEGY  What a strategy's fund holds, in words.
%
%   d = figures.describe_strategy(s)    % s: a strategy struct (name, label, set)
%
%   For a glide_rule 'knots' fund: the risky share at each knot and the REIT
%   part of the risky share, e.g. "risky 100% at 25 -> 70% at 46 -> 30% at 67
%   -> 30% at 100; risky part 50% REIT, 50% stocks". Otherwise the label.

d = strategy.label;
s = strategy.set;
if isempty(s) || ~isstruct(s) || ~isfield(s, 'glide_knots') || isempty(s.glide_knots), return, end
K = s.glide_knots; risky = K(:, 2) + K(:, 3);
pts = strjoin(compose('%.0f%% at %d', 100 * risky, K(:, 1)), ' -> ');
f = K(:, 3) ./ max(risky, eps); f = f(risky > 0);
mix = 'no risky part';
if ~isempty(f)
    if max(f) - min(f) < 1e-9
        mix = sprintf('risky part %.0f%% REIT, %.0f%% stocks', 100 * f(1), 100 * (1 - f(1)));
    else
        mix = 'REIT part of risky varies by age';
    end
end
d = sprintf('risky %s; %s', pts, mix);
end
