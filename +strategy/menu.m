function strats = menu(levels, monotone_only)
%MENU  The current production spline-strategy collection.
%
%   strats = strategy.menu()                    % default: 165 strategies
%   strats = strategy.menu([0 .5 1])            % coarser: 10 strategies
%   strats = strategy.menu(0:0.25:1)            % old default: 35 strategies
%   strats = strategy.menu(0:0.125:1, false)    % non-monotone too: 495
%
%   Three knots, fractions free at each, on a grid:
%     age0            (25)  -- initial level
%     retirement_age  (67)  -- retirement level
%     age0 + T - 2    (99)  -- end-of-life level (last transition age; the
%                              terminal age 100 has no transition, so 99 is
%                              where the final knot can live)
%   Default levels 0:0.125:1 (9 levels), monotone (non-increasing) only ->
%   C(9+3-1, 3) = 165 strategies. Sized to fill ~12h on one cluster
%   instance at housing="both": 165 strategies x 2 housings = 330 jobs,
%   observed cluster speed ~1.8-2 min/job (see spline_strategies_log.txt)
%   -> ~660 min = ~11h. Widened 2026-07-14 from the old 0:0.25:1 (35
%   strategies, ~140 min at this speed) specifically to make good use of a
%   12h cluster window; re-widen further (e.g. 0:0.1:1 -> 286 strategies,
%   ~19h) if 11h leaves too much headroom.
%
%   Slice the returned array to assign strategies to a cluster instance:
%     M = strategy.menu();
%     run_spline_strategies(M(1:18));      % instance A
%     run_spline_strategies(M(19:end));    % instance B

if nargin < 1 || isempty(levels), levels = 0:0.125:1; end
if nargin < 2, monotone_only = true;  end

p = config.params();
knot_ages = [p.age0, p.retirement_age, p.age0 + p.T - 2];
strats = strategy.make_grid(p, knot_ages, levels, monotone_only);
end
