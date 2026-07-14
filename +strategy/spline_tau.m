function tau_S = spline_tau(p, knot_ages, knot_fracs)
%SPLINE_TAU  Build a tau_S glide path from (age, equity-fraction) knots.
%
%   tau_S = strategy.spline_tau(p, knot_ages, knot_fracs)
%
%   Fits a shape-preserving piecewise-cubic Hermite interpolant (PCHIP,
%   Fritsch-Carlson) through the knots and evaluates it at every transition
%   age (age0 .. age0+T-2), giving the length T-1 vector the solver and
%   simulator expect in p.tau_S.
%
%   PCHIP is monotone BETWEEN each pair of knots (no overshoot), so the
%   path never leaves [min(knot_fracs), max(knot_fracs)] and a monotone
%   knot sequence yields a globally monotone glide path. Outside the
%   outermost knots the path is held FLAT at the first/last knot value.
%
%   knot_ages  : strictly increasing, inside [age0, age0+T-2]
%   knot_fracs : equity fractions in [0, 1], same length (>= 2 knots;
%                the production family uses 4)

knot_ages  = knot_ages(:);
knot_fracs = knot_fracs(:);

assert(numel(knot_ages) == numel(knot_fracs) && numel(knot_ages) >= 2, ...
    'strategy:spline_tau', 'need >= 2 knots, ages and fracs same length');
assert(all(diff(knot_ages) > 0), ...
    'strategy:spline_tau', 'knot ages must be strictly increasing');
assert(all(knot_fracs >= 0 & knot_fracs <= 1), ...
    'strategy:spline_tau', 'knot fractions must lie in [0, 1]');
assert(knot_ages(1) >= p.age0 && knot_ages(end) <= p.age0 + p.T - 2, ...
    'strategy:spline_tau', 'knot ages must lie in [age0, age0+T-2]');

ages = (p.age0 : p.age0 + p.T - 2).';          % transition ages, length T-1

% Clamp query ages to the knot span -> flat extrapolation at end values.
ages_q = min(max(ages, knot_ages(1)), knot_ages(end));
tau_S  = interp1(knot_ages, knot_fracs, ages_q, 'pchip');

% PCHIP stays within the knot range, so this is belt-and-braces only.
tau_S = min(max(tau_S, 0), 1);
end
