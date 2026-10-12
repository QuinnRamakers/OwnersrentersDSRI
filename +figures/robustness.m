function fig = robustness(ref, ref_label, groups, ttl, file)
%ROBUSTNESS  One page of a step's robustness runs against the reference.
%
%   figures.robustness(r_ref, ref_label, groups, title, file)
%
%   groups is a struct array with fields name (row title), rs (cell of
%   results) and labels (cell of names). One row per group, five columns:
%   consumption and liquid savings as % differences from the reference, the
%   liquid equity share (reference in black with its 10th-90th percentile
%   band) and its difference from the reference, and a box with each run's
%   settings, checks and largest gaps. Means across simulated households, all
%   with the reference's households and seed.

st = figures.style();
cols = st.series(1:5, :);
styles = {'-', '--', '-.', ':', '-'};
FS = 10; FT = 10.5; LFS = 8.5; LWD = 1.7;
d0 = figures.panel_data(ref); a = d0.ages; ret = ref.p.retirement_age;
C0 = mean(d0.C, 1); X0 = mean(d0.X, 1); P0 = mean(d0.pi, 1);
small = X0 < 1e-3 * max(X0);
w = 1:numel(a) - 1;

ng = numel(groups);
fig = figure('Visible', 'off', 'Position', [30 30 2400 470 * ng], 'Color', 'w');
tl  = tiledlayout(fig, ng, 5, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {ttl, ['Black = ' ref_label ' (the reference). Lines are means across simulated households; ' ...
    'the band is the reference''s 10th-90th percentile range']}, 'FontSize', 14, 'FontWeight', 'bold', ...
    'Interpreter', 'none');

for g = 1:ng
    G = groups(g); n = numel(G.rs);
    D = cellfun(@figures.panel_data, G.rs, 'UniformOutput', false);
    what = {'consumption, % difference', 'liquid savings, % difference', 'liquid equity share', ...
            'equity share, difference'};
    lt = @(k) sprintf('(%s)  %s: %s', char('a' + 5 * (g - 1) + k - 1), G.name, what{k});

    ax = tile(tl, ret, FS); yline(ax, 0, 'k-', 'LineWidth', 1.2, 'HandleVisibility', 'off');
    h = gobjects(1, n);
    for i = 1:n
        h(i) = plot(ax, a, 100 * (mean(D{i}.C, 1) ./ C0 - 1), styles{i}, 'Color', cols(i, :), 'LineWidth', LWD);
    end
    ylabel(ax, '% difference from black'); title(ax, lt(1), 'FontSize', FT);
    legend(ax, h, G.labels, 'Location', 'best', 'FontSize', LFS, 'Interpreter', 'none');

    ax = tile(tl, ret, FS); yline(ax, 0, 'k-', 'LineWidth', 1.2, 'HandleVisibility', 'off');
    for i = 1:n
        dx = 100 * (mean(D{i}.X, 1) ./ X0 - 1); dx(small) = NaN;
        plot(ax, a(2:end), dx(2:end), styles{i}, 'Color', cols(i, :), 'LineWidth', LWD);
    end
    ylabel(ax, '% difference from black'); title(ax, lt(2), 'FontSize', FT);

    ax = tile(tl, ret, FS);
    fill(ax, [a(w), fliplr(a(w))], [quantile(d0.pi(:, w), 0.1, 1), fliplr(quantile(d0.pi(:, w), 0.9, 1))], ...
        [0.85 0.85 0.85], 'EdgeColor', 'none', 'FaceAlpha', 0.6);
    for i = 1:n
        plot(ax, a(w), mean(D{i}.pi(:, w), 1), styles{i}, 'Color', cols(i, :), 'LineWidth', LWD);
    end
    plot(ax, a(w), P0(w), 'k-', 'LineWidth', 2.4);
    ylim(ax, [0 1.02]); ylabel(ax, 'Stock share [0-1]'); title(ax, lt(3), 'FontSize', FT);

    ax = tile(tl, ret, FS); yline(ax, 0, 'k-', 'LineWidth', 1.2, 'HandleVisibility', 'off');
    for i = 1:n
        plot(ax, a(w), mean(D{i}.pi(:, w), 1) - P0(w), styles{i}, 'Color', cols(i, :), 'LineWidth', LWD);
    end
    ylabel(ax, 'difference in share'); title(ax, lt(4), 'FontSize', FT);

    ax = nexttile(tl); axis(ax, 'off');
    L = {};
    for i = 1:n
        r = G.rs{i}; p = r.p; c = r.checks; s = r.summary;
        L{end+1} = G.labels{i}; %#ok<AGROW>
        L{end+1} = sprintf('  grid %dx%dx%d, gh %d, %s, sweep %d, %s, %.0f s', p.N_u1, p.N_u2, p.N_u3, p.gh_n, ...
            p.fmincon_algorithm, p.use_refine, pool_name(r), r.timing.solve_sec); %#ok<AGROW>
        L{end+1} = sprintf('  bound %.1f%%  floored %.2f%%  off-grid %d  entry value %.3g', ...
            100 * c.c_bound_25_39, 100 * c.floored_share, sum(c.offgrid), c.ce_entry); %#ok<AGROW>
        dx = abs(s.X.mean ./ ref.summary.X.mean - 1); dx(small) = NaN;
        L{end+1} = sprintf('  max |d pi| %.3f   |dC/C| %.2f%%   |dX/X| %.2f%%', ...
            max(abs(s.pi(w) - P0(w))), 100 * max(abs(s.C.mean ./ ref.summary.C.mean - 1)), ...
            100 * max(dx(2:end), [], 'omitnan')); %#ok<AGROW>
    end
    L = [{sprintf('reference: %s, %.0f s, entry value %.3g', pool_name(ref), ref.timing.solve_sec, ref.checks.ce_entry), ''}, L]; %#ok<AGROW>
    text(ax, 0, 1, L, 'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', FS - 1.5, ...
        'Interpreter', 'none', 'FontName', 'Consolas');
    title(ax, sprintf('(%s)  %s: settings and checks', char('a' + 5 * g - 1), G.name), 'FontSize', FT);
end

if nargin > 4 && ~isempty(file)
    axs = findall(fig, 'Type', 'axes');
    for i = 1:numel(axs)
        if ~isempty(axs(i).Toolbar), axs(i).Toolbar.Visible = 'off'; end
    end
    exportgraphics(fig, file, 'Resolution', 120);
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

function s = pool_name(r)
s = 'serial';
if isfield(r.timing, 'pool') && isfield(r.timing.pool, 'type')
    if contains(r.timing.pool.type, 'Thread'), s = 'threads';
    elseif contains(r.timing.pool.type, 'Process'), s = 'processes'; end
end
end
