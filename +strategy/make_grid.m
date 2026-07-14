function strats = make_grid(p, knot_ages, levels, monotone_only)
%MAKE_GRID  Generate a spline-strategy collection on a fraction grid.
%
%   strats = strategy.make_grid(p, knot_ages, levels, monotone_only)
%
%   Fully variable: any number of knot AGES (strictly increasing, within
%   [p.age0, p.age0+p.T-2]); knot FRACTIONS take every combination of
%   `levels` at those ages. With monotone_only = true (default) only
%   non-increasing sequences are kept (classic derisking glide paths).
%
%   Returns a struct array with fields:
%     .name       'spl_100_050_000' (fractions in percent, one per knot)
%     .knot_ages  1 x n_knots
%     .knot_fracs 1 x n_knots
%
%   Ordering is deterministic (sorted descending by fraction rows), so the
%   same call gives the same list on every machine -- slice it however you
%   like when assigning strategies to cluster instances.
%
%   See strategy.menu for the current production collection.

if nargin < 3 || isempty(levels),  levels = 0:0.25:1;   end
if nargin < 4,                     monotone_only = true; end
levels = unique(levels(:).');
assert(all(levels >= 0 & levels <= 1), 'strategy:make_grid', 'levels must lie in [0,1]');
nk = numel(knot_ages);
assert(nk >= 2 && all(diff(knot_ages) > 0), 'strategy:make_grid', ...
    'knot_ages must be >= 2 strictly increasing ages');

grids_in  = repmat({levels}, 1, nk);
grids_out = cell(1, nk);
[grids_out{:}] = ndgrid(grids_in{:});
combos = cell2mat(cellfun(@(g) g(:), grids_out, 'UniformOutput', false));
if monotone_only
    combos = combos(all(diff(combos, 1, 2) <= 1e-12, 2), :);
end
combos = sortrows(combos, 'descend');   % deterministic order everywhere

n = size(combos, 1);
strats = struct('name', cell(n,1), 'knot_ages', cell(n,1), 'knot_fracs', cell(n,1));
for k = 1:n
    f = combos(k, :);
    strats(k).name       = ['spl_' strjoin(compose('%03d', round(100*f)), '_')];
    strats(k).knot_ages  = knot_ages(:).';
    strats(k).knot_fracs = f;
end
end
