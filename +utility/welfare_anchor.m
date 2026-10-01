function [Vt0, node] = welfare_anchor(p, V0, b)
%WELFARE_ANCHOR  V_tilde at the entry state, for a liquid buffer of b years of income.
%
%   Vt0         = utility.welfare_anchor(p, V0)        % b = p.b0
%   Vt0         = utility.welfare_anchor(p, V0, b)     % b scalar or vector
%   [Vt0, node] = utility.welfare_anchor(p, V0, b)
%
%   V0 is the age-25 slice sol.V(:,:,:,1). A household entering with liquid
%   wealth b*Y0, housing or rent index h_mult*Y0 and no DC pot has
%   W0 = (1 + h_mult + b) Y0 and sits at
%       u1 = 1/(1 + h_mult + b),   u2 = h_mult/(h_mult + b),   u3 = 0.
%   V(W0, u) = W0^(1-gamma) * V_tilde(u), so V_tilde ranks two solutions of the
%   same model from the same entry state. config.insert_anchor_nodes makes the
%   states for p.b0 and p.b_alt exact grid nodes; any other b is interpolated.

if nargin < 3 || isempty(b), b = p.b0; end
assert(isnumeric(b) && isreal(b) && all(b(:) >= 0), 'welfare_anchor:b', ...
    'b must be real and non-negative (years of income).');
sz_want = [numel(p.u1_grid), numel(p.u2_grid), numel(p.u3_grid)];
sz_got  = [size(V0, 1), size(V0, 2), size(V0, 3)];
assert(isequal(sz_got, sz_want), 'welfare_anchor:size', ...
    'V0 is %dx%dx%d but the grids in p are %dx%dx%d.', sz_got, sz_want);

F   = griddedInterpolant({p.u1_grid, p.u2_grid, p.u3_grid}, V0, 'linear', 'nearest');
den = 1 + p.h_mult + b(:);          % same order as insert_anchor_nodes, so the node is hit exactly
u1  = 1 ./ den;
u2  = p.h_mult ./ max(p.h_mult + b(:), realmin);   % 0/0 without housing or buffer: no illiquid wealth
u3  = zeros(size(den));
Vt0 = reshape(F(u1, u2, u3), size(b));
if nargout > 1
    node = struct('b', b(:).', 'u1', u1.', 'u2', u2.', 'u3', u3.', 'W0_over_Y0', den.');
end
end
