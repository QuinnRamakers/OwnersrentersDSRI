function [Vt0, node] = welfare_anchor(p, V0, b)
%WELFARE_ANCHOR  V_tilde at the buffered initial state, b years of income.
%
%   Vt0          = utility.welfare_anchor(p, V0)        % b = 0 (old corner)
%   Vt0          = utility.welfare_anchor(p, V0, b)     % b scalar or vector
%   [Vt0, node]  = utility.welfare_anchor(p, V0, b)
%
%   V0 is the t=1 value slice sol.V(:,:,:,1), sized N_lambda x N_sA x N_sH.
%
%   A household starting with a liquid buffer of b years of income owns
%   H_0 = h_mult * Y_0 of housing and no DC balance, so total initial wealth
%   and its normalized state coordinates are
%       W0   = (b + h_mult + 1) * Y0
%       lam0 = 1        / (b + h_mult + 1)
%       sX0  = b        / (b + h_mult + 1)
%       sH0  = h_mult   / (b + h_mult + 1)
%       sA0  = 0
%   (lam0 + sX0 + sH0 = 1 with sA0 = 0; sX0 is implied by the simplex and is
%   not an interpolation coordinate, it is returned in `node` for reporting.)
%   b = 0 is the ZERO-buffer corner -- the convention every welfare0.Vt0
%   written before 2026-08 used. The calibrated anchors are p.b0 and p.b_alt
%   (config.params), which config.insert_anchor_nodes puts on the grid as
%   exact nodes so the value read there is solved rather than interpolated.
%
%   This is the single implementation of the interpolate-V-at-a-node step
%   that used to be copy-pasted inline in run_combined, run_nodc,
%   run_spline_strategies, welfare_dc_vs_nodc, plot_welfare_vs_buffer and
%   both comparison scripts. NaN handling is unchanged from those copies:
%   infeasible-state NaNs are filled with the nearest finite node value
%   before a 'linear'/'nearest' griddedInterpolant is built, because the
%   initial state sits exactly on the feasibility boundary and plain linear
%   interpolation would otherwise pick up a NaN corner.
%
%   b may be a vector; the interpolant (and its NaN fill, which is the
%   expensive part) is then built ONCE and queried at every buffer. Vt0 comes
%   back with the same shape as b.

if nargin < 3 || isempty(b), b = 0; end
assert(isnumeric(b) && isreal(b) && all(b(:) >= 0), 'welfare_anchor:b', ...
    'b must be real, non-negative (years of income).');
assert(all(isfield(p, {'lambda_grid', 'sA_grid', 'sH_grid', 'h_mult'})), ...
    'welfare_anchor:params', 'p needs lambda_grid/sA_grid/sH_grid/h_mult.');

sz_want = [numel(p.lambda_grid), numel(p.sA_grid), numel(p.sH_grid)];
sz_got  = [size(V0, 1), size(V0, 2), size(V0, 3)];
assert(isequal(sz_got, sz_want), 'welfare_anchor:size', ...
    ['V0 is %dx%dx%d but the grids in p are %dx%dx%d -- p and the solution ' ...
     'come from different vintages.'], sz_got, sz_want);

F = griddedInterpolant({p.lambda_grid, p.sA_grid, p.sH_grid}, ...
                       fill_nan_nearest_3d(V0), 'linear', 'nearest');

den  = b(:) + p.h_mult + 1;
lam0 = 1        ./ den;
sX0  = b(:)     ./ den;
sH0  = p.h_mult ./ den;
sA0  = zeros(size(den));

Vt0 = reshape(F(lam0, sA0, sH0), size(b));

if nargout > 1
    node = struct('b', b(:).', 'lam0', lam0.', 'sA0', sA0.', ...
                  'sX0', sX0.', 'sH0', sH0.', 'W0_over_Y0', den.');
end
end

%% =======================================================================
function Z = fill_nan_nearest_3d(M)
% Replace infeasible-state NaNs with the nearest finite value. Byte-for-byte
% the helper that used to be duplicated in run_combined / run_nodc /
% run_spline_strategies / welfare_dc_strategies / both comparison scripts --
% do not "improve" it, the welfare numbers depend on this exact behaviour.
Z = M;
if ~any(isnan(Z(:))), return; end
[NL, NA, NH] = size(Z);
mask_ok = ~isnan(Z);
[Ig, Jg, Kg] = ndgrid(1:NL, 1:NA, 1:NH);
I_ok = Ig(mask_ok); J_ok = Jg(mask_ok); K_ok = Kg(mask_ok); V_ok = Z(mask_ok);
I_bad = Ig(~mask_ok); J_bad = Jg(~mask_ok); K_bad = Kg(~mask_ok);
for k = 1:numel(I_bad)
    di = I_bad(k) - I_ok; dj = J_bad(k) - J_ok; dk = K_bad(k) - K_ok;
    d2 = di.*di + dj.*dj + dk.*dk;
    [~, q] = min(d2);
    Z(I_bad(k), J_bad(k), K_bad(k)) = V_ok(q);
end
end
