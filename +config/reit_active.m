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
%   shock, and ladder.same_calibration to decide whether the REIT fields matter.
%
%   The REIT bites when its share is nonzero at some age (reit_risky, the
%   REIT's part of the glide; tau_REIT; reit_decum) or when it is correlated
%   with another shock -- a nonzero correlation reshapes the S/H/L draws even at
%   a zero share. The correlation with the H shock is the tenure's
%   (config.h_corr). A p-struct saved before a field existed reads it as 0.

tf = false;

for f = {'reit_risky', 'tau_REIT', 'reit_decum'}
    if isfield(p, f{1}) && ~isempty(p.(f{1})) && any(p.(f{1})(:) ~= 0)
        tf = true;
    end
end
[~, ~, corr_RH] = config.h_corr(p);
for c = [field_or(p, 'corr_RL', 0), field_or(p, 'corr_RS', 0), corr_RH]
    if c ~= 0
        tf = true;
    end
end
end

function v = field_or(p, f, default)
if isfield(p, f) && ~isempty(p.(f)), v = p.(f); else, v = default; end
end
