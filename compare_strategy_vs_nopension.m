function compare_strategy_vs_nopension(results_dir)
%COMPARE_STRATEGY_VS_NOPENSION  Sanity-check dashboard: best spline glide
% path vs no DC pension at all (kappa=0), for renter and owner separately.
%
%   compare_strategy_vs_nopension                     % scan utility.output_dir()
%   compare_strategy_vs_nopension('D:\downloads\all')  % scan a combined folder
%
%   For each housing type, finds the best-ranked spl_*_{housing}.mat (by
%   V_tilde0, same ranking as compare_spline_strategies.m) and compares it
%   against combined_{housing}_kappa0.mat (the no-pension benchmark from
%   run_combined.m) on a 12-panel dashboard layout adapted from make_plots.m's
%   renter-vs-owner comparison -- both lines share housing tenure here, only
%   the DC pension differs, so this is a direct visual "does having a
%   pension actually help, and does it look sane" check: pension balance
%   should be strictly zero for the no-pension line, and housing panels
%   should be IDENTICAL between the two lines (H_0 depends on Y_0, not
%   kappa, and housing dynamics don't depend on kappa either -- if they're
%   not identical, something is leaking kappa into housing and that's a
%   bug worth chasing). The welfare comparison itself (panel l) is always
%   reported with NO_PENSION as the fixed reference: a positive number
%   means the best strategy beats no pension, negative means no pension
%   wins -- both are normal, expected possible outcomes, not an error.
%
%   Requires spl_*_{housing}.mat files from run_spline_strategies.m and
%   combined_{housing}_kappa0.mat from run_combined.m to already exist in
%   results_dir -- this does no solving itself.
%
%   Output (written into results_dir):
%     printed CEV summary + sanity-check assertions per housing type
%     fig_strategy_vs_nopension_{renter|owner}.png

arguments
    results_dir {mustBeTextScalar} = ''
end

RES_DIR = char(results_dir);
if isempty(RES_DIR), RES_DIR = utility.output_dir(); end
assert(isfolder(RES_DIR), 'compare_strategy_vs_nopension:nodir', 'Not a folder: %s', RES_DIR);
HOUSING = {'renter', 'owner'};

for hi = 1:numel(HOUSING)
    housing = HOUSING{hi};
    fprintf('\n%s\n-- %s --\n%s\n', repmat('=',1,66), housing, repmat('=',1,66));

    %% Find the best-ranked spline strategy (by V_tilde0, fast matfile read)
    files = dir(fullfile(RES_DIR, sprintf('spl_*_%s.mat', housing)));
    if isempty(files)
        fprintf('  No spl_*_%s.mat files in %s -- run run_spline_strategies first. Skipping.\n', ...
            housing, RES_DIR);
        continue
    end
    best_Vt0 = -Inf; best_file = '';
    for k = 1:numel(files)
        fname = fullfile(files(k).folder, files(k).name);
        m = matfile(fname); vars = who(m);
        if ismember('welfare0', vars)
            w0 = m.welfare0; Vt0 = w0.Vt0;
        else
            pk  = m.p; sol = m.sol;
            V0f = fill_nan_nearest_3d(sol.V(:,:,:,1));
            Fv  = griddedInterpolant({pk.lambda_grid, pk.sA_grid, pk.sH_grid}, ...
                                     V0f, 'linear', 'nearest');
            Vt0 = Fv(1/(1+pk.h_mult), 0, pk.h_mult/(1+pk.h_mult));
        end
        if Vt0 > best_Vt0
            best_Vt0 = Vt0; best_file = fname;
        end
    end

    nopension_file = fullfile(RES_DIR, sprintf('combined_%s_kappa0.mat', housing));
    if ~isfile(nopension_file)
        fprintf('  %s not found -- run run_combined first. Skipping.\n', nopension_file);
        continue
    end

    % No-pension Vt0, same fast-path-with-fallback as the strategy loop above.
    mn = matfile(nopension_file); vars_n = who(mn);
    if ismember('welfare0', vars_n)
        w0n = mn.welfare0; nop_Vt0 = w0n.Vt0;
    else
        pk  = mn.p; sol = mn.sol;
        V0f = fill_nan_nearest_3d(sol.V(:,:,:,1));
        Fv  = griddedInterpolant({pk.lambda_grid, pk.sA_grid, pk.sH_grid}, ...
                                 V0f, 'linear', 'nearest');
        nop_Vt0 = Fv(1/(1+pk.h_mult), 0, pk.h_mult/(1+pk.h_mult));
    end

    fprintf('  Best strategy: %s\n', best_file);
    fprintf('  No-pension:    %s\n', nopension_file);
    best = load(best_file, 'p', 'profile', 'sim', 'strat_info');
    nop  = load(nopension_file, 'p', 'profile', 'sim');
    % +simulate/paths.m does not compute H_net/M_balance itself (only
    % make_plots.m backfills them on load) -- do the same here so panel
    % (f) and the net-worth panels have what they need.
    best = backfill_mortgage(best);
    nop  = backfill_mortgage(nop);

    %% Sanity checks -- "does this make sense" before plotting anything
    ok = true;
    for f = {'C','pi','X','A','H','disp_inc'}
        fn = f{1};
        if any(isnan(best.sim.(fn)(:))) || any(isinf(best.sim.(fn)(:)))
            fprintf('  SANITY FAIL: best-strategy sim.%s has NaN/Inf.\n', fn); ok = false;
        end
        if any(isnan(nop.sim.(fn)(:))) || any(isinf(nop.sim.(fn)(:)))
            fprintf('  SANITY FAIL: no-pension sim.%s has NaN/Inf.\n', fn); ok = false;
        end
    end
    if any(abs(nop.sim.A(:)) > 1e-9)
        fprintf('  SANITY FAIL: no-pension scenario has nonzero A (kappa=0 should keep A=0 for life).\n');
        ok = false;
    end
    if best.p.is_owner ~= nop.p.is_owner
        fprintf('  SANITY FAIL: housing tenure differs between the two files (%d vs %d) -- not a fair comparison.\n', ...
            best.p.is_owner, nop.p.is_owner);
        ok = false;
    end
    if abs(mean(best.sim.H(:,1)) - mean(nop.sim.H(:,1))) > 1e-6 * max(1, mean(nop.sim.H(:,1)))
        fprintf('  SANITY FAIL: initial home value H_0 differs between the two files -- kappa should not affect H_0.\n');
        ok = false;
    end
    % Grid + calibration must match (kappa excluded -- differs by design):
    % V_tilde values from different grids/parameter vintages are not
    % comparable, so a stale file on either side makes the CEV meaningless.
    fp_b = param_fingerprint(best.p);
    fp_n = param_fingerprint(nop.p);
    if ~strcmp(fp_b, fp_n)
        fprintf('  SANITY FAIL: grid/calibration mismatch between the two files -- CEV below is NOT meaningful.\n');
        fprintf('    best:       %s\n', fp_b);
        fprintf('    no-pension: %s\n', fp_n);
        fprintf('    One of them is stale -- delete it and re-solve on the current calibration.\n');
        ok = false;
    end

    % Welfare gain of the best strategy is always measured against
    % NO_PENSION as the fixed reference: g > 0 means the best strategy
    % delivers g%% more lifetime consumption-equivalent value than no
    % pension; g < 0 means no pension delivers more. Either sign is a
    % normal, expected possible outcome, not an error -- report it as a
    % single number, not a "who won" branch.
    gamma  = best.p.gamma;
    g      = cev(nop_Vt0, best_Vt0, gamma);
    fprintf('  V_tilde0: best=%.6g   no-pension (reference)=%.6g\n', best_Vt0, nop_Vt0);
    fprintf('  Best strategy vs no pension (reference): %+.3f%% lifetime consumption-equivalent welfare gain.\n', g*100);
    if ok
        fprintf('  Sanity checks passed: no NaN/Inf, A=0 throughout for no-pension, matching tenure and H_0.\n');
    else
        fprintf('  ONE OR MORE SANITY CHECKS FAILED -- see above. Dashboard still generated for inspection.\n');
    end

    %% Dashboard: best strategy vs no pension, same 12-panel layout as
    %% make_plots.m's renter-vs-owner comparison, adapted to two DC-pension
    %% configurations at fixed housing tenure instead of two tenures.
    plot_comparison_dashboard(best, nop, housing, best.strat_info.name, g, ok, RES_DIR);
end
end

%% =======================================================================
function plot_comparison_dashboard(best, nop, housing, best_name, g, sanity_ok, out_dir)
p_b = best.p; p_n = nop.p;
sim_b = best.sim; sim_n = nop.sim;
ages    = sim_b.ages(:).';
ret_age = p_b.retirement_age;
is_own  = p_b.is_owner;
has_housing = p_b.h_mult > 0;

% Dollar scale: same convention as make_plots.m -- anchor mean income at
% age 50 to $50,000 (uses the pension-on scenario; both share the same
% income process since kappa doesn't affect gross income).
age50_idx   = 50 - p_b.age0 + 1;
unit        = mean(sim_b.Y(:, age50_idx));
Y50_dollars = 50000;
dscale      = Y50_dollars / (unit * 1000);
dlbl        = 'USD (k)';

pi_merton = p_b.mu_S_level / (p_b.gamma * p_b.sigma_S_level^2);

c_b = [0.20 0.45 0.75];   % blue  = best strategy (pension on)
c_n = [0.80 0.35 0.15];   % orange = no pension
FS = 10; FT = 11; LFS = 9; LWD = 1.9;
name_b = sprintf('Best strategy (%s)', strrep(best_name, '_', '\_'));
name_n = 'No pension (\kappa=0)';

[~, ~, efW_b, effin_b, tau_path_b, HC_b, ~] = equity_exposure(sim_b, p_b, best.profile);
[~, ~, efW_n, effin_n, ~,           HC_n, ~] = equity_exposure(sim_n, p_n, nop.profile);

TW_b = sim_b.X + sim_b.A + sim_b.H_net;
TW_n = sim_n.X + sim_n.A + sim_n.H_net;
TWHC_b = TW_b + HC_b;
TWHC_n = TW_n + HC_n;

dd_b = disposable_decomp(sim_b, p_b);
dd_n = disposable_decomp(sim_n, p_n);
if is_own
    HCOST_b = dd_b.maintenance + dd_b.mortgage;
    HCOST_n = dd_n.maintenance + dd_n.mortgage;
else
    HCOST_b = dd_b.rent;
    HCOST_n = dd_n.rent;
end

fig = figure('Position', [30 30 2200 1300], 'Color', 'w', 'Visible', 'off');
tl  = tiledlayout(3, 4, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {sprintf('%s: best DC glide path vs no pension', [upper(housing(1)) housing(2:end)]), ...
           sprintf('Blue = %s,  orange = %s.  Lines show the average across simulated households; shaded bands show the 10th-90th percentile range', ...
                   name_b, name_n)}, ...
      'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'tex');

% (a) Consumption
nexttile; hold on; grid on; box on;
plot_band(ages, sim_b.C * dscale, c_b, name_b, LWD);
plot_band(ages, sim_n.C * dscale, c_n, name_n, LWD);
xline(ret_age, 'k--', 'HandleVisibility', 'off');
xlabel('Age', 'FontSize', FS); ylabel(dlbl, 'FontSize', FS);
title('(a)  Consumption spending', 'FontSize', FT);
legend('Location', 'northwest', 'FontSize', LFS, 'Interpreter', 'tex');
set(gca, 'FontSize', FS);

% (b) Disposable income
nexttile; hold on; grid on; box on;
plot_band(ages, sim_b.disp_inc * dscale, c_b, name_b, LWD);
plot_band(ages, sim_n.disp_inc * dscale, c_n, name_n, LWD);
xline(ret_age, 'k--', 'HandleVisibility', 'off');
xlabel('Age', 'FontSize', FS); ylabel(dlbl, 'FontSize', FS);
title('(b)  Disposable income', 'FontSize', FT);
set(gca, 'FontSize', FS);

% (c) Housing cost (identical between lines by construction -- sanity check)
nexttile; hold on; grid on; box on;
plot_band(ages, HCOST_b * dscale, c_b, name_b, LWD);
plot_band(ages, HCOST_n * dscale, c_n, name_n, LWD);
xline(ret_age, 'k--', 'HandleVisibility', 'off');
xlabel('Age', 'FontSize', FS); ylabel(dlbl, 'FontSize', FS);
title('(c)  Housing cost (should overlap exactly -- kappa-independent)', 'FontSize', FT);
legend('Location', 'best', 'FontSize', LFS, 'Interpreter', 'tex');
set(gca, 'FontSize', FS);

% (d) Liquid savings
nexttile; hold on; grid on; box on;
plot_band(ages, sim_b.X * dscale, c_b, name_b, LWD);
plot_band(ages, sim_n.X * dscale, c_n, name_n, LWD);
xline(ret_age, 'k--', 'HandleVisibility', 'off');
xlabel('Age', 'FontSize', FS); ylabel(dlbl, 'FontSize', FS);
title('(d)  Liquid savings', 'FontSize', FT);
set(gca, 'FontSize', FS);

% (e) Pension account balance (no-pension line should sit exactly at 0)
nexttile; hold on; grid on; box on;
plot_band(ages, sim_b.A * dscale, c_b, name_b, LWD);
plot(ages, zeros(size(ages)), '--', 'Color', c_n, 'LineWidth', 1.6, ...
     'DisplayName', [name_n ' (always zero)']);
xline(ret_age, 'k--', 'HandleVisibility', 'off');
xlabel('Age', 'FontSize', FS); ylabel(dlbl, 'FontSize', FS);
title('(e)  Pension account balance', 'FontSize', FT);
legend('Location', 'best', 'FontSize', LFS, 'Interpreter', 'tex');
set(gca, 'FontSize', FS);

% (f) Housing detail (identical between lines by construction -- sanity check)
nexttile; hold on; grid on; box on;
if has_housing && is_own
    plot_band(ages, sim_b.H         * dscale, [0.60 0.82 0.58], [name_b ': home value'], LWD);
    plot_band(ages, sim_b.M_balance * dscale, [0.82 0.25 0.25], [name_b ': mortgage'],    LWD);
    plot_band(ages, sim_b.H_net     * dscale, c_b,              [name_b ': net equity'],  LWD);
    plot(ages, mean(sim_n.H_net,1) * dscale, '--', 'Color', c_n, 'LineWidth', 1.4, ...
         'DisplayName', [name_n ': net equity']);
    title('(f)  Home value, mortgage and net equity (should overlap)', 'FontSize', FT);
elseif has_housing
    plot_band(ages, sim_b.H * dscale, c_b, [name_b ': rented home value'], LWD);
    plot_band(ages, sim_n.H * dscale, c_n, [name_n ': rented home value'], LWD);
    title('(f)  Value of the rented home (should overlap exactly)', 'FontSize', FT);
else
    text(0.5, 0.5, 'No housing in this scenario', 'HorizontalAlignment', 'center', ...
         'Units', 'normalized', 'FontSize', 11, 'Color', [0.55 0.55 0.55]);
    title('(f)  Housing (not applicable)', 'FontSize', FT);
end
xline(ret_age, 'k--', 'HandleVisibility', 'off');
xlabel('Age', 'FontSize', FS); ylabel(dlbl, 'FontSize', FS);
legend('Location', 'best', 'FontSize', LFS - 1, 'Interpreter', 'tex');
set(gca, 'FontSize', FS);

% (g) Net worth: savings + pension + net housing equity
nexttile; hold on; grid on; box on;
plot_band(ages, TW_b * dscale, c_b, name_b, LWD);
plot_band(ages, TW_n * dscale, c_n, name_n, LWD);
xline(ret_age, 'k--', 'HandleVisibility', 'off');
xlabel('Age', 'FontSize', FS); ylabel(dlbl, 'FontSize', FS);
title('(g)  Net worth: savings, pension and housing equity', 'FontSize', FT);
set(gca, 'FontSize', FS);

% (h) Total wealth (net worth + human capital)
nexttile; hold on; grid on; box on;
plot_band(ages, TWHC_b * dscale, c_b, [name_b ': total wealth'], LWD);
plot_band(ages, TWHC_n * dscale, c_n, [name_n ': total wealth'], LWD);
plot(ages, mean(HC_b,1,'omitnan') * dscale, '--', 'Color', c_b, 'LineWidth', 1.3, ...
     'DisplayName', 'Human capital only');
xline(ret_age, 'k--', 'HandleVisibility', 'off');
xlabel('Age', 'FontSize', FS); ylabel(dlbl, 'FontSize', FS);
title('(h)  Total wealth (net worth + human capital)', 'FontSize', FT);
legend('Location', 'best', 'FontSize', LFS - 1, 'Interpreter', 'tex');
set(gca, 'FontSize', FS);

% (i) Stock share: household choice (both lines) + pension fund glide path
% (best-strategy line only -- meaningless for no-pension, A=0 for life)
nexttile; hold on; grid on; box on;
plot_band(ages, sim_b.pi, c_b, [name_b ': liquid savings'], LWD);
plot_band(ages, sim_n.pi, c_n, [name_n ': liquid savings'], LWD);
plot(ages, tau_path_b, '--', 'Color', [0.35 0.35 0.35], 'LineWidth', LWD, ...
     'DisplayName', 'Pension fund glide path (best strategy; N/A when kappa=0)');
xline(ret_age, 'k--', 'HandleVisibility', 'off');
xlabel('Age', 'FontSize', FS); ylabel('Stock share [0-1]', 'FontSize', FS);
title('(i)  Stock share: household savings vs. the pension fund', 'FontSize', FT);
legend('Location', 'best', 'FontSize', LFS - 1, 'Interpreter', 'tex');
ylim([-0.02 1.02]);
set(gca, 'FontSize', FS);

% (j) Stock exposure relative to total wealth
nexttile; hold on; grid on; box on;
plot_band(ages, efW_b, c_b, name_b, LWD);
plot_band(ages, efW_n, c_n, name_n, LWD);
xline(ret_age, 'k--', 'HandleVisibility', 'off');
yline(pi_merton, 'r--', 'Merton fraction', 'LabelHorizontalAlignment', 'left', ...
      'LineWidth', 1.4, 'FontSize', FS - 1, 'HandleVisibility', 'off');
xlabel('Age', 'FontSize', FS); ylabel('Stock share [0-1]', 'FontSize', FS);
title('(j)  Stock exposure relative to total wealth', 'FontSize', FT);
ylim([0 1]);
set(gca, 'FontSize', FS);

% (k) Stock exposure relative to savings and pension only
nexttile; hold on; grid on; box on;
plot_band(ages, effin_b, c_b, name_b, LWD);
plot_band(ages, effin_n, c_n, name_n, LWD);
xline(ret_age, 'k--', 'HandleVisibility', 'off');
xlabel('Age', 'FontSize', FS); ylabel('Stock share [0-1]', 'FontSize', FS);
title('(k)  Stock exposure relative to savings and pension only', 'FontSize', FT);
ylim([0 1]);
set(gca, 'FontSize', FS);

% (l) Summary: CEV (vs no-pension reference) + sanity-check status
nexttile; axis off;
cev_line = sprintf('Best strategy vs no pension (reference): %+.3f%% welfare gain.', g*100);
sanity_line = ternary(sanity_ok, ...
    'Sanity checks: PASSED (no NaN/Inf, A=0 for no-pension, matching tenure and H_0).', ...
    'Sanity checks: FAILED -- see console output.');
box_txt = {
    '\bf Comparison summary \rm';
    cev_line;
    sanity_line;
    '';
    sprintf('DC contribution rate (best strategy) \\kappa=%.0f%%   |   AOW replacement rate=%.0f%%', ...
            100*p_b.kappa, 100*p_b.replacement);
    sprintf('CRRA coefficient \\gamma=%.0f   |   Discount factor \\beta=%.2f', p_b.gamma, p_b.beta);
    sprintf('N=%d households per scenario,  ages %d-%d,  retirement age %d', ...
            sim_b.N, p_b.age0, p_b.age0+p_b.T-1, ret_age);
};
text(0.02, 0.97, box_txt, 'Units', 'normalized', 'VerticalAlignment', 'top', ...
     'FontSize', FS, 'Interpreter', 'tex');
title('(l)  Summary', 'FontSize', FT);

hide_axes_toolbars(fig);
out = fullfile(out_dir, sprintf('fig_strategy_vs_nopension_%s.png', housing));
exportgraphics(fig, out, 'Resolution', 150);
fprintf('  Wrote %s\n', out);
close(fig);
end

%% =======================================================================
function s = backfill_mortgage(s)
% Same convention as make_plots.m's loading section: +simulate/paths.m
% does not compute H_net/M_balance directly, so derive them here from the
% deterministic mortgage schedule. Renters never own H (it only scales the
% rent flow), so H_net is forced to zero for them regardless.
if ~isfield(s.p, 'LTV'), s.p.LTV = 0.80; end
if ~isfield(s.sim, 'M_balance')
    if s.p.is_owner && s.p.h_mult > 0 && s.p.m_rate_path(1) > 0
        ltv     = s.p.LTV;
        H0      = s.sim.H(1,1);
        PMT     = ltv * H0 * s.p.m_rate_path(1);
        M_sched = zeros(1, s.p.T);
        M_sched(1) = ltv * H0;
        for tt = 1:s.p.T-1
            M_sched(tt+1) = max(0, M_sched(tt) * (1 + s.p.r_m) - PMT);
        end
        s.sim.M_balance = repmat(M_sched, s.sim.N, 1);
    else
        s.sim.M_balance = zeros(size(s.sim.H));
    end
end
if ~isfield(s.sim, 'H_net')
    s.sim.H_net = s.sim.H - s.sim.M_balance;
end
if ~s.p.is_owner
    s.sim.H_net = zeros(size(s.sim.H));
end
end

function g = cev(V_A, V_B, gamma)
%CEV  Consumption-equivalent variation of A relative to benchmark B.
%   g > 0: A needs g*100% more lifetime consumption to match B (A worse).
    g = (V_B / V_A) ^ (1 / (1 - gamma)) - 1;
end

function s = param_fingerprint(p)
%PARAM_FINGERPRINT  Same convention as compare_spline_strategies.m: one-line
%   grid + calibration identity string; kappa deliberately excluded.
flds = {'N_lambda','N_sA','N_sH','gh_n','age0','T','retirement_age', ...
        'gamma','beta','chi','alpha','theta','h_mult','r','mu_S_level', ...
        'sigma_S_level','mu_H_level','sigma_H_level','r_m','replacement', ...
        'sigma_l_log','tau_inc','tau_cg_stock'};
parts = cell(1, numel(flds));
for i = 1:numel(flds)
    if isfield(p, flds{i}), v = p.(flds{i}); else, v = NaN; end
    parts{i} = sprintf('%s=%.6g', flds{i}, v);
end
s = strjoin(parts, ' ');
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end

function hide_axes_toolbars(fig)
axs = findall(fig, 'Type', 'axes');
for aa = 1:numel(axs)
    tb = axs(aa).Toolbar;
    if ~isempty(tb), tb.Visible = 'off'; end
end
end

function plot_band(x, M, color, name, lwd)
% Mean line + 10-90 percentile shaded band. M is N x T.
if nargin < 5, lwd = 1.7; end
if size(M,1) == 1, M = M(:).'; end
mu = mean(M, 1, 'omitnan');
lo = quantile(M, 0.10, 1);
hi = quantile(M, 0.90, 1);
fc = min(1, color * 0.5 + 0.5);
fill([x, fliplr(x)], [lo, fliplr(hi)], fc, 'EdgeColor','none', ...
     'FaceAlpha',0.25, 'HandleVisibility','off');
plot(x, mu, '-', 'Color', color, 'LineWidth', lwd, 'DisplayName', name);
end

function d = disposable_decomp(sim, p)
% Decompose disposable income into its additive components (model units, N x T).
% Same convention as make_plots.m's disposable_decomp.
[N, T] = size(sim.Y);
is_ret = (1:T) >= p.t_ret;

tau_inc = 0; if isfield(p, 'tau_inc'), tau_inc = p.tau_inc; end
net_inc = 1 - tau_inc;

d.gross_Y = sim.Y;
d.tax     = zeros(N, T);
d.tax(:, ~is_ret) = (1 - p.delta) * (1 - p.kappa) * tau_inc .* sim.Y(:, ~is_ret);
d.tax(:, is_ret)  = (1 - p.delta) * tau_inc .* sim.Y(:, is_ret);

d.pension_contrib = zeros(N, T);
d.pension_contrib(:, ~is_ret) = p.kappa .* sim.Y(:, ~is_ret);

contrib_factor = repmat((1 - p.delta) * net_inc, N, T);
contrib_factor(:, ~is_ret) = (1 - p.delta) * (1 - p.kappa) * net_inc;
d.takehome = contrib_factor .* sim.Y;

d.annuity = net_inc .* sim.ann_pay;

d.rent        = zeros(N, T);
d.maintenance = zeros(N, T);
d.mortgage    = zeros(N, T);
if p.h_mult > 0
    if p.is_owner
        d.maintenance = p.theta .* sim.H;
        d.mortgage    = sim.m_pay;
    else
        d.rent        = p.alpha .* sim.H;
    end
end

d.disp = d.takehome + d.annuity - (d.rent + d.maintenance + d.mortgage);
end

function [eq_priv, eq_pens, eq_frac_W, eq_frac_fin, tau_path, HC, W] = equity_exposure(sim, p, profile)
% Same convention as make_plots.m's equity_exposure -- see that file for
% the full derivation notes.
[N, T] = size(sim.X); %#ok<ASGLU>

tau_S_vec = [p.tau_S(:); zeros(max(0, T - numel(p.tau_S)), 1)];
tau_path  = tau_S_vec(1:T).';

eq_priv = sim.pi .* sim.X;
eq_pens = bsxfun(@times, sim.A, tau_path);

Rf      = 1 + p.r;
p_surv  = profile.p_surv(:);
mu_grow = profile.mu_growth(:);
sig_l   = profile.sigma_l_log(:);

log_step = mu_grow + 0.5 .* sig_l.^2;
cum_log  = [0; cumsum(log_step)];

g_t = zeros(T, 1);
for t = 1:T
    cs = 1; pv = 0;
    for s = (t+1):T
        cs = cs * p_surv(s-1);
        pv = pv + exp(cum_log(s) - cum_log(t)) * cs / Rf^(s - t);
    end
    g_t(t) = pv;
end
g_path = g_t.';

HC = sim.Y .* g_path;
Y_total = sim.Y + HC;

W = sim.X + sim.A + sim.H + Y_total;
eq_frac_W = (eq_priv + eq_pens) ./ max(W, 1e-10);

fin_raw     = sim.X + sim.A;
eq_frac_fin = (eq_priv + eq_pens) ./ fin_raw;
eq_frac_fin(fin_raw < 1e-6) = NaN;
end

function Z = fill_nan_nearest_3d(M)
% Replace infeasible-state NaNs with nearest finite value -- same helper
% used throughout this repo (solve_lifecycle.m, paths.m, welfare_dc_strategies.m).
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
