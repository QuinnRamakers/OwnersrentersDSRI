function tf = reit_active(p)
%REIT_ACTIVE  True when the DC REIT leg can move any outcome.
%
%   The REIT is a fourth shock, and wiring it into the joint quadrature the
%   solver integrates over multiplies the node count by gh_n_reit (see
%   grids.shock_grid). That cost is only worth paying when the REIT can
%   actually change a result, so grids.shock_grid builds the 4-D tensor only
%   when this returns true and otherwise returns the pre-REIT 3-D tensor,
%   reproducing the old model (up to floating-point summation order) at the old
%   cost. The simulators use the same gate to decide whether to draw the fourth
%   shock.
%
%   The REIT bites when its share is nonzero at some age (accumulation or
%   decumulation) or when it is correlated with another shock -- a nonzero
%   correlation reshapes the S/H/L draws even at a zero share.

tf = false;

if isfield(p, 'tau_REIT') && ~isempty(p.tau_REIT) && any(p.tau_REIT(:) ~= 0)
    tf = true;
end
if isfield(p, 'reit_decum') && ~isempty(p.reit_decum) && any(p.reit_decum(:) ~= 0)
    tf = true;
end
for f = {'corr_RL', 'corr_RS', 'corr_RH'}
    if isfield(p, f{1}) && ~isempty(p.(f{1})) && p.(f{1}) ~= 0
        tf = true;
    end
end
end
