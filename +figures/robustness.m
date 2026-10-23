function fig = robustness(ref, ref_label, groups, ttl, file, ref_what)
%ROBUSTNESS  One page of a step's robustness runs against the step as solved.
%
%   figures.robustness(r_ref, ref_label, groups, title, file)
%   figures.robustness(..., ref_what)    % what black is, if not the step as solved
%
%   r_ref is the step as the ladder solved it (the reference, drawn in black
%   with its 10th-90th percentile band); ref_label describes its settings.
%   ref_what names the reference in the title and legend ('the step as
%   solved in the ladder' by default).
%   groups is a struct array with fields name (row title), rs (cell of
%   results) and labels (cell of names). One row per group, seven columns:
%   consumption, liquid savings and the liquid equity share, each as a level
%   and as a difference from the reference, then a box with each run's
%   settings, checks and largest gaps. Means across simulated households, all
%   with the reference's households and seed.

st = figures.style();
cols = st.series(1:5, :);
styles = {'-', '--', '-.', ':', '-'};
FS = 10; FT = 10.5; LFS = 8.5; LWD = 1.7;
d0 = figures.panel_data(ref); a = d0.ages; ret = ref.p.retirement_age; sc = d0.scale;
C0 = mean(d0.C, 1); X0 = mean(d0.X, 1); P0 = mean(d0.pi, 1);
small = X0 < 0.01 * max(X0);         % % gaps on near-zero savings say nothing
w = 1:numel(a) - 1;
if nargin < 6 || isempty(ref_what), ref_what = 'the step as solved in the ladder'; end
ref_name = sprintf('black: %s (reference)', erase(ref_what, ' in the ladder'));

ng = numel(groups);
fig = figure('Visible', 'off', 'Position', [30 30 3300 480 * ng], 'Color', 'w');
tl  = tiledlayout(fig, ng, 7, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {ttl, ['Black line = the reference: ' ref_what ', ' ref_label ...
    '. Grey band = its 10th-90th percentile range. Coloured lines = the same step solved another way. ' ...
    'All lines are means across the same simulated households']}, 'FontSize', 14, 'FontWeight', 'bold', ...
    'Interpreter', 'none');

for g = 1:ng
    G = groups(g); n = numel(G.rs);
    D = cellfun(@figures.panel_data, G.rs, 'UniformOutput', false);
    letter = @(k) panel_letter(7 * (g - 1) + k);

    % Consumption: level, then % difference
    ax = tile(tl, ret, FS);
    ref_band(ax, a, d0.C * sc);
    hy = income_lines(ax, d0, sc);
    h = gobjects(1, n + 1);
    h(1) = plot(ax, a, C0 * sc, 'k-', 'LineWidth', 2.4);
    for i = 1:n
        h(i + 1) = plot(ax, a, mean(D{i}.C, 1) * sc, styles{i}, 'Color', cols(i, :), 'LineWidth', LWD);
    end
    ylabel(ax, d0.unit); title(ax, sprintf('(%s)  %s: consumption and income', letter(1), G.name), 'FontSize', FT);
    legend(ax, [h, hy], [{ref_name}, G.labels, {'gross income', 'income after tax, contributions and housing'}], ...
        'Location', 'northwest', 'FontSize', LFS, 'Interpreter', 'none');

    ax = diff_tile(tl, ret, FS);
    for i = 1:n
        plot(ax, a, 100 * (mean(D{i}.C, 1) ./ C0 - 1), styles{i}, 'Color', cols(i, :), 'LineWidth', LWD);
    end
    ylabel(ax, '% difference from black');
    title(ax, sprintf('(%s)  %s: consumption, %% difference', letter(2), G.name), 'FontSize', FT);

    % Liquid savings: level, then % difference
    ax = tile(tl, ret, FS);
    ref_band(ax, a, d0.X * sc);
    plot(ax, a, X0 * sc, 'k-', 'LineWidth', 2.4);
    for i = 1:n
        plot(ax, a, mean(D{i}.X, 1) * sc, styles{i}, 'Color', cols(i, :), 'LineWidth', LWD);
    end
    ylabel(ax, d0.unit); title(ax, sprintf('(%s)  %s: liquid savings', letter(3), G.name), 'FontSize', FT);

    ax = diff_tile(tl, ret, FS);
    for i = 1:n
        dx = 100 * (mean(D{i}.X, 1) ./ X0 - 1); dx(small) = NaN;
        plot(ax, a(2:end), dx(2:end), styles{i}, 'Color', cols(i, :), 'LineWidth', LWD);
    end
    ylabel(ax, '% difference from black');
    title(ax, sprintf('(%s)  %s: liquid savings, %% difference', letter(4), G.name), 'FontSize', FT);

    % Liquid equity share: level, then difference
    ax = tile(tl, ret, FS);
    ref_band(ax, a(w), d0.pi(:, w));
    plot(ax, a(w), P0(w), 'k-', 'LineWidth', 2.4);
    for i = 1:n
        plot(ax, a(w), mean(D{i}.pi(:, w), 1), styles{i}, 'Color', cols(i, :), 'LineWidth', LWD);
    end
    ylim(ax, [0 1.02]); ylabel(ax, 'Stock share [0-1]');
    title(ax, sprintf('(%s)  %s: liquid equity share', letter(5), G.name), 'FontSize', FT);

    ax = diff_tile(tl, ret, FS);
    for i = 1:n
        plot(ax, a(w), mean(D{i}.pi(:, w), 1) - P0(w), styles{i}, 'Color', cols(i, :), 'LineWidth', LWD);
    end
    ylabel(ax, 'difference from black, share');
    title(ax, sprintf('(%s)  %s: equity share, difference', letter(6), G.name), 'FontSize', FT);

    % Settings and checks
    ax = nexttile(tl); axis(ax, 'off');
    L = [{sprintf('black (reference): %s', erase(ref_what, ' in the ladder'))}, strcat({'  '}, strsplit(ref_label, ', ')), ...
         {sprintf('  %s, %.0f s, entry value %.3g', pool_name(ref), ref.timing.solve_sec, ref.checks.ce_entry), ''}];
    for i = 1:n
        r = G.rs{i}; p = r.p; c = r.checks; s = r.summary;
        L{end+1} = G.labels{i}; %#ok<AGROW>
        L{end+1} = sprintf('  grid %dx%dx%d, gh %d, %s, sweep %d, %s, %.0f s', p.N_u1, p.N_u2, p.N_u3, p.gh_n, ...
            p.fmincon_algorithm, p.use_refine, pool_name(r), r.timing.solve_sec); %#ok<AGROW>
        [~, fl] = model.floor_kind(p);
        L{end+1} = sprintf('  bound %.1f%%  %s %.2f%%  off-grid %d  entry value %.3g', ...
            100 * c.c_bound_25_39, fl, 100 * c.floored_share, sum(c.offgrid), c.ce_entry); %#ok<AGROW>
        dx = abs(s.X.mean ./ ref.summary.X.mean - 1); dx(small) = NaN;
        L{end+1} = sprintf('  largest gap: pi %.3f  C %.2f%%  X %.2f%%', ...
            max(abs(s.pi(w) - P0(w))), 100 * max(abs(s.C.mean ./ ref.summary.C.mean - 1)), ...
            100 * max(dx(2:end), [], 'omitnan')); %#ok<AGROW>
    end
    text(ax, 0, 1, L, 'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', FS - 1.5, ...
        'Interpreter', 'none', 'FontName', 'Consolas');
    title(ax, sprintf('(%s)  %s: settings and checks', letter(7), G.name), 'FontSize', FT);
end

if nargin > 4 && ~isempty(file)
    axs = findall(fig, 'Type', 'axes');
    for i = 1:numel(axs)
        if ~isempty(axs(i).Toolbar), axs(i).Toolbar.Visible = 'off'; end
    end
    exportgraphics(fig, file, 'Resolution', 110);
    close(fig);
end
end

% ------------------------------------------------------------------------
function ax = tile(tl, ret, FS)
ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
ax.FontSize = FS; ax.XLim = [25 100];
xline(ax, ret, 'k--', 'HandleVisibility', 'off');
xlabel(ax, 'Age');
end

function ax = diff_tile(tl, ret, FS)
% A difference panel: the black zero line is the reference.
ax = tile(tl, ret, FS);
yline(ax, 0, 'k-', 'black = reference', 'LineWidth', 1.6, 'LabelHorizontalAlignment', 'left', ...
    'FontSize', 8, 'HandleVisibility', 'off');
end

function ref_band(ax, x, M)
fill(ax, [x, fliplr(x)], [quantile(M, 0.1, 1), fliplr(quantile(M, 0.9, 1))], [0.85 0.85 0.85], ...
    'EdgeColor', 'none', 'FaceAlpha', 0.6, 'HandleVisibility', 'off');
end

function s = pool_name(r)
s = 'serial';
if isfield(r.timing, 'pool') && isfield(r.timing.pool, 'type')
    if contains(r.timing.pool.type, 'Thread'), s = 'threads';
    elseif contains(r.timing.pool.type, 'Process'), s = 'processes'; end
end
end

function h = income_lines(ax, d, sc)
% Mean gross income and income after tax, contributions and housing costs of
% the reference households, as thin grey lines behind consumption.
c = [0.45 0.45 0.45];
h(1) = plot(ax, d.ages, mean(d.Y, 1) * sc, '--', 'Color', c, 'LineWidth', 1.3);
h(2) = plot(ax, d.ages, mean(d.disp_inc, 1) * sc, ':', 'Color', c, 'LineWidth', 1.6);
end

function s = panel_letter(i)
% a, b, ..., z, then aa, ab, ...
if i <= 26, s = char('a' + i - 1); else, s = [char('a' + floor((i - 1) / 26) - 1), char('a' + mod(i - 1, 26))]; end
end
