% MAKE_PLOTS  Per-scenario dashboards + 3D policy surfaces + cross-scenario comparison
%
%   Output figures
%   ─────────────────────────────────────────────────────────────────────────
%   fig_dashboard_<name>.png      3×4 per-scenario dashboard (level in USD k)
%   fig_policy_3d_<name>.png      3D policy surfaces at 4 representative ages
%   fig_cross_scenario.png        3×4 clean 5-scenario comparison (mean lines)
%   fig_renter_vs_owner.png       2×4 FULL renter vs owner (mean + band)
%   fig_reduction_overlay.png     1×3 reduction-consistency check
%
%   Dollar calibration
%   ─────────────────────────────────────────────────────────────────────────
%   All level plots are in USD thousands, anchored so that the mean simulated
%   income at age 50 equals Y50_dollars = $50 000.  Fractions (c, pi, shares)
%   remain dimensionless.
%
%   Housing note
%   ─────────────────────────────────────────────────────────────────────────
%   Panel (d) net-worth stack uses H_net = H_gross − M_balance (net equity).
%   Panel (f) shows the full housing decomposition: gross H, mortgage M, H_net.
%   The solver uses a proportional mortgage-cost approximation (m_rate*H_t) to
%   preserve homotheticity; M_balance is tracked exactly in the forward simulation.

close all;

% ── run-control flags ────────────────────────────────────────────────────
% RUN_ALL_SCENARIOS = true  -> all 5 dashboards + 3D surfaces + cross-scenario
%                              comparison + reduction overlay (full pipeline).
% RUN_ALL_SCENARIOS = false -> only the FULL renter/owner dashboards and the
%                              renter-vs-owner comparison (faster iteration).
RUN_ALL_SCENARIOS = false;

% ── scenario metadata ─────────────────────────────────────────────────────
fig_tag = '';    % appended to always-on figure filenames ('' or '_lna')
if RUN_ALL_SCENARIOS
    files = {'diag_pension_only.mat', ...
             'diag_housing_renter.mat', 'diag_housing_owner.mat', ...
             'diag_full_renter.mat',    'diag_full_owner.mat'};
    short_names  = {'pension_only',  'housing_renter', 'housing_owner', ...
                    'full_renter',   'full_owner'};
    legend_names = {'Pension only',  'Housing renter', 'Housing owner', ...
                    'Full renter',   'Full owner'};
    labels = {'PENSION ONLY (no housing)', ...
              'HOUSING ONLY renter (no pension)', ...
              'HOUSING ONLY owner (no pension)', ...
              'FULL renter (pension + housing)', ...
              'FULL owner (pension + housing)'};
    colors = {[0.20 0.30 0.55], ...
              [0.85 0.40 0.20], [0.85 0.65 0.15], ...
              [0.45 0.20 0.55], [0.20 0.60 0.30]};
else
    files        = {'combined_renter.mat',     'combined_owner.mat'};
    short_names  = {'full_renter',             'full_owner'};
    legend_names = {'Full renter',             'Full owner'};
    labels       = {'FULL renter (pension + housing)', ...
                     'FULL owner (pension + housing)'};
    colors       = {[0.45 0.20 0.55], [0.20 0.60 0.30]};
    % CGM_GRID=lna reads the cube-grid outputs of run_combined
    % (combined_<name>_lna.mat) and tags figures _lna so the two grid
    % systems can be plotted side by side. Only this 2-file branch is
    % lna-aware: the diag_* pipeline and the 3D policy-surface section
    % assume the simplex (lambda, s_A, s_H) grid layout.
    if strcmp(getenv('CGM_GRID'), 'lna')
        files   = strrep(files, '.mat', '_lna.mat');
        labels  = cellfun(@(s) [s '  [lna grid]'], labels, 'UniformOutput', false);
        fig_tag = '_lna';
    end
end

% Read inputs from (and write figures to) the persistent-volume output dir
% if CGM_OUTPUT_DIR is set -- see +utility/output_dir.m.
out_dir = utility.output_dir();
files   = fullfile(out_dir, files);

% Tolerate missing scenario files in the 2-file mode (e.g. only the renter
% solved so far): plot what exists, skip the rest. The 5-scenario pipeline
% keeps the hard requirement because its sections index scenarios by
% position (S{1}..S{5}).
if ~RUN_ALL_SCENARIOS
    present = cellfun(@isfile, files);
    if ~any(present)
        error('make_plots:no_inputs', 'None of these exist: %s -- run run_combined first.', ...
              strjoin(files, ', '));
    end
    for k = find(~present)
        fprintf('NOTE: %s missing -- skipping that scenario.\n', files{k});
    end
    files        = files(present);
    short_names  = short_names(present);
    legend_names = legend_names(present);
    labels       = labels(present);
    colors       = colors(present);
end

% ── load ──────────────────────────────────────────────────────────────────
S = cell(numel(files), 1);
for k = 1:numel(files)
    if ~isfile(files{k}), error('Missing %s – run run_diagnostics first', files{k}); end
    S{k} = load(files{k});
    % Backward compatibility: older .mat files predate mortgage tracking and
    % may lack p.LTV entirely. Mortgage schedule is deterministic — compute
    % from saved params, no re-solve needed. Backfill p.LTV so every
    % downstream consumer (e.g. the calibration box) can read it directly.
    if ~isfield(S{k}.p, 'LTV'), S{k}.p.LTV = 0.80; end
    if ~isfield(S{k}.sim, 'M_balance')
        if S{k}.p.is_owner && S{k}.p.h_mult > 0 && S{k}.p.m_rate_path(1) > 0
            ltv_k   = S{k}.p.LTV;
            H0_k    = S{k}.sim.H(1,1);
            PMT_k   = ltv_k * H0_k * S{k}.p.m_rate_path(1);
            M_sched = zeros(1, S{k}.p.T);
            M_sched(1) = ltv_k * H0_k;
            for tt = 1:S{k}.p.T-1
                M_sched(tt+1) = max(0, M_sched(tt) * (1 + S{k}.p.r_m) - PMT_k);
            end
            S{k}.sim.M_balance = repmat(M_sched, S{k}.sim.N, 1);
        else
            S{k}.sim.M_balance = zeros(size(S{k}.sim.H));
        end
    end
    if ~isfield(S{k}.sim, 'H_net')
        S{k}.sim.H_net = S{k}.sim.H - S{k}.sim.M_balance;
    end
    % Renters never own H (it only scales the rent flow alpha*H_t; bequest
    % base excludes H for renters -- see bellman_step). Zero out any stray
    % H_net so it can never be miscounted as owned housing equity.
    if ~S{k}.p.is_owner
        S{k}.sim.H_net = zeros(size(S{k}.sim.H));
    end
end
ages    = S{1}.sim.ages(:).';
ret_age = S{1}.p.retirement_age;

% ── dollar scale ──────────────────────────────────────────────────────────
age50_idx  = 50 - S{1}.p.age0 + 1;
unit       = mean(S{1}.sim.Y(:, age50_idx));   % model unit = E[Y @ age 50]
Y50_dollars = 50000;                            % calibrated age-50 income in USD
dscale      = Y50_dollars / (unit * 1000);      % model units  →  USD thousands
dlbl        = 'USD (k)';
fprintf('E[Y@50] = %.4f  |  1 model unit = $%.0f  |  dscale = %.3f k$/unit\n', ...
        unit, Y50_dollars/unit, dscale);

% ── Merton benchmark ─────────────────────────────────────────────────────
% Classical Merton risky share on total wealth: pi* = mu_S_excess / (gamma * sigma_S^2)
% Reference horizontal line for the "Total equity / total wealth W" panels.
% p.mu_S_level IS ALREADY the excess return over r_f (see params.m) -- do not
% subtract p.r again here, that would double-count it and always give 0.
% Uses level (gross) excess return / vol as in params.m. Same across all five
% scenarios since gamma, mu_S, sigma_S don't vary.
pi_merton = S{1}.p.mu_S_level / (S{1}.p.gamma * S{1}.p.sigma_S_level^2);
fprintf('Merton benchmark: pi* = %.3f/(%.0f * %.3f^2) = %.4f\n', ...
        S{1}.p.mu_S_level, S{1}.p.gamma, S{1}.p.sigma_S_level, pi_merton);

%% =================== PER-SCENARIO DASHBOARDS (3×4) ======================
% Publication-quality 12-panel dashboard per scenario.
%   Row 1: (a) Income & housing costs | (b) Consumption | (c) Disposable income breakdown | (d) Net worth
%   Row 2: (e) Pension balance | (f) Housing detail | (g) Net worth + future income | (h) Consumption share
%   Row 3: (i) Stocks/liquid savings | (j) Combined stock exposure | (k) Stocks/savings+pension | (l) Calibration

% Shared style constants
FS  = 10;   % axis tick / label font size
FT  = 11;   % panel title font size
LFS = 9;    % legend font size
LWD = 1.9;  % main line width
BAND_NOTE = 'Lines show the average across simulated households; shaded bands show the 10th-90th percentile range';

for k = 1:numel(files)
    sim = S{k}.sim;  p = S{k}.p;  sol = S{k}.sol;
    col = colors{k};
    has_pension = p.kappa > 0;
    has_housing = p.h_mult > 0;
    is_own      = p.is_owner;

    % Equity exposure decomposition + human capital (HC) + total wealth W
    % tau_path = pension fund's own stock allocation glide path (plan design,
    % not chosen by the household -- see config.params for the schedule).
    [eq_priv, eq_pens, eq_frac_W, eq_frac_fin, tau_path, HC, Wtot] = equity_exposure(sim, p, S{k}.profile);

    fig = figure('Position', [30 30 2200 1240], 'Color', 'w');
    tl  = tiledlayout(3, 4, 'Padding', 'compact', 'TileSpacing', 'compact');
    title(tl, {sprintf('Dashboard — %s', labels{k}), BAND_NOTE}, ...
          'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'tex');

    % ── (a) Income and housing costs ────────────────────────────────────
    nexttile; hold on; grid on; box on;
    plot_band(ages, sim.Y        * dscale, [0.25 0.45 0.75], 'Gross income (before any deductions)', LWD);
    plot_band(ages, sim.disp_inc * dscale, [0.85 0.50 0.20], 'Disposable income (after contributions and housing costs)', LWD);
    if has_pension && any(sim.ann_pay(:) > 0)
        plot_band(ages, sim.ann_pay * dscale, [0.25 0.65 0.35], 'Pension annuity payment', LWD);
    end
    if has_housing
        hc = housing_cost(sim, p);
        if is_own
            hc_label = 'Housing cost (maintenance + mortgage payment)';
        else
            hc_label = 'Housing cost (rent payment)';
        end
        plot_band(ages, hc * dscale, [0.80 0.25 0.25], hc_label, LWD);
    end
    xline(ret_age, 'k--', 'Retirement', 'LabelVerticalAlignment', 'bottom', ...
          'HandleVisibility', 'off', 'FontSize', FS - 1);
    xlabel('Age', 'FontSize', FS); ylabel(dlbl, 'FontSize', FS);
    title('(a)  Income and housing costs over the lifecycle', 'FontSize', FT);
    legend('Location', 'northwest', 'FontSize', LFS);
    set(gca, 'FontSize', FS);

    % ── (b) Consumption spending ─────────────────────────────────────────
    nexttile; hold on; grid on; box on;
    plot_band(ages, sim.C * dscale, col, 'Consumption spending', LWD);
    xline(ret_age, 'k--', 'HandleVisibility', 'off');
    xlabel('Age', 'FontSize', FS); ylabel(dlbl, 'FontSize', FS);
    title('(b)  Consumption spending over the lifecycle', 'FontSize', FT);
    set(gca, 'FontSize', FS);

    % ── (c) Disposable income: where it comes from, where it goes ────────
    % Positive stack (income in) above zero; cost stack (housing out) below.
    % Net disposable line + gross-income reference line.
    nexttile; hold on; grid on; box on;
    dd     = disposable_decomp(sim, p);
    th_m   = mean(dd.takehome,    1) * dscale;
    an_m   = mean(dd.annuity,     1) * dscale;
    rent_m = mean(dd.rent,        1) * dscale;
    main_m = mean(dd.maintenance, 1) * dscale;
    mort_m = mean(dd.mortgage,    1) * dscale;
    grY_m  = mean(dd.gross_Y,     1) * dscale;
    disp_m = mean(dd.disp,        1) * dscale;

    ap = area(ages, [th_m; an_m].');                 % income in (>=0)
    ap(1).FaceColor = [0.35 0.62 0.42];  ap(1).FaceAlpha = 0.80;  ap(1).EdgeColor = 'none';
    ap(2).FaceColor = [0.20 0.55 0.55];  ap(2).FaceAlpha = 0.80;  ap(2).EdgeColor = 'none';
    ap(1).DisplayName = 'Income received (wages before retirement, state pension after)';
    ap(2).DisplayName = 'Private pension payment';
    if is_own
        anh = area(ages, -[main_m; mort_m].');       % housing out (<=0)
        anh(1).FaceColor = [0.90 0.55 0.20];  anh(1).FaceAlpha = 0.80;  anh(1).EdgeColor = 'none';
        anh(2).FaceColor = [0.65 0.15 0.15];  anh(2).FaceAlpha = 0.80;  anh(2).EdgeColor = 'none';
        anh(1).DisplayName = 'Home maintenance cost';
        anh(2).DisplayName = 'Mortgage payment';
    elseif has_housing
        anh = area(ages, -rent_m.');
        anh(1).FaceColor = [0.80 0.30 0.30];  anh(1).FaceAlpha = 0.80;  anh(1).EdgeColor = 'none';
        anh(1).DisplayName = 'Rent payment';
    end
    plot(ages, disp_m, 'k-',  'LineWidth', 2.0, 'DisplayName', 'Net disposable income');
    plot(ages, grY_m, '--', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.2, ...
         'DisplayName', 'Gross income (before deductions, for reference)');
    xline(ret_age, 'k--', 'HandleVisibility', 'off');
    yline(0, 'k-', 'HandleVisibility', 'off', 'LineWidth', 0.5);
    xlabel('Age', 'FontSize', FS); ylabel(dlbl, 'FontSize', FS);
    title('(c)  Disposable income', 'FontSize', FT);
    legend('Location', 'best', 'FontSize', LFS - 2, 'NumColumns', 1);
    set(gca, 'FontSize', FS);

    % ── (d) Net worth: savings, pension and housing equity ────────────────
    nexttile; hold on; grid on; box on;
    Xm    = mean(sim.X,     1) * dscale;
    Am    = mean(sim.A,     1) * dscale;
    Hnetm = mean(sim.H_net, 1) * dscale;
    ha = area(ages, [Xm; Am; Hnetm].');
    ha(1).FaceColor = [0.50 0.68 0.84];  ha(1).FaceAlpha = 0.85;
    ha(2).FaceColor = [0.95 0.75 0.28];  ha(2).FaceAlpha = 0.85;
    ha(3).FaceColor = [0.42 0.76 0.48];  ha(3).FaceAlpha = 0.85;
    ha(1).DisplayName = 'Liquid savings';
    ha(2).DisplayName = 'Pension account balance';
    ha(3).DisplayName = 'Net housing equity (home value minus mortgage owed)';
    xline(ret_age, 'k--', 'HandleVisibility', 'off');
    xlabel('Age', 'FontSize', FS); ylabel(dlbl, 'FontSize', FS);
    title('(d)  Net worth: savings, pension and housing equity combined', 'FontSize', FT);
    legend('Location', 'northwest', 'FontSize', LFS);
    set(gca, 'FontSize', FS);

    % ── (e) Pension account balance and payouts ───────────────────────────
    nexttile; hold on; grid on; box on;
    plot_band(ages, sim.A * dscale, [0.85 0.60 0.15], 'Account balance', LWD);
    if any(sim.ann_pay(:) > 0)
        plot_band(ages, sim.ann_pay * dscale, [0.25 0.65 0.35], 'Annuity payments after retirement', LWD);
    end
    xline(ret_age, 'k--', 'HandleVisibility', 'off');
    xlabel('Age', 'FontSize', FS); ylabel(dlbl, 'FontSize', FS);
    title('(e)  Pension account balance and payouts', 'FontSize', FT);
    legend('Location', 'best', 'FontSize', LFS);
    set(gca, 'FontSize', FS);

    % ── (f) Housing: owner gets value/mortgage/equity; renter gets dwelling value ──
    nexttile; hold on; grid on; box on;
    if has_housing && is_own
        plot_band(ages, sim.H         * dscale, [0.60 0.82 0.58], 'Home value', LWD);
        plot_band(ages, sim.M_balance * dscale, [0.82 0.25 0.25], 'Mortgage balance owed', LWD);
        plot_band(ages, sim.H_net     * dscale, [0.15 0.52 0.25], 'Net home equity (value minus mortgage owed)', LWD);
        xline(ret_age, 'k--', 'HandleVisibility', 'off');
        legend('Location', 'best', 'FontSize', LFS);
        title('(f)  Home value, mortgage balance and net equity', 'FontSize', FT);
    elseif has_housing
        % Renter: H is the rented dwelling's value (sets rent payment); it is
        % never owned, so it contributes zero to the renter's net worth.
        plot_band(ages, sim.H * dscale, [0.55 0.55 0.55], 'Value of the rented home', LWD);
        xline(ret_age, 'k--', 'HandleVisibility', 'off');
        legend('Location', 'best', 'FontSize', LFS);
        title('(f)  Value of the rented home (renters build no housing equity)', 'FontSize', FT);
    else
        text(0.5, 0.5, 'No housing in this scenario', ...
             'HorizontalAlignment', 'center', 'Units', 'normalized', ...
             'FontSize', 11, 'Color', [0.55 0.55 0.55]);
        title('(f)  Housing (not applicable to this scenario)', 'FontSize', FT);
    end
    xlabel('Age', 'FontSize', FS); ylabel(dlbl, 'FontSize', FS);
    set(gca, 'FontSize', FS);

    % ── (g) Total wealth (net worth + human capital) ──────────────────────
    nexttile; hold on; grid on; box on;
    Xm2    = mean(sim.X,     1) * dscale;
    Am2    = mean(sim.A,     1) * dscale;
    Hnetm2 = mean(sim.H_net, 1) * dscale;
    HCm    = mean(HC,        1) * dscale;
    TOTm   = Xm2 + Am2 + Hnetm2 + HCm;
    plot(ages, HCm,    '-', 'Color', [0.55 0.35 0.65], 'LineWidth', LWD, 'DisplayName', 'Value of future income (human capital)');
    plot(ages, Xm2,    '-', 'Color', [0.30 0.50 0.75], 'LineWidth', LWD, 'DisplayName', 'Liquid savings');
    plot(ages, Am2,    '-', 'Color', [0.85 0.60 0.15], 'LineWidth', LWD, 'DisplayName', 'Pension account balance');
    plot(ages, Hnetm2, '-', 'Color', [0.30 0.65 0.35], 'LineWidth', LWD, 'DisplayName', 'Net housing equity');
    plot(ages, TOTm,   'k-', 'LineWidth', 2.4, 'DisplayName', 'Total wealth (all components combined)');
    xline(ret_age, 'k--', 'HandleVisibility', 'off');
    xlabel('Age', 'FontSize', FS); ylabel(dlbl, 'FontSize', FS);
    title('(g)  Total wealth (net worth + human capital)', 'FontSize', FT);
    legend('Location', 'best', 'FontSize', LFS - 1);
    set(gca, 'FontSize', FS);

    % ── (h) Share of available resources spent on consumption ─────────────
    nexttile; hold on; grid on; box on;
    plot_band(ages, sim.c_frac, col, 'Consumption share', LWD);
    xline(ret_age, 'k--', 'HandleVisibility', 'off');
    xlabel('Age', 'FontSize', FS); ylabel('Share of resources spent [0–1]', 'FontSize', FS);
    title('(h)  Share of available resources spent on consumption', 'FontSize', FT);
    ylim([0 1]);
    set(gca, 'FontSize', FS);

    % ── (i) Stock share: household's liquid savings vs the pension fund ───
    % pi_t (household choice, varies by household -> mean+band) alongside
    % tau_S(t) (the pension fund's own glide path: fixed by plan design, the
    % same for every household, so plotted as a single deterministic line).
    nexttile; hold on; grid on; box on;
    plot_band(ages, sim.pi, col, 'Liquid savings: stock share chosen by the household', LWD);
    plot(ages, tau_path, '--', 'Color', [0.75 0.25 0.25], 'LineWidth', LWD, ...
         'DisplayName', 'Pension fund: stock share set by the plan''s glide path');
    xline(ret_age, 'k--', 'HandleVisibility', 'off');
    xlabel('Age', 'FontSize', FS); ylabel('Stock share [0–1]', 'FontSize', FS);
    title('(i)  Stock share: household savings vs. the pension fund', 'FontSize', FT);
    legend('Location', 'best', 'FontSize', LFS - 1);
    ylim([-0.02 1.02]);
    set(gca, 'FontSize', FS);

    % ── (j) Combined stock exposure: liquid + pension holdings ────────────
    % Stacked decomposition: liquid-savings stock holdings + pension stock
    % holdings, both as a share of total wealth. Stack height = total
    % exposure (this equals the mean of eq_frac_W exactly, by linearity).
    nexttile; hold on; grid on; box on;
    liq_eqW_m  = mean(eq_priv ./ max(Wtot, 1e-10), 1, 'omitnan');
    pens_eqW_m = mean(eq_pens ./ max(Wtot, 1e-10), 1, 'omitnan');
    aj = area(ages, [liq_eqW_m; pens_eqW_m].');
    aj(1).FaceColor = [0.30 0.55 0.80]; aj(1).FaceAlpha = 0.85; aj(1).EdgeColor = 'none';
    aj(2).FaceColor = [0.85 0.60 0.20]; aj(2).FaceAlpha = 0.85; aj(2).EdgeColor = 'none';
    aj(1).DisplayName = 'Liquid savings invested in stocks';
    aj(2).DisplayName = 'Pension invested in stocks';
    plot(ages, liq_eqW_m + pens_eqW_m, 'k-', 'LineWidth', 1.4, ...
         'DisplayName', 'Total stock exposure (both combined)');
    xline(ret_age, 'k--', 'HandleVisibility', 'off');
    yline(pi_merton, 'r--', 'Merton fraction', ...
          'LabelHorizontalAlignment', 'left', 'LineWidth', 1.5, 'FontSize', FS - 1, ...
          'HandleVisibility', 'off');
    xlabel('Age', 'FontSize', FS); ylabel('Share of total wealth [0–1]', 'FontSize', FS);
    title('(j)  Total stock exposure: liquid and pension holdings combined', 'FontSize', FT);
    legend('Location', 'best', 'FontSize', LFS - 1);
    ylim([0 1]);
    set(gca, 'FontSize', FS);

    % ── (k) Stock exposure relative to savings and pension only ───────────
    nexttile; hold on; grid on; box on;
    plot_band(ages, eq_frac_fin, [0.55 0.22 0.65], 'Stock share of savings and pension', LWD);
    xline(ret_age, 'k--', 'HandleVisibility', 'off');
    xlabel('Age', 'FontSize', FS); ylabel('Stock share [0–1]', 'FontSize', FS);
    title('(k)  Stock exposure relative to savings and pension only', 'FontSize', FT);
    ylim([0 1]);
    set(gca, 'FontSize', FS);

    % ── (l) Calibration / parameter box ──────────────────────────────────
    nexttile; axis off;
    if is_own
        ltv = NaN; if isfield(p, 'LTV'), ltv = p.LTV; end   % older .mat files lack LTV
        house_line = sprintf('Owner:  LTV=%.0f%%,  mortgage rate r_m=%.1f%%,  maintenance \\theta=%.1f%%', ...
                             100*ltv, 100*p.r_m, 100*p.theta);
    elseif has_housing
        house_line = sprintf('Renter:  rent rate \\alpha=%.1f%% of home value p.a.', 100*p.alpha);
    else
        house_line = 'Housing not modelled in this scenario.';
    end
    tau_inc  = NaN; if isfield(p, 'tau_inc'),      tau_inc  = p.tau_inc;      end   % older .mat files predate the tax model
    tau_cg_b = NaN; if isfield(p, 'tau_cg_bond'),  tau_cg_b = p.tau_cg_bond;  end
    tau_cg_s = NaN; if isfield(p, 'tau_cg_stock'), tau_cg_s = p.tau_cg_stock; end
    box_txt = {
        '\bf Calibration \rm';
        sprintf('CRRA coefficient \\gamma=%.0f   |   Discount factor \\beta=%.2f   |   Bequest parameter \\chi=%.2f', p.gamma, p.beta, p.chi);
        sprintf('DC contribution rate \\kappa=%.0f%%   |   AOW replacement rate=%.0f%%', 100*p.kappa, 100*p.replacement);
        sprintf('Risk-free rate r=%.1f%%   |   Equity return \\mu_S=%.1f%%   |   Equity volatility \\sigma_S=%.1f%%', 100*p.r, 100*p.mu_S_level, 100*p.sigma_S_level);
        sprintf('Income tax \\tau_{inc}=%.0f%%   |   Capital-gains tax bond/stock=%.0f%%/%.0f%%', 100*tau_inc, 100*tau_cg_b, 100*tau_cg_s);
        house_line;
        sprintf('N=%d households,  ages %d-%d,  retirement age %d', sim.N, p.age0, p.age0+p.T-1, ret_age);
        sprintf('Dollar scale: 1 model unit = $%.0f.   Merton fraction \\pi^{*}=%.2f', Y50_dollars/unit, pi_merton);
    };
    text(0.02, 0.97, box_txt, 'Units', 'normalized', 'VerticalAlignment', 'top', ...
         'FontSize', FS, 'Interpreter', 'tex');
    title('(l)  Calibration', 'FontSize', FT);

    % Footnote: clarify the two mortgage treatments used in this figure
    if has_housing && is_own
        fn_txt = ['Note: panels (a) and (c) housing cost use the model''s simplified approximation, ' ...
                  'where the mortgage payment scales with the current home value. ' ...
                  'Panels (d), (f) and (g) instead use the realistic fixed mortgage payment schedule, ' ...
                  'where the payment is fixed at purchase and the balance is paid off over time.'];
        annotation(fig, 'textbox', [0.01 0.00 0.98 0.03], ...
                   'String', fn_txt, 'FontSize', 7, 'Interpreter', 'tex', ...
                   'EdgeColor', 'none', 'Color', [0.40 0.40 0.40], ...
                   'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                   'FitBoxToText', false);
    end

    hide_axes_toolbars(fig);
    out = fullfile(out_dir, sprintf('fig_dashboard_%s%s.png', short_names{k}, fig_tag));
    exportgraphics(fig, out, 'Resolution', 150);
    fprintf('Wrote %s\n', out);
    close(fig);
end

%% =================== 3D POLICY SURFACES =================================
% For each scenario: 2-row × 4-column figure.
%   Row 1: c(λ, s_A) surfaces at ages 30, 45, 60, 75 (fixed s_H at mean)
%   Row 2: π(λ, s_A) surfaces at the same ages

if RUN_ALL_SCENARIOS
ages_3d = [30, 45, 60, 75];

for k = 1:numel(files)
    sim = S{k}.sim;  p = S{k}.p;  sol = S{k}.sol;
    has_housing = p.h_mult > 0;

    t_3d = ages_3d - p.age0 + 1;
    t_3d = t_3d(t_3d >= 1 & t_3d <= p.T);
    n3   = numel(t_3d);

    [SAgrid, LAmgrid] = meshgrid(p.sA_grid, p.lambda_grid);

    fig = figure('Position', [40 40 350*n3 650], 'Color','w');
    tl  = tiledlayout(2, n3, 'Padding','compact','TileSpacing','compact');
    title(tl, sprintf('3D policy surfaces — %s', labels{k}), ...
          'FontSize',12,'FontWeight','bold','Interpreter','tex');

    for j = 1:n3
        tt    = t_3d(j);
        age_j = p.age0 + tt - 1;

        % fix s_H at mean simulated value (0 if no housing)
        sH_fix = 0;
        if has_housing && tt <= size(sim.sH,2)
            sH_fix = mean(sim.sH(:, tt));
        end
        [~, ih] = min(abs(p.sH_grid - sH_fix));

        c_surf  = squeeze(sol.c_pol( :, :, ih, tt));   % (N_lam × N_sA)
        pi_surf = squeeze(sol.pi_pol(:, :, ih, tt));

        % Row 1: c surface
        nexttile(j);
        surf(SAgrid, LAmgrid, c_surf, 'EdgeColor','none','FaceAlpha',0.90);
        xlabel('s_A','FontSize',8); ylabel('\lambda','FontSize',8);
        zlabel('c','FontSize',8);  zlim([0 1]);
        title(sprintf('c  age %d  (s_H=%.2f)', age_j, p.sH_grid(ih)),'FontSize',9);
        colormap(gca, parula); caxis([0 1]);
        view(-40, 28); grid on; box on;

        % Row 2: π surface
        nexttile(n3 + j);
        surf(SAgrid, LAmgrid, pi_surf, 'EdgeColor','none','FaceAlpha',0.90);
        xlabel('s_A','FontSize',8); ylabel('\lambda','FontSize',8);
        zlabel('\pi','FontSize',8); zlim([0 1]);
        title(sprintf('\\pi  age %d  (s_H=%.2f)', age_j, p.sH_grid(ih)),'FontSize',9);
        colormap(gca, hot); caxis([0 1]);
        view(-40, 28); grid on; box on;
    end

    out = fullfile(out_dir, sprintf('fig_policy_3d_%s.png', short_names{k}));
    exportgraphics(fig, out, 'Resolution', 120);
    fprintf('Wrote %s\n', out);
    close(fig);
end
end % if RUN_ALL_SCENARIOS

%% =================== CROSS-SCENARIO COMPARISON (3×4) ===================
% Clean 12-panel figure: mean paths only, all 5 scenarios as coloured lines.
% Row 1: wealth & income levels (USD k)
% Row 2: portfolio & equity allocations (fractions / USD k)
% Row 3: state shares & annuity price

if RUN_ALL_SCENARIOS
% pre-compute equity fractions for each scenario
eq_frac_W_all   = cell(numel(files),1);
eq_frac_fin_all = cell(numel(files),1);
eq_priv_all     = cell(numel(files),1);
eq_pens_all     = cell(numel(files),1);
for k = 1:numel(files)
    [ep, epen, efW, effin, ~] = equity_exposure(S{k}.sim, S{k}.p, S{k}.profile);
    eq_frac_W_all{k}   = efW;
    eq_frac_fin_all{k} = effin;
    eq_priv_all{k}     = ep;
    eq_pens_all{k}     = epen;
end

fig = figure('Position', [40 40 1800 1100], 'Color','w');
tl  = tiledlayout(3, 4, 'Padding','compact','TileSpacing','compact');
title(tl, {'Five-scenario comparison — average lifecycle paths', ...
           'Each coloured line is the average across simulated households in that scenario'}, ...
      'FontSize',14,'FontWeight','bold');

% ── Row 1: levels in USD k ───────────────────────────────────────────────
% Net-worth components: liquid savings, pension balance, net housing equity
specs1 = {
    'C',        true,  'Consumption spending';
    'X',        true,  'Liquid savings';
    'A',        true,  'Pension account balance';
    'H_net',    true,  'Net housing equity';
};
for j = 1:4
    nexttile;
    field = specs1{j,1};  do_norm = specs1{j,2};  ttl = specs1{j,3};
    data = cellfun(@(s) s.sim.(field), S, 'UniformOutput', false);
    comp_lines(ages, data, colors, legend_names, do_norm, dscale, ret_age, j==1);
    xlabel('Age'); ylabel(dlbl); title(ttl);
end

% ── Row 2: portfolio & equity ─────────────────────────────────────────────
nexttile;
data = cellfun(@(s) s.sim.pi, S, 'UniformOutput', false);
comp_lines(ages, data, colors, legend_names, false, dscale, ret_age, false);
xlabel('Age'); ylabel('Stock share [0–1]'); title('Share of liquid savings invested in stocks');
ylim([0 1]);

nexttile;
comp_lines(ages, eq_frac_W_all, colors, legend_names, false, dscale, ret_age, false);
yline(pi_merton, 'r:', 'Merton fraction', ...
      'LabelHorizontalAlignment','left', 'LineWidth', 1.2, 'HandleVisibility', 'off');
xlabel('Age'); ylabel('Stock share [0–1]'); title('Stock exposure relative to total wealth');
ylim([0 1]);

nexttile;
comp_lines(ages, eq_frac_fin_all, colors, legend_names, false, dscale, ret_age, false);
xlabel('Age'); ylabel('Stock share [0–1]'); title('Stock exposure relative to savings and pension only');
ylim([0 1]);

nexttile;
data_disp = cellfun(@(s) s.sim.disp_inc, S, 'UniformOutput', false);
comp_lines(ages, data_disp, colors, legend_names, true, dscale, ret_age, false);
xlabel('Age'); ylabel(dlbl); title('Net disposable income');

% ── Row 3: wealth shares + annuity ─────────────────────────────────────────
nexttile;
data = cellfun(@(s) s.sim.sA, S, 'UniformOutput', false);
comp_lines(ages, data, colors, legend_names, false, dscale, ret_age, false);
xlabel('Age'); ylabel('Share of total wealth [0–1]'); title('Pension share of total wealth');
ylim([0 1]);

nexttile;
data = cellfun(@(s) s.sim.sH, S, 'UniformOutput', false);
comp_lines(ages, data, colors, legend_names, false, dscale, ret_age, false);
xlabel('Age'); ylabel('Share of total wealth [0–1]'); title('Housing share of total wealth');
ylim([0 1]);

nexttile;
data = cellfun(@(s) s.sim.c_frac, S, 'UniformOutput', false);
comp_lines(ages, data, colors, legend_names, false, dscale, ret_age, false);
xlabel('Age'); ylabel('Share of resources spent [0–1]'); title('Share of available resources spent on consumption');
ylim([0 1]);

% annuity price panel
nexttile; hold on; grid on;
for k = 1:numel(files)
    plot(ages, S{k}.ann_price(:).', '-','Color',colors{k},'LineWidth',1.9, ...
         'DisplayName', legend_names{k});
end
xline(ret_age,'k--','HandleVisibility','off');
xlabel('Age'); ylabel('Price per $1 of annual pension income');
title('Annuity price (cost of converting savings to lifetime income)');
legend('Location','best','FontSize',7,'Interpreter','none');

hide_axes_toolbars(fig);
exportgraphics(fig, fullfile(out_dir, 'fig_cross_scenario.png'), 'Resolution', 130);
fprintf('Wrote fig_cross_scenario.png\n');
close(fig);
end % if RUN_ALL_SCENARIOS

%% =================== RENTER VS OWNER (3×4) ==============================
% 12-panel comparison, organised in three themed rows:
%   Row 1 (cash flows):     consumption, disposable income, housing cost, liquid savings
%   Row 2 (wealth/housing): pension balance, housing detail, net worth, net worth + future income
%   Row 3 (risk-taking):    stock share of savings, of total wealth (vs benchmark), of savings+pension

% Look up indices dynamically so this works whether RUN_ALL_SCENARIOS loaded
% 2 or 5 scenarios.
renter_idx = find(strcmp(short_names, 'full_renter'));
owner_idx  = find(strcmp(short_names, 'full_owner'));
if isempty(renter_idx) || isempty(owner_idx)
fprintf('Skipping renter-vs-owner comparison: need both scenarios loaded.\n');
else
renter = S{renter_idx};  owner = S{owner_idx};
c_r = [0.55 0.25 0.65];   % purple = renter
c_o = [0.20 0.60 0.30];   % green  = owner
FS3  = 10; FT3 = 11; LFS3 = 9; LWD3 = 1.9;

fig = figure('Position', [30 30 2200 1300], 'Color','w');
tl  = tiledlayout(3, 4, 'Padding','compact','TileSpacing','compact');
title(tl, {'Renting vs owning a home: full lifecycle comparison', ...
           'Purple = renter, green = owner.  Lines show the average across simulated households; shaded bands show the 10th-90th percentile range'}, ...
      'FontSize', 14, 'FontWeight', 'bold');

% equity decompositions + human capital + total wealth W
[eq_priv_r, eq_pens_r, efW_r, effin_r, tau_path, HC_r, ~] = equity_exposure(renter.sim, renter.p, renter.profile);
[eq_priv_o, eq_pens_o, efW_o, effin_o, ~,        HC_o, ~] = equity_exposure(owner.sim,  owner.p,  owner.profile);
% Pension fund's stock allocation glide path is plan design, identical for
% renter and owner (both share the same kappa, tau_S schedule) -- one line.

% Net worth = liquid + pension + NET housing equity (H_net = H - mortgage; zero for renter)
TW_r  = renter.sim.X + renter.sim.A + renter.sim.H_net;
TW_o  = owner.sim.X  + owner.sim.A  + owner.sim.H_net;
TWHC_r = TW_r + HC_r;          % + value of future income
TWHC_o = TW_o + HC_o;

% Housing cost: renter pays rent; owner pays maintenance + mortgage payment
dd_r = disposable_decomp(renter.sim, renter.p);
dd_o = disposable_decomp(owner.sim,  owner.p);
HCOST_r = dd_r.rent;
HCOST_o = dd_o.maintenance + dd_o.mortgage;

% ── (a) Consumption spending ───────────────────────────────────────────
nexttile; hold on; grid on; box on;
plot_band(ages, renter.sim.C * dscale, c_r, 'Renter', LWD3);
plot_band(ages, owner.sim.C  * dscale, c_o, 'Owner',  LWD3);
xline(ret_age, 'k--', 'HandleVisibility', 'off');
xlabel('Age', 'FontSize', FS3); ylabel(dlbl, 'FontSize', FS3);
title('(a)  Consumption spending', 'FontSize', FT3);
legend('Location', 'northwest', 'FontSize', LFS3);
set(gca, 'FontSize', FS3);

% ── (b) Net disposable income ──────────────────────────────────────────
nexttile; hold on; grid on; box on;
plot_band(ages, renter.sim.disp_inc * dscale, c_r, 'Renter', LWD3);
plot_band(ages, owner.sim.disp_inc  * dscale, c_o, 'Owner',  LWD3);
xline(ret_age, 'k--', 'HandleVisibility', 'off');
xlabel('Age', 'FontSize', FS3); ylabel(dlbl, 'FontSize', FS3);
title('(b)  Disposable income', 'FontSize', FT3);
set(gca, 'FontSize', FS3);

% ── (c) Housing cost: rent vs. mortgage and maintenance ────────────────
nexttile; hold on; grid on; box on;
plot_band(ages, HCOST_r * dscale, c_r, 'Renter (rent payment)', LWD3);
plot_band(ages, HCOST_o * dscale, c_o, 'Owner (mortgage + maintenance)', LWD3);
xline(ret_age, 'k--', 'HandleVisibility', 'off');
xlabel('Age', 'FontSize', FS3); ylabel(dlbl, 'FontSize', FS3);
title('(c)  Housing cost: rent vs. mortgage and maintenance', 'FontSize', FT3);
legend('Location', 'best', 'FontSize', LFS3);
set(gca, 'FontSize', FS3);

% ── (d) Liquid savings ──────────────────────────────────────────────────
nexttile; hold on; grid on; box on;
plot_band(ages, renter.sim.X * dscale, c_r, 'Renter', LWD3);
plot_band(ages, owner.sim.X  * dscale, c_o, 'Owner',  LWD3);
xline(ret_age, 'k--', 'HandleVisibility', 'off');
xlabel('Age', 'FontSize', FS3); ylabel(dlbl, 'FontSize', FS3);
title('(d)  Liquid savings', 'FontSize', FT3);
set(gca, 'FontSize', FS3);

% ── (e) Pension account balance ─────────────────────────────────────────
nexttile; hold on; grid on; box on;
plot_band(ages, renter.sim.A * dscale, c_r, 'Renter', LWD3);
plot_band(ages, owner.sim.A  * dscale, c_o, 'Owner',  LWD3);
xline(ret_age, 'k--', 'HandleVisibility', 'off');
xlabel('Age', 'FontSize', FS3); ylabel(dlbl, 'FontSize', FS3);
title('(e)  Pension account balance', 'FontSize', FT3);
set(gca, 'FontSize', FS3);

% ── (f) Housing: home value, mortgage and net equity (owner only) ──────
nexttile; hold on; grid on; box on;
plot_band(ages, owner.sim.H         * dscale, [0.65 0.65 0.65], 'Owner: home value', LWD3);
plot_band(ages, owner.sim.M_balance * dscale, [0.82 0.25 0.25], 'Owner: mortgage balance owed', LWD3);
plot_band(ages, owner.sim.H_net     * dscale, c_o,              'Owner: net home equity', LWD3);
plot(ages, zeros(size(ages)), '--', 'Color', c_r, 'LineWidth', 1.6, ...
     'DisplayName', 'Renter: no housing equity (always zero)');
xline(ret_age, 'k--', 'HandleVisibility', 'off');
xlabel('Age', 'FontSize', FS3); ylabel(dlbl, 'FontSize', FS3);
title('(f)  Housing: home value, mortgage and net equity', 'FontSize', FT3);
legend('Location', 'best', 'FontSize', LFS3 - 1);
set(gca, 'FontSize', FS3);

% ── (g) Net worth: savings, pension and housing equity combined ────────
nexttile; hold on; grid on; box on;
plot_band(ages, TW_r * dscale, c_r, 'Renter', LWD3);
plot_band(ages, TW_o * dscale, c_o, 'Owner',  LWD3);
xline(ret_age, 'k--', 'HandleVisibility', 'off');
xlabel('Age', 'FontSize', FS3); ylabel(dlbl, 'FontSize', FS3);
title('(g)  Net worth: savings, pension and housing equity combined', 'FontSize', FT3);
set(gca, 'FontSize', FS3);

% ── (h) Total wealth (net worth + human capital) ────────────────────────
nexttile; hold on; grid on; box on;
plot_band(ages, TWHC_r * dscale, c_r, 'Renter: total wealth', LWD3);
plot_band(ages, TWHC_o * dscale, c_o, 'Owner: total wealth',  LWD3);
plot(ages, mean(HC_r, 1, 'omitnan') * dscale, '--', 'Color', c_r, 'LineWidth', 1.3, ...
     'DisplayName', 'Renter: human capital only');
plot(ages, mean(HC_o, 1, 'omitnan') * dscale, '--', 'Color', c_o, 'LineWidth', 1.3, ...
     'DisplayName', 'Owner: human capital only');
xline(ret_age, 'k--', 'HandleVisibility', 'off');
xlabel('Age', 'FontSize', FS3); ylabel(dlbl, 'FontSize', FS3);
title('(h)  Total wealth (net worth + human capital)', 'FontSize', FT3);
legend('Location', 'best', 'FontSize', LFS3 - 1);
set(gca, 'FontSize', FS3);

% ── (i) Stock share: household's liquid savings vs the pension fund ────
% pi_t is the household's own choice (renter vs owner, mean+band); tau_S(t)
% is the pension fund's glide path -- plan design, identical for both, so
% it is plotted once as a single deterministic line.
nexttile; hold on; grid on; box on;
plot_band(ages, renter.sim.pi, c_r, 'Renter: liquid savings (household choice)', LWD3);
plot_band(ages, owner.sim.pi,  c_o, 'Owner: liquid savings (household choice)',  LWD3);
plot(ages, tau_path, '--', 'Color', [0.35 0.35 0.35], 'LineWidth', LWD3, ...
     'DisplayName', 'Pension fund: stock share set by the plan''s glide path');
xline(ret_age, 'k--', 'HandleVisibility', 'off');
xlabel('Age', 'FontSize', FS3); ylabel('Stock share [0–1]', 'FontSize', FS3);
title('(i)  Stock share: household savings vs. the pension fund', 'FontSize', FT3);
legend('Location', 'best', 'FontSize', LFS3 - 1);
ylim([-0.02 1.02]);
set(gca, 'FontSize', FS3);

% ── (j) Stock exposure relative to total wealth (vs benchmark) ─────────
nexttile; hold on; grid on; box on;
plot_band(ages, efW_r, c_r, 'Renter', LWD3);
plot_band(ages, efW_o, c_o, 'Owner',  LWD3);
xline(ret_age, 'k--', 'HandleVisibility', 'off');
yline(pi_merton, 'r--', 'Merton fraction', ...
      'LabelHorizontalAlignment', 'left', 'LineWidth', 1.4, 'FontSize', FS3 - 1, ...
      'HandleVisibility', 'off');
xlabel('Age', 'FontSize', FS3); ylabel('Stock share [0–1]', 'FontSize', FS3);
title('(j)  Stock exposure relative to total wealth', 'FontSize', FT3);
ylim([0 1]);
set(gca, 'FontSize', FS3);

% ── (k) Stock exposure relative to savings and pension only ────────────
nexttile; hold on; grid on; box on;
plot_band(ages, effin_r, c_r, 'Renter', LWD3);
plot_band(ages, effin_o, c_o, 'Owner',  LWD3);
xline(ret_age, 'k--', 'HandleVisibility', 'off');
xlabel('Age', 'FontSize', FS3); ylabel('Stock share [0–1]', 'FontSize', FS3);
title('(k)  Stock exposure relative to savings and pension only', 'FontSize', FT3);
ylim([0 1]);
set(gca, 'FontSize', FS3);

% ── (l) Calibration comparison box ──────────────────────────────────────
nexttile; axis off;
ltv_o = NaN; if isfield(owner.p, 'LTV'), ltv_o = owner.p.LTV; end
tau_inc_o  = NaN; if isfield(owner.p, 'tau_inc'),      tau_inc_o  = owner.p.tau_inc;      end
tau_cg_b_o = NaN; if isfield(owner.p, 'tau_cg_bond'),  tau_cg_b_o = owner.p.tau_cg_bond;  end
tau_cg_s_o = NaN; if isfield(owner.p, 'tau_cg_stock'), tau_cg_s_o = owner.p.tau_cg_stock; end
box_txt = {
    '\bf Calibration (shared parameters) \rm';
    sprintf('CRRA coefficient \\gamma=%.0f   |   Discount factor \\beta=%.2f', owner.p.gamma, owner.p.beta);
    sprintf('DC contribution rate \\kappa=%.0f%%   |   AOW replacement rate=%.0f%%', 100*owner.p.kappa, 100*owner.p.replacement);
    sprintf('Risk-free rate r=%.1f%%   |   Equity return \\mu_S=%.1f%%   |   Equity volatility \\sigma_S=%.1f%%', 100*owner.p.r, 100*owner.p.mu_S_level, 100*owner.p.sigma_S_level);
    sprintf('Income tax \\tau_{inc}=%.0f%%   |   Capital-gains tax bond/stock=%.0f%%/%.0f%%', 100*tau_inc_o, 100*tau_cg_b_o, 100*tau_cg_s_o);
    '';
    '\bf Where renter and owner differ \rm';
    sprintf('Renter:  rent rate \\alpha=%.1f%% of home value p.a., builds no housing equity', 100*renter.p.alpha);
    sprintf('Owner:  LTV=%.0f%%,  mortgage rate r_m=%.1f%%,  maintenance \\theta=%.1f%%', 100*ltv_o, 100*owner.p.r_m, 100*owner.p.theta);
    sprintf('N=%d households per scenario,  ages %d-%d,  retirement age %d', renter.sim.N, owner.p.age0, owner.p.age0+owner.p.T-1, ret_age);
    sprintf('Merton fraction \\pi^{*}=%.2f', pi_merton);
};
text(0.02, 0.97, box_txt, 'Units', 'normalized', 'VerticalAlignment', 'top', ...
     'FontSize', FS3, 'Interpreter', 'tex');
title('(l)  Calibration', 'FontSize', FT3);

hide_axes_toolbars(fig);
exportgraphics(fig, fullfile(out_dir, sprintf('fig_renter_vs_owner%s.png', fig_tag)), 'Resolution', 130);
fprintf('Wrote fig_renter_vs_owner%s.png\n', fig_tag);
close(fig);
end % renter-vs-owner guard
%% =================== REDUCTION OVERLAY (1×3) ============================
if RUN_ALL_SCENARIOS
fig = figure('Position', [40 40 1600 480], 'Color','w');
tl  = tiledlayout(1, 3, 'Padding','compact','TileSpacing','compact');
title(tl, 'Reduction overlay: h\_mult=0 or \kappa=0 must reproduce parent dynamics', ...
      'FontSize',13,'FontWeight','bold','Interpreter','tex');

nexttile; hold on; grid on;
plot(ages, mean(S{1}.sim.A,1)*dscale, '-','Color',[0 0.3 0.7],'LineWidth',2.5,'DisplayName','pension-only');
plot(ages, mean(S{4}.sim.A,1)*dscale,'--','Color',[0.85 0.2 0.2],'LineWidth',1.7,'DisplayName','full renter');
plot(ages, mean(S{5}.sim.A,1)*dscale, ':','Color',[0.20 0.6 0.3],'LineWidth',1.7,'DisplayName','full owner');
xline(ret_age,'k--','HandleVisibility','off');
xlabel('Age'); ylabel(dlbl); title('DC pension A: reduction vs full');
legend('Location','best','FontSize',8);

nexttile; hold on; grid on;
plot(ages, mean(S{2}.sim.H,1)*dscale, '-','Color',[0.85 0.4 0.2],'LineWidth',2.5,'DisplayName','housing renter');
plot(ages, mean(S{3}.sim.H,1)*dscale, '-','Color',[0.85 0.65 0.15],'LineWidth',2.5,'DisplayName','housing owner');
plot(ages, mean(S{4}.sim.H,1)*dscale,'--','Color',[0.85 0.2 0.2],'LineWidth',1.7,'DisplayName','full renter');
plot(ages, mean(S{5}.sim.H,1)*dscale, ':','Color',[0.20 0.6 0.3],'LineWidth',1.7,'DisplayName','full owner');
xline(ret_age,'k--','HandleVisibility','off');
xlabel('Age'); ylabel(dlbl); title('Housing H: reduction vs full');
legend('Location','best','FontSize',8);

nexttile;
neg_pct = arrayfun(@(k) 100 * S{k}.sim.diagnostics.n_negLW / (S{k}.sim.N * S{k}.p.T), ...
                   1:numel(files));
b = bar(neg_pct,'FaceColor','flat');
for k = 1:numel(files), b.CData(k,:) = colors{k}; end
set(gca,'XTick',1:numel(files),'XTickLabel',legend_names,'XTickLabelRotation',30, ...
        'TickLabelInterpreter','none');
ylabel('% of N×T points'); title('Negative-LW frequency'); grid on;

hide_axes_toolbars(fig);
exportgraphics(fig, fullfile(out_dir, 'fig_reduction_overlay.png'), 'Resolution', 130);
fprintf('Wrote fig_reduction_overlay.png\n');
close(fig);
end % if RUN_ALL_SCENARIOS

fprintf('\nAll figures written.\n');

%% =================== HELPERS ============================================

function hide_axes_toolbars(fig)
% Suppress the interactive axes toolbar so exportgraphics doesn't bake it in.
axs = findall(fig, 'Type', 'axes');
for aa = 1:numel(axs)
    tb = axs(aa).Toolbar;
    if ~isempty(tb), tb.Visible = 'off'; end
end
end

function plot_band(x, M, color, name, lwd)
% Mean line + 10–90 percentile shaded band.  M is N×T.
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

function hc = housing_cost(sim, p)
% Per-household per-age housing cost in model (un-normalised) units.
[N, T] = size(sim.H);
hc = zeros(N, T);
for t = 1:T
    if p.is_owner
        m_t = 0;
        if t <= numel(p.m_rate_path), m_t = p.m_rate_path(t); end
        hc(:, t) = (p.theta + m_t) * sim.H(:, t);
    else
        hc(:, t) = p.alpha * sim.H(:, t);
    end
end
end

function d = disposable_decomp(sim, p)
% Decompose disposable income into its additive components (model units, N×T).
% Reconciles exactly to sim.disp_inc:
%   disp = takehome + annuity - (rent + maintenance + mortgage)
% Matches +simulate/paths.m's tax/contribution treatment: while working,
% takehome = (1-delta)(1-kappa)(1-tau_inc)*Y (gross Y less the wage haircut
% delta*Y, the pre-tax pension contribution kappa*Y, then income tax on the
% remainder); retired takehome = (1-delta)(1-tau_inc)*Y (AOW, taxed as
% income). The annuity payout is taxed the same way: sim.ann_pay stores the
% GROSS payout, so it is scaled by (1-tau_inc) here to match sim.disp_inc,
% which uses the NET payout. Housing cost split:
%   renter -> rent = alpha*H ;  owner -> maintenance = theta*H,
%   mortgage = m_rate_t*H (sim.m_pay, the solver's homothetic approximation).
% tau_inc/delta default to 0 for legacy p-structs that predate the tax model.
[N, T] = size(sim.Y);
is_ret = (1:T) >= p.t_ret;                       % 1×T logical, retired ages

tau_inc = 0; if isfield(p, 'tau_inc'), tau_inc = p.tau_inc; end
net_inc = 1 - tau_inc;

d.gross_Y = sim.Y;
d.tax     = zeros(N, T);                                    % income tax (=0 if tau_inc=0)
d.tax(:, ~is_ret) = (1 - p.delta) * (1 - p.kappa) * tau_inc .* sim.Y(:, ~is_ret);
d.tax(:, is_ret)  = (1 - p.delta) * tau_inc .* sim.Y(:, is_ret);

% Pension contribution kappa*Y (working only; funds the future DC annuity)
d.pension_contrib = zeros(N, T);
d.pension_contrib(:, ~is_ret) = p.kappa .* sim.Y(:, ~is_ret);

% Take-home labour / AOW income actually entering the budget (post income tax)
contrib_factor = repmat((1 - p.delta) * net_inc, N, T);
contrib_factor(:, ~is_ret) = (1 - p.delta) * (1 - p.kappa) * net_inc;
d.takehome = contrib_factor .* sim.Y;

d.annuity = net_inc .* sim.ann_pay;               % DC pension payout, net of income tax

% Housing cost components
d.rent        = zeros(N, T);
d.maintenance = zeros(N, T);
d.mortgage    = zeros(N, T);
if p.h_mult > 0
    if p.is_owner
        d.maintenance = p.theta .* sim.H;
        d.mortgage    = sim.m_pay;                % m_rate_t * H_t (model approx.)
    else
        d.rent        = p.alpha .* sim.H;
    end
end

% Net disposable income (reconciles to sim.disp_inc)
d.disp = d.takehome + d.annuity - (d.rent + d.maintenance + d.mortgage);
end

function [eq_priv, eq_pens, eq_frac_W, eq_frac_fin, tau_path, HC, W] = equity_exposure(sim, p, profile)
% Decompose equity exposure into private (π·X) and pension (τ_S·A) components.
% Returns N×T matrices for household-level quantities, T-vector tau_path, and
% the N×T human-capital matrix HC = Y_t * g_t (PV of future income, ex-current).
%
% Total-wealth denominator W replaces the single-period income flow Y_t with
% an HC-augmented gross-income wealth:
%   Y_total_{i,t} = Y_{i,t} + E_t[ sum_{s>t} Y_{i,s} * sp_t(s-t) / Rf^(s-t) ]
% with sp_t(k) = product of one-period survivals from t to t+k.
% Gross income is used so the pre-retirement κ·Y is captured (it funds the
% future DC annuity); post-retirement Y is the AOW flow. The DC annuity
% stream itself is captured in W through the book-value A_t term -- this
% avoids double-counting.
%
% Under the log-normal income process, conditional on Y_{i,t} the expectation
% E_t[Y_s] = Y_{i,t} * exp( sum_{u=t}^{s-1} mu_growth(u) + 0.5*sigma_l(u)^2 ),
% so the HC is linear in Y_{i,t}: HC_{i,t} = Y_{i,t} * g_t for a deterministic
% scale vector g_t (precomputed once below).

[N, T] = size(sim.X);

% Pension glide path: pad to length T (last entry 0 = fully de-risked at death)
tau_S_vec = [p.tau_S(:); zeros(max(0, T - numel(p.tau_S)), 1)];
tau_path  = tau_S_vec(1:T).';    % 1×T for plotting against ages

% Private equity: π_t * X_t
eq_priv = sim.pi .* sim.X;       % N×T

% Pension equity: τ_S(t) * A_t  (glide path is deterministic per household)
eq_pens = bsxfun(@times, sim.A, tau_path);   % N×T

% ---- HC scale factor g_t = E_t[ sum_{s>t} (Y_s/Y_t) * sp_t / Rf^k ] ----
Rf      = 1 + p.r;
p_surv  = profile.p_surv(:);
mu_grow = profile.mu_growth(:);     % length T-1: log-growth from t -> t+1
sig_l   = profile.sigma_l_log(:);   % length T-1: log-shock std (0 at retirement transition + post-ret)

% E_t[Y_s]/Y_t = exp( sum_{u=t}^{s-1} mu_grow(u) + 0.5*sig_l(u)^2 )
% Build prefix sums of (mu_grow + 0.5*sig_l^2) starting from each t.
log_step   = mu_grow + 0.5 .* sig_l.^2;        % T-1 x 1, log E[Y_{u+1}/Y_u]
% Cumulative from index 1 to any s: cum_log(s) = sum_{u=1}^{s-1} log_step(u),
% so E[Y_s]/Y_t = exp(cum_log(s) - cum_log(t)).
cum_log = [0; cumsum(log_step)];               % T x 1, indexed 1..T

g_t = zeros(T, 1);
for t = 1:T
    cs = 1;                                    % cumulative survival product
    pv = 0;
    for s = (t+1):T
        cs = cs * p_surv(s-1);                 % Pr(alive at s | alive at t)
        pv = pv + exp(cum_log(s) - cum_log(t)) * cs / Rf^(s - t);
    end
    g_t(t) = pv;
end
g_path = g_t.';                                % 1×T

% Human capital = PV of future income (excludes current Y_t): HC = Y_t * g_t
HC = sim.Y .* g_path;                          % N×T

% HC-augmented gross-income wealth: Y_t * (1 + g_t) = Y_t + HC
Y_total = sim.Y + HC;                          % N×T

% Total equity as fraction of total wealth W (with HC)
W = sim.X + sim.A + sim.H + Y_total;
eq_frac_W = (eq_priv + eq_pens) ./ max(W, 1e-10);

% Total equity as fraction of financial wealth only (X+A, excl. housing & HC).
% At age 20 (and early life) X+A is ~0, so the ratio is undefined: mask those
% household-periods with NaN so they are dropped from the mean/percentile band
% rather than plotting a spurious 0 or blow-up.
fin_raw     = sim.X + sim.A;
eq_frac_fin = (eq_priv + eq_pens) ./ fin_raw;
eq_frac_fin(fin_raw < 1e-6) = NaN;
end

function comp_lines(ages, data_cell, cols, leg_names, normalise, dscale, ret_age, show_legend)
% Plot 5 mean lines onto the current axes; optionally show legend.
hold on; grid on;
for kk = 1:numel(data_cell)
    m = mean(data_cell{kk}, 1, 'omitnan');
    if normalise, m = m * dscale; end
    plot(ages, m, '-','Color',cols{kk},'LineWidth',1.9,'DisplayName',leg_names{kk});
end
xline(ret_age,'k--','HandleVisibility','off');
if show_legend
    lg = legend('Location','best','FontSize',7);
    lg.Interpreter = 'none';
end
end

function sl = policy_slice(pol_4d, p, sim, tt, lam_idx, use_sA, has_housing, has_pension)
% Extract a 1D policy slice at fixed lambda and age tt.
% Varies over s_A (if use_sA) or s_H, fixing the other state at mean sim value.
if use_sA
    ih = 1;
    if has_housing
        sH_t = mean(sim.sH(:, tt));
        [~, ih] = min(abs(p.sH_grid - sH_t));
    end
    sl = squeeze(pol_4d(lam_idx, :, ih, tt));
else
    ia = 1;
    if has_pension
        sA_t = mean(sim.sA(:, tt));
        [~, ia] = min(abs(p.sA_grid - sA_t));
    end
    sl = squeeze(pol_4d(lam_idx, ia, :, tt));
end
end
