function strats = menu(levels, monotone_only)
%MENU  The production collection of spline glide-path strategies.
%
%   strats = strategy.menu()                    % default collection
%   strats = strategy.menu([0 .5 1])            % coarser fraction grid
%   strats = strategy.menu(0:0.125:1, false)    % allow non-monotone paths
%
%   Each strategy is a pension equity glide path pinned at four knot ages:
%     age0                     (25)  entry
%     (age0 + retirement)/2    (46)  mid working life
%     retirement_age           (67)  retirement
%     age0 + T - 2             (99)  final transition age
%   with the equity fraction free at each knot on the grid `levels` (default
%   0:0.125:1). With monotone_only = true only non-increasing paths are kept --
%   classic derisking glide paths -- giving C(9+4-1, 4) = 495 strategies.
%
%   The list is deterministic, so slicing it assigns strategies to parallel
%   cluster instances:
%     M = strategy.menu();
%     run_spline_strategies(M(1:100));     % instance A
%     run_spline_strategies(M(101:end));   % instance B

if nargin < 1 || isempty(levels), levels = 0:0.125:1; end
if nargin < 2, monotone_only = true;  end

p = config.params();
knot_ages = [p.age0, round((p.age0 + p.retirement_age)/2), ...
             p.retirement_age, p.age0 + p.T - 2];
strats = strategy.make_grid(p, knot_ages, levels, monotone_only);
end
