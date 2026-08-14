function [s, arm] = param_fingerprint(p)
%PARAM_FINGERPRINT  Grid + calibration identity of a solved run.
%
%   s        = utility.param_fingerprint(p)
%   [s, arm] = utility.param_fingerprint(p)
%
%   Two files are welfare-comparable only if their fingerprint strings match.
%   V_tilde values solved on different grids, calibrations or solver fills are
%   not on the same scale, and ranking them together produces CEVs that look
%   plausible and are meaningless -- which has happened once already, when
%   stale pre-calibration files ranked against a fresh benchmark returned a
%   +792% "pension value".
%
%   The string covers the grid dimensions and every calibrated parameter:
%   state and quadrature grid, lifecycle length, preferences, housing costs,
%   return and rent processes, income and first pillar, mortgage and
%   bequest-sale block, taxes, welfare anchors, and the decumulation share.
%   kappa_base and franchise are included because they define the kappa_t
%   profile; run_nodc overrides p.kappa to 0 and leaves both untouched, so this
%   is safe even though kappa itself is an arm field.
%
%   is_owner is in the list because tenure selects which growth process the H
%   state follows (config.h_process), not just the carrying-cost rate, so owner
%   and renter files are solved against different stochastics and were never
%   welfare-comparable to begin with.
%
%   ARM fields (kappa, choose_tau_S) are deliberately excluded and returned
%   separately, because they are what the comparison is about: the no-pension
%   benchmark is kappa = 0 by design and the free-DC benchmark is
%   choose_tau_S = true by design. Both are solved from the same p on the same
%   grid, so gating on them would fence the benchmarks out of the very table
%   that has to contain them. Callers check them separately -- swept strategy
%   files must agree, the benchmarks may differ. arm.kappa is a scalar summary
%   because p.kappa is an age profile; see kappa_summary below.
%
%   Absent fields fingerprint as NaN, a distinct string from any numeric
%   value, so an older vintage never silently matches a newer one. That is
%   what separates pre-fix files from post-fix ones: pre-fix files have no
%   legacy_fill field ("legacy_fill=NaN") while the runners stamp
%   p.legacy_fill = false ("legacy_fill=0"). If the runners ever stopped
%   stamping it, both vintages would read NaN and the fence would open.
%
%   tau_decum is the exception: empty (the all-bond default) is non-scalar and
%   so also fingerprints as NaN, matching a vintage that never had the field.
%   That is intended -- [] reproduces the old behaviour exactly, so the two
%   really are the same model.

FLDS = {'N_lambda','N_sA','N_sH','gh_n','age0','T','retirement_age', ...
        'gamma','beta','chi','alpha','theta','h_mult','r','mu_S_level', ...
        'sigma_S_level','mu_H_level','sigma_H_level','mu_R_level','sigma_R_level', ...
        'is_owner','r_m','N_mort','LTV', ...
        'sell_cost','replacement','delta','sigma_l_log','income_price_factor', ...
        'sex','kappa_base','franchise','tau_inc','tau_cg_bond','tau_cg_stock', ...
        'tau_wealth','b0','b_alt','legacy_fill','tau_decum','phi_floor', ...
        'N_u1','N_u2','N_u3','polish_ver','N_c','N_pi'};

parts = cell(1, numel(FLDS));
for i = 1:numel(FLDS)
    parts{i} = sprintf('%s=%.6g', FLDS{i}, field_or_nan(p, FLDS{i}));
end
s = sprintf('%s grid=%s', strjoin(parts, ' '), grid_tag(p));

if nargout > 1
    arm = struct('kappa',        kappa_summary(p), ...
                 'choose_tau_S', field_or_nan(p, 'choose_tau_S'));
    arm.str = sprintf('kappa=%.6g choose_tau_S=%.6g', arm.kappa, arm.choose_tau_S);
end
end

function g = grid_tag(p)
%GRID_TAG  Which coordinate system the run was solved on.
%
%   The simplex (lambda, s_A, s_H) and the LNA cube (u1, u2, u3) are different
%   discretisations of the same model, and a p-struct carries BOTH sets of grid
%   vectors, so nothing else in p tells them apart. Without this tag a simplex
%   file and an LNA file fingerprint identically and would pass the
%   comparability gate against each other.
%
%   Callers declare it as p.grid_type. config.params defaults it to 'simplex';
%   solver.solve_lifecycle_lna asserts it is 'lna',
%   so a cube solve that forgot to declare itself fails rather than being
%   silently labelled a simplex run. A p-struct predating the tag reads
%   'unset', which matches neither.
g = 'unset';
if isfield(p, 'grid_type') && (ischar(p.grid_type) || isstring(p.grid_type))
    g = char(p.grid_type);
end
end

function k = kappa_summary(p)
%KAPPA_SUMMARY  Scalar stand-in for a kappa that may be an age profile.
%   Callers use arm.kappa only to tell the DC-on arms from the kappa = 0
%   benchmark, and to check that one sweep does not mix contribution regimes.
%   So they need a scalar that is 0 exactly when the DC pillar is off, and the
%   peak working-life rate is that.
%
%   It cannot separate two different profiles sharing a peak, but it does not
%   need to: the profile is pinned by kappa_base, franchise and the income
%   profile, and the first two are in the comparability gate above.
%
%   Returns NaN for a p with no kappa at all, matching field_or_nan.
if ~isfield(p, 'kappa') || isempty(p.kappa) || ~isnumeric(p.kappa)
    k = NaN; return
end
if isfield(p, 'T') && isfield(p, 't_ret')
    k = max(config.kappa_path(p));
else
    k = max(p.kappa(:));      % legacy p-struct: no T/t_ret to expand against
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
