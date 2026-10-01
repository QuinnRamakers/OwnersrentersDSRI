function plot_ablation(tag, out_png)
%PLOT_ABLATION  Render the CGM ablation ladder: where does pi(age) break?
%
%   plot_ablation()              % reads diagnostics/ablation_default.mat
%   plot_ablation(tag)
%   plot_ablation(tag, out_png)
%
%   Small multiples of mean pi(age), one panel per rung, because overlaying
%   seven sawtooth lines is unreadable. Underneath: the roughness statistic
%   split at retirement, and the consumption paths (smooth enough to overlay).
%
%   Read the pi panels as a sequence. Rung 0 is the CGM core, where the
%   published result is a share pinned at the 1.0 constraint while human
%   capital is large, falling smoothly as it runs out. The rung where the line
%   stops being smooth is the rung whose feature makes the choice indeterminate.

if nargin < 1 || isempty(tag), tag = 'default'; end
here = fileparts(mfilename('fullpath'));
S = load(fullfile(here, sprintf('ablation_%s.mat', tag)));
R = S.R;
n = numel(R);
if nargin < 2 || isempty(out_png)
    out_png = fullfile(here, sprintf('fig_ablation_%s.png', tag));
end

RET_C  = [0.55 0.55 0.60];
PI_C   = [0.20 0.35 0.70];
WORK_C = [0.20 0.35 0.70];
RETC   = [0.85 0.45 0.15];

fig = figure('Position', [60 60 1500 900], 'Color', 'w');
tl = tiledlayout(fig, 3, max(n, 4), 'TileSpacing', 'compact', 'Padding', 'compact');

% ---- row 1: pi(age) small multiples -----------------------------------------
ymin = 0; ymax = 1;
for k = 1:n
    d = R(k).diag;
    ax = nexttile(tl, k);
    hold(ax, 'on');
    ret_age = R(k).p.retirement_age;
    xline(ax, ret_age, '--', 'Color', RET_C, 'LineWidth', 1);
    plot(ax, d.ages, d.pi_mean, '-', 'Color', PI_C, 'LineWidth', 1.3);
    ylim(ax, [ymin ymax]); xlim(ax, [min(d.ages) max(d.ages)]);
    title(ax, sprintf('%s', d.label), 'FontWeight', 'bold', 'Interpreter', 'none');
    subtitle(ax, sprintf('accum %.4f  retired %.4f', ...
        d.r_accum, d.r_retired), 'FontSize', 8);
    if k == 1, ylabel(ax, 'mean \pi (liquid equity share)'); end
    xlabel(ax, 'age');
    grid(ax, 'on'); box(ax, 'on');
end

% ---- row 2: roughness by rung ------------------------------------------------
ax = nexttile(tl, max(n, 4) + 1, [1 max(n, 4)]);
labels = arrayfun(@(x) string(x.diag.label), R);
% Four phases, not two. The retirement TRANSITION is a legitimate kink (income
% drops discretely) and scores high on a second difference for a good reason;
% the final years are dominated by households whose wealth has gone. Only the
% accumulation and retired-proper bars speak to whether pi is well determined.
ra = arrayfun(@(x) x.diag.r_accum,      R);
rt = arrayfun(@(x) x.diag.r_transition, R);
rr = arrayfun(@(x) x.diag.r_retired,    R);
rl = arrayfun(@(x) x.diag.r_late,       R);
b = bar(ax, categorical(labels, labels), [ra(:) rt(:) rr(:) rl(:)], 'grouped');
b(1).FaceColor = WORK_C; b(2).FaceColor = [0.60 0.60 0.65];
b(3).FaceColor = RETC;   b(4).FaceColor = [0.45 0.30 0.55];
legend(ax, {'accumulation', 'retirement transition', 'retirement proper', 'final years'}, 'Location', 'northwest');
ylabel(ax, 'roughness  mean|\Delta^2 \pi|');
title(ax, 'Where does the equity share stop being smooth?');
grid(ax, 'on'); box(ax, 'on');

% ---- row 3: consumption + pi level -------------------------------------------
ax = nexttile(tl, 2 * max(n, 4) + 1, [1 2]);
hold(ax, 'on');
cmap = lines(n);
for k = 1:n
    d = R(k).diag;
    nc = min(numel(d.ages), numel(d.c_mean));
    plot(ax, d.ages(1:nc), d.c_mean(1:nc), '-', ...
        'Color', cmap(k,:), 'LineWidth', 1.2, 'DisplayName', d.label);
end
xlabel(ax, 'age'); ylabel(ax, 'mean consumption (EUR)');
title(ax, 'Consumption path (CGM: hump-shaped)');
legend(ax, 'Location', 'best', 'Interpreter', 'none', 'FontSize', 7);
grid(ax, 'on'); box(ax, 'on');

ax = nexttile(tl, 2 * max(n, 4) + 3, [1 2]);
hold(ax, 'on');
pe = arrayfun(@(x) x.diag.pi_early, R);
pm = arrayfun(@(x) x.diag.pi_mid,   R);
pl = arrayfun(@(x) x.diag.pi_late,  R);
plot(ax, 1:n, pe, '-o', 'LineWidth', 1.3, 'DisplayName', 'age 25-35');
plot(ax, 1:n, pm, '-s', 'LineWidth', 1.3, 'DisplayName', 'age 45-55');
plot(ax, 1:n, pl, '-^', 'LineWidth', 1.3, 'DisplayName', 'age 70-85');
set(ax, 'XTick', 1:n, 'XTickLabel', labels, 'TickLabelInterpreter', 'none');
ylim(ax, [0 1]); ylabel(ax, 'mean \pi'); xtickangle(ax, 30);
title(ax, 'Equity-share level by rung');
legend(ax, 'Location', 'best', 'FontSize', 7);
grid(ax, 'on'); box(ax, 'on');

title(tl, sprintf('CGM ablation ladder (%s): each rung switches one feature back on', tag), ...
    'FontWeight', 'bold', 'Interpreter', 'none');

exportgraphics(fig, out_png, 'Resolution', 140);
fprintf('Wrote %s\n', out_png);

% ---- console summary ---------------------------------------------------------
fprintf('\n%-12s %8s %8s %8s %8s %8s %8s %8s\n', ...
    'rung', 'accum', 'transit', 'retired', 'final', 'pi_early', 'pi_mid', 'pi_late');
fprintf('%s\n', repmat('-', 1, 84));
for k = 1:n
    d = R(k).diag;
    fprintf('%-12s %8.4f %8.4f %8.4f %8.4f %8.3f %8.3f %8.3f\n', ...
        d.label, d.r_accum, d.r_transition, d.r_retired, d.r_late, ...
        d.pi_early, d.pi_mid, d.pi_late);
end
end
