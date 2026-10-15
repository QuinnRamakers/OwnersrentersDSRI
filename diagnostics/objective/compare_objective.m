function T = compare_objective(steps, opts)
%COMPARE_OBJECTIVE  Each ladder step solved with fmincon on both objectives.
%
%   T = compare_objective()          steps 1-7 and 9-12 at standard numerics
%   T = compare_objective([1 7])
%   T = compare_objective([], figures=false)   solve and tabulate only
%
%   Every arm of every step is solved twice, with p.fmincon_objective =
%   'utility' (the objective in utility units divided by a median, as before
%   15 October 2026) and 'ce' (certainty-equivalent units relative to the
%   seed). Everything else is the same, including the consumption bounds of 15
%   October. Results go to <numerics dir>/objective/ (reused when present),
%   with an overlay per arm, a summary page, and objective_comparison.pdf.
%   Returns the largest gaps between the two over ages 26-95.

arguments
    steps double = []
    opts.figures (1,1) logical = true
end
if isempty(steps), steps = [1:7, 9:12]; end
repo = fileparts(fileparts(fileparts(mfilename('fullpath'))));
cd(repo);
setenv('CGM_OUTPUT_DIR', ''); setenv('CGM_STATE_GRID', ''); setenv('CGM_GH_N', '');
S = ladder.steps(); num = ladder.numerics('standard');
out = fullfile(num.dir, 'objective');
if ~isfolder(out), mkdir(out); end
objs = {'utility', 'ce'};

T = table(); pages = {};
for k = steps
    p = ladder.params(k); p.grid_dims = num.dims; p.gh_n = num.gh_n; p = config.derive(p);
    arms = {false};
    if model.tenures_differ(p), arms = {false, true}; end
    for a = 1:numel(arms)
        r = cell(1, 2);
        for j = 1:2
            pa = p; pa.is_owner = arms{a}; pa.fmincon_objective = objs{j}; pa = config.derive(pa);
            ten = model.tenure(pa);
            file = fullfile(out, sprintf('%02d_%s_%s_%s.mat', k, S(k).name, ten, objs{j}));
            if isfile(file)
                r{j} = load(file);
            else
                r{j} = model.run(pa, N_sim = num.N_sim, verbose = false);
                rr = r{j}; save(file, '-struct', 'rr');
            end
        end
        s0 = r{1}.summary; s1 = r{2}.summary; ag = s0.ages; w = ag > 25 & ag <= 95; w2 = ag(1:end-1) > 25;
        dpi = abs(s1.pi(1:end-1) - s0.pi(1:end-1));
        dC  = abs(s1.C.mean ./ s0.C.mean - 1);
        dX  = abs(s1.X.mean - s0.X.mean) ./ s0.Y.mean;
        dpol = abs(r{2}.sol.pi_pol - r{1}.sol.pi_pol); dcp = abs(r{2}.sol.c_pol - r{1}.sol.c_pol);
        dce = (r{2}.sol.V ./ r{1}.sol.V) .^ (1 / (1 - p.gamma)) - 1;   % value gap in certainty-equivalent terms
        better = mean(dce(:) > 1e-3); worse = mean(dce(:) < -1e-3);
        sav = s0.X.mean(1:end-1) ./ s0.Y.mean(1:end-1); dps = dpi; dps(~w2 | sav < 0.05) = 0;
        T = [T; table(k, string(S(k).name), string(ten), max(dpi(w2)), max(dps), 100 * max(dC(w)), max(dX(w)), ...
            max(dpol(:)), max(dcp(:)), 100 * better, 100 * worse, ...
            100 * r{1}.checks.floored_share, 100 * r{2}.checks.floored_share, ...
            r{1}.timing.solve_sec, r{2}.timing.solve_sec, ...
            'VariableNames', {'step', 'name', 'tenure', 'max_dpi', 'max_dpi_saving', 'max_dC_pct', 'max_dX_inc', ...
            'max_dpi_grid', 'max_dc_grid', 'V_higher_pct', 'V_lower_pct', 'floored_util_pct', ...
            'floored_ce_pct', 'solve_util_s', 'solve_ce_s'})]; %#ok<AGROW>
        png = fullfile(out, sprintf('compare_%02d_%s_%s.png', k, S(k).name, ten));
        if opts.figures && ~isfile(png)
            figures.compare(r, {'utility objective (before)', 'certainty-equivalent objective (now)'}, ...
                sprintf('Step %d %s, %s: the fmincon objective in utility against certainty-equivalent units', ...
                k, S(k).name, ten), png);
            close all
        end
        pages{end+1} = png; %#ok<AGROW>
        fprintf('step %2d %-12s %-18s max|d pi| %.4f  max|dC| %.3f%%  V higher at %.1f%% of grid points, lower at %.1f%%  solve %4.0f -> %4.0f s\n', ...
            k, S(k).name, ten, T.max_dpi(end), T.max_dC_pct(end), T.V_higher_pct(end), T.V_lower_pct(end), ...
            T.solve_util_s(end), T.solve_ce_s(end));
    end
end

if ~opts.figures, return; end

% Summary page
lab = strcat(string(T.step), " ", T.name, " ", erase(T.tenure, "nohousing_"));
fig = figure('Visible', 'off', 'Position', [30 30 2100 1100], 'Color', 'w');
tl = tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {'The fmincon objective in certainty-equivalent units against utility units, every step and arm', ...
    'Largest gaps over ages 26-95 in means across the same simulated households; standard numerics'}, ...
    'FontSize', 13, 'FontWeight', 'bold');
x = categorical(lab, lab);
ax = nexttile(tl); bar(ax, x, [T.max_dpi, T.max_dpi_saving]); grid(ax, 'on');
legend(ax, {'all ages 26-95', 'ages where mean liquid savings are at least 0.05 years of income'}, 'Location', 'northwest');
ylabel(ax, 'largest gap in the mean liquid equity share'); title(ax, '(a)  Equity share');
ax = nexttile(tl); bar(ax, x, T.max_dC_pct); grid(ax, 'on');
ylabel(ax, 'largest gap in mean consumption (%)'); title(ax, '(b)  Consumption');
ax = nexttile(tl); bar(ax, x, [T.V_higher_pct, T.V_lower_pct]); grid(ax, 'on');
ylabel(ax, '% of grid points'); legend(ax, {'higher with the new objective', 'lower with the new objective'}, 'Location', 'northwest');
title(ax, '(c)  Grid points where the value differs by more than 0.1% (certainty-equivalent terms)');
ax = nexttile(tl); bar(ax, x, [T.solve_util_s, T.solve_ce_s]); grid(ax, 'on');
ylabel(ax, 'solve time (s)'); legend(ax, {'utility objective', 'certainty-equivalent objective'}, 'Location', 'northwest');
title(ax, '(d)  Solve time');
sumpng = fullfile(out, 'objective_summary.png');
exportgraphics(fig, sumpng, 'Resolution', 120); close(fig);

% PDF
pdf = fullfile(out, 'objective_comparison.pdf');
if isfile(pdf), delete(pdf); end
L = {sprintf('%-30s %7s %9s %8s %7s %8s %8s %12s', 'step and arm', 'd pi', 'd pi sav', 'd C %', 'd X', 'V high', 'V low', 'solve (s)')};
for i = 1:height(T)
    L{end+1} = sprintf('%-30s %7.3f %9.3f %8.3f %7.3f %7.2f%% %7.2f%% %5.0f -> %4.0f', lab(i), T.max_dpi(i), T.max_dpi_saving(i), ...
        T.max_dC_pct(i), T.max_dX_inc(i), T.V_higher_pct(i), T.V_lower_pct(i), T.solve_util_s(i), T.solve_ce_s(i)); %#ok<AGROW>
end
cover(pdf, 'The fmincon objective: certainty-equivalent against utility units', [{ ...
    'Each step and arm solved twice at standard numerics, identical except for what fmincon minimises:', ...
    '  utility: the Bellman objective divided by the median |V| of next period (before 15 October 2026)', ...
    '  certainty-equivalent: -(rhs / rhs_seed)^(1/(1-gamma)), equal to -1 at the seed at every node (now)', ...
    'Same optimum in theory; the sweep is unchanged. Consumption from the floor to all liquid resources in both.', '', ...
    'Largest gaps over ages 26-95 (d pi: mean liquid equity share; d pi sav: the same at ages where mean liquid', ...
    'savings are at least 0.05 years of income; d C: mean consumption; d X: mean liquid savings in years of', ...
    'income), and the share of grid points where the value differs by more than 0.1% in certainty-equivalent', 'terms, higher or lower with the new objective:', ''}, L]);
add_png(pdf, sumpng);
for i = 1:numel(pages)
    if isfile(pages{i}), add_png(pdf, pages{i}); end
end
writetable(T, fullfile(out, 'objective_comparison.csv'));
fprintf('wrote %s (%.1f MiB)\n', pdf, dir(pdf).bytes / 2^20);
end

% ------------------------------------------------------------------------
function cover(pdf, ttl, lines)
fig = figure('Visible', 'off', 'Position', [0 0 1600 1000], 'Color', 'w');
ax = axes(fig, 'Position', [0.04 0.04 0.92 0.90]); axis(ax, 'off');
text(ax, 0, 1, ttl, 'FontSize', 20, 'FontWeight', 'bold', 'VerticalAlignment', 'top', 'Interpreter', 'none');
text(ax, 0, 0.93, lines, 'FontSize', 11, 'VerticalAlignment', 'top', 'Interpreter', 'none', 'FontName', 'Consolas');
exportgraphics(fig, pdf, 'Append', true, 'ContentType', 'image', 'Resolution', 100);
close(fig);
end

function add_png(pdf, file)
I = imread(file);
[h, w, ~] = size(I);
fig = figure('Visible', 'off', 'Position', [0 0 round(w / 1.3) round(h / 1.3)], 'Color', 'w');
ax = axes(fig, 'Position', [0 0 1 1]);
image(ax, I); axis(ax, 'image', 'off');
exportgraphics(fig, pdf, 'Append', true, 'ContentType', 'image', 'Resolution', 120);
close(fig);
end
