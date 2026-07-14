function strats = menu(levels, monotone_only)
%MENU  The current production spline-strategy collection.
%
%   strats = strategy.menu()                    % default: 35 strategies
%   strats = strategy.menu([0 .5 1])            % coarser: 10 strategies
%   strats = strategy.menu(0:0.25:1, false)     % non-monotone too: 125
%
%   Three knots, fractions free at each, on a grid:
%     age0            (20)  -- initial level
%     retirement_age  (65)  -- retirement level
%     age0 + T - 2    (99)  -- end-of-life level (last transition age; the
%                              terminal age 100 has no transition, so 99 is
%                              where the final knot can live)
%   Default levels 0:0.25:1, monotone (non-increasing) only ->
%   C(5+3-1, 3) = 35 strategies.
%
%   Slice the returned array to assign strategies to a cluster instance:
%     M = strategy.menu();
%     run_spline_strategies(M(1:18));      % instance A
%     run_spline_strategies(M(19:end));    % instance B

if nargin < 1, levels = [];           end
if nargin < 2, monotone_only = true;  end

p = config.params();
knot_ages = [p.age0, p.retirement_age, p.age0 + p.T - 2];
strats = strategy.make_grid(p, knot_ages, levels, monotone_only);
end
