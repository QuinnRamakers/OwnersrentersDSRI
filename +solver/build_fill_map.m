function map = build_fill_map(lambda_grid, sA_grid, sH_grid)
%BUILD_FILL_MAP  Nearest-feasible source index for every infeasible cube node.
%
%   The state grid is the full cube (lambda x s_A x s_H) but only the simplex
%   lambda + s_A + s_H <= 1 is ever solved. The continuation interpolant in
%   solver.bellman_step is nevertheless built on the whole cube, so every
%   infeasible node needs SOME value: a query inside a cell that touches the
%   sX = 0 face blends feasible corners with infeasible ones.
%
%   The original fill put the GLOBAL MINIMUM feasible z at every infeasible
%   node. That minimum is numerically the z-image of the -1e15 ruin
%   assignment (~1e-4, against ~0.02-0.07 at face-adjacent nodes), so every
%   legitimate face-adjacent query was blended with ruin -- an artificial
%   penalty one cell wide along the whole sX = 0 face, at every age. Negative
%   liquid wealth is unreachable in this model (gross exp() return factors at
%   every GH node, pi bounded to [0,1] in both the seed grid and the fmincon
%   bounds, c <= 1-1e-6, and states whose committed outgoings exceed resources
%   already get V = -1e15 explicitly BEFORE interpolation), so that fill had
%   no protective function -- it was pure distortion. See the assert in
%   bellman_step, which fails loudly if leverage, additive returns, post-return
%   cost deduction or a mortgage stock ever make sX < 0 reachable.
%
%   The fix is a nearest-feasible fill: project the infeasible node radially
%   onto the simplex face (divide the coordinate vector by its sum, which is
%   > 1 by construction) and take the z of the nearest FEASIBLE grid node to
%   that projection, Euclidean in (lambda, s_A, s_H).
%
%   The map depends only on the grid, so it is built ONCE per solve
%   (solver.solve_lifecycle stores it on p.fill_map) and each Bellman step is
%   then a single gather. Brute-force vectorised in chunks: at 52^3 that is
%   ~116k infeasible x ~25k feasible distance evaluations, fine as a one-off,
%   and deliberately toolbox-free (no knnsearch -- Statistics Toolbox is not a
%   dependency of this project).
%
%   Returns a struct with fields:
%       dims       : [NL NA NH] the map was built for (validity check)
%       infeas_lin : uint32 linear indices of the infeasible cube nodes
%       src_lin    : uint32 linear index of the nearest feasible node, aligned
%                    element-wise with infeas_lin

lambda_grid = lambda_grid(:); sA_grid = sA_grid(:); sH_grid = sH_grid(:);
NL = numel(lambda_grid); NA = numel(sA_grid); NH = numel(sH_grid);

[Lam, SA, SH] = ndgrid(lambda_grid, sA_grid, sH_grid);
feas = (Lam + SA + SH) <= 1 + 1e-12;      % same tolerance as bellman_step

map = struct('dims', [NL NA NH], 'infeas_lin', uint32([]), 'src_lin', uint32([]));

infeas_lin = find(~feas);
feas_lin   = find(feas);
if isempty(infeas_lin)
    return
end
if isempty(feas_lin)
    error('build_fill_map:no_feasible', ...
          'No feasible nodes on the %dx%dx%d grid.', NL, NA, NH);
end

% Radial projection onto the simplex face. The sum is > 1 on every infeasible
% node, so the division is always well defined.
s  = Lam(infeas_lin) + SA(infeas_lin) + SH(infeas_lin);
Pl = Lam(infeas_lin) ./ s;
Pa = SA(infeas_lin)  ./ s;
Ph = SH(infeas_lin)  ./ s;

Fl = Lam(feas_lin).'; Fa = SA(feas_lin).'; Fh = SH(feas_lin).';   % 1 x n_feas

n_inf  = numel(infeas_lin);
n_feas = numel(feas_lin);
src    = zeros(n_inf, 1);

% Chunk so the distance block stays around 2e7 doubles (~160 MB).
chunk = max(1, floor(2e7 / n_feas));
for i0 = 1:chunk:n_inf
    i1 = min(i0 + chunk - 1, n_inf);
    d2 = (Pl(i0:i1) - Fl).^2 + (Pa(i0:i1) - Fa).^2 + (Ph(i0:i1) - Fh).^2;
    [~, q] = min(d2, [], 2);
    src(i0:i1) = feas_lin(q);
end

map.infeas_lin = uint32(infeas_lin);
map.src_lin    = uint32(src);
end
