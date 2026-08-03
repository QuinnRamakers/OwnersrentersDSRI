function [s, arm] = param_fingerprint(p)
%PARAM_FINGERPRINT  Grid + calibration identity of a solved run.
%
%   s        = utility.param_fingerprint(p)
%   [s, arm] = utility.param_fingerprint(p)
%
%   Two files are welfare-comparable IFF their fingerprint strings match:
%   V_tilde values solved on different grids, different calibrations or
%   different solver fills are not on the same scale, and ranking them
%   together produces CEVs that look plausible and are garbage (this has
%   already happened once -- stale pre-calibration-overhaul spl_* files
%   ranked against a fresh benchmark yielded a nonsense +792% "pension
%   value", see the gate in compare_spline_strategies).
%
%   The single copy. It used to live inline in both compare_spline_strategies
%   and compare_strategy_vs_nopension, and the two drifted: neither picked up
%   tau_wealth, b0/b_alt or legacy_fill when those were added.
%
%   ARM fields (kappa, choose_tau_S) are deliberately EXCLUDED from s and
%   returned separately in `arm`. They are what the comparison is ABOUT, not
%   a threat to it:
%     kappa        the no-pension benchmark is kappa = 0 by design.
%     choose_tau_S the free-DC benchmark is choose_tau_S = true by design.
%   Both arms are solved from the same p on the same grid, so their V_tilde
%   values live on the same scale and belong in one ranking -- gating on them
%   would fence the two benchmarks out of the very table that has to contain
%   them. Callers check them separately (all swept strategy files must agree;
%   the benchmarks may differ).
%
%   Comparability fields, and why each one breaks it:
%     N_lambda/N_sA/N_sH/gh_n         different state or quadrature grid
%     age0/T/retirement_age           different lifecycle length
%     gamma/beta/chi                  different preferences (gamma also sets
%                                     the CEV exponent)
%     alpha/theta/h_mult/r_m          different housing cost block
%     r/mu_*_level/sigma_*_level      different return process
%     replacement/sigma_l_log         different income / first pillar
%     tau_inc/tau_cg_bond/tau_cg_stock/tau_wealth
%                                     different tax block. tau_wealth (0.0197,
%                                     added on the freetau branch) shifts the
%                                     liquid account's after-tax return, so a
%                                     pre-tau_wealth file is a different model.
%     b0/b_alt                        different welfare anchors => different
%                                     inserted nodes => different grid => the
%                                     welfare node itself moves
%     legacy_fill                     the pre-fix phantom-penalty continuation
%                                     fill. A file solved with it carries a
%                                     ruin-blended penalty along the sX = 0
%                                     face, which is exactly where the welfare
%                                     anchor sits.
%
%   Absent fields fingerprint as NaN, which is a distinct string from any
%   numeric value, so an older vintage never silently matches a newer one.
%   That is what fences PRE-FIX files off from POST-FIX ones: they have no
%   legacy_fill field at all -> "legacy_fill=NaN", while the run scripts now
%   stamp p.legacy_fill = false -> "legacy_fill=0". Note the second half of
%   that sentence is load-bearing: if the runners stopped stamping the field,
%   both vintages would read NaN and the fence would silently open.

FLDS = {'N_lambda','N_sA','N_sH','gh_n','age0','T','retirement_age', ...
        'gamma','beta','chi','alpha','theta','h_mult','r','mu_S_level', ...
        'sigma_S_level','mu_H_level','sigma_H_level','r_m','replacement', ...
        'sigma_l_log','tau_inc','tau_cg_bond','tau_cg_stock','tau_wealth', ...
        'b0','b_alt','legacy_fill'};

parts = cell(1, numel(FLDS));
for i = 1:numel(FLDS)
    parts{i} = sprintf('%s=%.6g', FLDS{i}, field_or_nan(p, FLDS{i}));
end
s = strjoin(parts, ' ');

if nargout > 1
    arm = struct('kappa',        field_or_nan(p, 'kappa'), ...
                 'choose_tau_S', field_or_nan(p, 'choose_tau_S'));
    arm.str = sprintf('kappa=%.6g choose_tau_S=%.6g', arm.kappa, arm.choose_tau_S);
end
end

function v = field_or_nan(p, f)
% Scalar-or-NaN. Non-scalar values (a p that stored a vector under one of
% these names) would corrupt the string silently, so they are collapsed to
% NaN rather than partially printed.
v = NaN;
if isfield(p, f)
    x = p.(f);
    if isnumeric(x) || islogical(x)
        if isscalar(x), v = double(x); end
    end
end
end
