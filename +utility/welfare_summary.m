function w = welfare_summary(p, V0)
%WELFARE_SUMMARY  The `welfare0` struct saved alongside every simplex run.
%
%   welfare0 = utility.welfare_summary(p, sol.V(:,:,:,1))
%
%   Saved top-level in the .mat so comparison scripts can matfile-read the
%   welfare metric without loading the big sol/sim arrays. Homotheticity gives
%   V(W, state) = W^(1-gamma) * V_tilde(state), so runs that start from the
%   same initial state are ranked exactly by V_tilde there -- no Monte Carlo
%   noise (see welfare_dc_strategies.m).
%
%   Fields:
%     Vt0        V_tilde at the ZERO-buffer corner (b = 0). Unchanged legacy
%                convention -- every pre-2026-08 file's Vt0 means this, so
%                rankings that fall back to it stay comparable with them.
%     Vt0_b0     V_tilde at the CALIBRATED buffer p.b0     <- paper number
%     Vt0_b_alt  V_tilde at the sensitivity buffer p.b_alt <- paper number
%     b0, b_alt  the buffer values actually used (years of income)
%     b_grid     sensitivity sweep [0 0.25 0.5 1 2 3 5 10] (years of income)
%     Vt0_grid   V_tilde at each b_grid point, same length
%     lam0/sA0/sH0   corner state coordinates (legacy fields, b = 0)
%     gamma      CRRA coefficient, so a CEV can be formed without loading p
%
%   b_grid exists so downstream scripts never have to reload the multi-GB sol
%   just to draw a sensitivity curve. plot_welfare_vs_buffer still does, for
%   its finer 41-point version.
%
%   All values come from utility.welfare_anchor, which builds the NaN-filled
%   interpolant once and queries every buffer off it.

B_SENS = [0 0.25 0.5 1 2 3 5 10];

if isfield(p, 'b0'),    b0    = p.b0;    else, b0    = NaN; end
if isfield(p, 'b_alt'), b_alt = p.b_alt; else, b_alt = NaN; end

% One interpolant build for all of them: corner, both calibrated anchors,
% then the sensitivity grid. NaN anchors (a p-struct predating b0/b_alt)
% would poison the interpolant query, so they are skipped and reported NaN.
b_named = [0, b0, b_alt];
ok      = ~isnan(b_named);
b_all   = [b_named(ok), B_SENS];
V_all   = utility.welfare_anchor(p, V0, b_all);

V_named      = nan(1, 3);
V_named(ok)  = V_all(1:nnz(ok));

w = struct( ...
    'Vt0',       V_named(1), ...
    'Vt0_b0',    V_named(2), ...
    'Vt0_b_alt', V_named(3), ...
    'b0',        b0, ...
    'b_alt',     b_alt, ...
    'b_grid',    B_SENS, ...
    'Vt0_grid',  V_all(nnz(ok)+1 : end), ...
    'lam0',      1 / (1 + p.h_mult), ...
    'sA0',       0, ...
    'sH0',       p.h_mult / (1 + p.h_mult), ...
    'gamma',     p.gamma);
end
