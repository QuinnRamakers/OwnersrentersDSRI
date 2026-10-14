function occupancy(numerics)
%OCCUPANCY  Where households live on the state grid, age by age.
%
%   occupancy()               % standard numerics
%
%   For steps 6 and 9-12, from each saved result's simulated panel. Writes, in
%   <numerics dir>/robustness/:
%     occupancy_<arm>.png        per step (columns): the households' density on
%                                u1 and on u2 by age, with the grid points of the
%                                standard grid (grey lines) and of the bunched grid
%                                (grid_pow 2, grid_pow_u2 2; red dashes), and the
%                                number of grid points inside the band where the
%                                middle 90% of households live
%     occupancy_joint_<arm>.png  steps 9-12 (rows) at five ages (columns): a sample
%                                of households on (u1, u2) with the grid lattice
%   The same points serve every age; the shading is the share of households at
%   that age, scaled to the age's largest bin so that every age is visible.

if nargin < 1, numerics = 'standard'; end
num = ladder.numerics(numerics); S = ladder.steps(); d = fullfile(num.dir, 'robustness');
steps = [6 9 10 11 12];
snap_ages = [35 50 62 66 75];
cmap = [linspace(1, 0.10, 256).', linspace(1, 0.30, 256).', linspace(1, 0.60, 256).'];
grey = [0.45 0.45 0.45]; red = [0.80 0.15 0.15];
yt = [0.001 0.003 0.01 0.03 0.1 0.3 1];
ytl = arrayfun(@(u) sprintf('%g  (%s)', u, years(u)), yt, 'UniformOutput', false);

for arm = {'nohousing_renter', 'nohousing_owner'}
    a = arm{1};
    D = struct('k', {}, 'p', {}, 'pb', {}, 'ages', {}, 'u1', {}, 'u2', {});
    for k = steps
        f = ladder.result_file(num, k, S(k).name, a);
        if ~isfile(f), continue; end
        r = load(f);
        s = figures.panel_data(r).sim;
        pb = r.p; pb.grid_pow = 2; pb.grid_pow_u2 = 2; pb = config.derive(pb);
        u1 = s.lambda; u2 = (s.sA + s.sH) ./ max(1 - u1, 1e-12);
        D(end+1) = struct('k', k, 'p', r.p, 'pb', pb, 'ages', s.ages(:).', 'u1', u1, 'u2', u2); %#ok<AGROW>
    end
    n = numel(D);

    % Page 1: density by age per axis, and grid points inside the occupied band
    fig = figure('Visible', 'off', 'Position', [20 20 600 * n 1350], 'Color', 'w');
    tl = tiledlayout(fig, 3, n, 'Padding', 'compact', 'TileSpacing', 'compact');
    title(tl, {sprintf('Where %s households live on the grid, age by age', erase(a, 'nohousing_')), ...
        ['Shading: share of households at each age (darker = more). Black lines: grid points of the ' ...
         'standard grid [16 16 10]. Red dashes: the same number of points bunched (grid\_pow 2, grid\_pow\_u2 2). ' ...
         'The same points serve every age. Orange: the median household.']}, 'FontSize', 14, 'FontWeight', 'bold');
    for i = 1:n
        x = D(i); ttl = sprintf('%d %s', x.k, S(x.k).name);
        % u1 on a log scale, labelled with total resources in years of income
        ax = nexttile(tl, i); hold(ax, 'on');
        edges = linspace(log10(4e-4), 0, 121);
        heat(ax, x.ages, edges, log10(max(x.u1, 4e-4)), cmap);
        nodes(ax, log10(x.p.u1_grid), [0 0 0], '-'); nodes(ax, log10(x.pb.u1_grid), red, '--');
        plot(ax, x.ages, log10(median(x.u1, 1)), '-', 'Color', [0.95 0.65 0.10], 'LineWidth', 2);
        set(ax, 'YTick', log10(yt), 'YTickLabel', ytl, 'FontSize', 9); ylim(ax, edges([1 end]));
        xlim(ax, [25 100]); xline(ax, x.p.retirement_age, 'k:');
        title(ax, {ttl, 'u1 = income / total resources (years of income)'}, 'FontSize', 11, 'Interpreter', 'none');
        if i == 1, ylabel(ax, 'u1, log scale'); end
        % u2
        ax = nexttile(tl, n + i); hold(ax, 'on');
        if numel(x.p.u2_grid) <= 2 && all(x.u2(:) < 1e-9)
            text(ax, 0.5, 0.5, {'No pension account:', 'u2 = 0 for everyone', '(axis collapsed)'}, ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', grey);
            axis(ax, 'off');
        else
            edges = linspace(0, 1, 101);
            heat(ax, x.ages, edges, x.u2, cmap);
            nodes(ax, x.p.u2_grid, [0 0 0], '-'); nodes(ax, x.pb.u2_grid, red, '--');
            plot(ax, x.ages, median(x.u2, 1), '-', 'Color', [0.95 0.65 0.10], 'LineWidth', 2);
            ylim(ax, [0 1]); xlim(ax, [25 100]); xline(ax, x.p.retirement_age, 'k:'); ax.FontSize = 9;
            title(ax, 'u2 = pension account / (pension + liquid savings)', 'FontSize', 11);
            if i == 1, ylabel(ax, 'u2'); end
        end
        xlabel(ax, 'Age');
        % grid points inside the middle-90% band, per age
        ax = nexttile(tl, 2 * n + i); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = 9;
        h = gobjects(1, 4);
        h(1) = plot(ax, x.ages, inband(x.u1, x.p.u1_grid), '-', 'Color', 'k', 'LineWidth', 1.6);
        h(2) = plot(ax, x.ages, inband(x.u1, x.pb.u1_grid), '-', 'Color', red, 'LineWidth', 1.6);
        if numel(x.p.u2_grid) > 2
            h(3) = plot(ax, x.ages, inband(x.u2, x.p.u2_grid), ':', 'Color', 'k', 'LineWidth', 1.8);
            h(4) = plot(ax, x.ages, inband(x.u2, x.pb.u2_grid), ':', 'Color', red, 'LineWidth', 1.8);
        end
        yline(ax, 2, '-', 'two points', 'Color', grey, 'LabelHorizontalAlignment', 'left', 'FontSize', 8);
        xlim(ax, [25 100]); ylim(ax, [0 inf]); xline(ax, x.p.retirement_age, 'k:'); xlabel(ax, 'Age');
        title(ax, 'Grid points inside the middle-90% band', 'FontSize', 11);
        if i == 1
            ylabel(ax, 'number of grid points');
            legend(ax, h(1:2), {'u1, standard', 'u1, bunched'}, 'Location', 'northeast', 'FontSize', 8);
        elseif isgraphics(h(3))
            legend(ax, h, {'u1, standard', 'u1, bunched', 'u2, standard', 'u2, bunched'}, ...
                'Location', 'northeast', 'FontSize', 8);
        end
    end
    out = fullfile(d, sprintf('occupancy_%s.png', a));
    exportgraphics(fig, out, 'Resolution', 110); close(fig);
    fprintf('wrote %s\n', out);

    % Page 2: households on (u1, u2) at a few ages, with the lattice
    J = D([D.k] >= 9);
    fig = figure('Visible', 'off', 'Position', [20 20 2300 450 * numel(J)], 'Color', 'w');
    tl = tiledlayout(fig, numel(J), numel(snap_ages), 'Padding', 'compact', 'TileSpacing', 'compact');
    title(tl, {sprintf('Households on the two live axes at five ages (%s; 1,500 of 10,000 shown)', erase(a, 'nohousing_')), ...
        ['Black: the standard grid lattice. Red dashes: the bunched grid. Each dot is a household at the start of ' ...
         'the year. Each panel is zoomed to where its households are.']}, ...
        'FontSize', 14, 'FontWeight', 'bold');
    rng(1); pick = randperm(size(J(1).u1, 1), 1500);
    for i = 1:numel(J)
        for j = 1:numel(snap_ages)
            x = J(i); t = snap_ages(j) - x.p.age0 + 1;
            ax = nexttile(tl); hold(ax, 'on'); box(ax, 'on'); ax.FontSize = 9;
            u1 = max(x.u1(:, t), 4e-4); u2 = x.u2(:, t);
            xl = log10([max(4e-4, prctile(u1, 0.5) / 1.6), min(1, prctile(u1, 99.5) * 1.6)]);
            yl = [max(0, prctile(u2, 0.5) - 0.08), 1.005];
            for v = x.p.u1_grid.', plot(ax, log10([v v]), [0 1.1], '-', 'Color', [0 0 0 0.55], 'LineWidth', 1); end
            for v = x.p.u2_grid.', plot(ax, log10([4e-4 1]), [v v], '-', 'Color', [0 0 0 0.55], 'LineWidth', 1); end
            for v = x.pb.u1_grid.', plot(ax, log10([v v]), [0 1.1], '--', 'Color', [red 0.7], 'LineWidth', 1); end
            for v = x.pb.u2_grid.', plot(ax, log10([4e-4 1]), [v v], '--', 'Color', [red 0.7], 'LineWidth', 1); end
            scatter(ax, log10(u1(pick)), u2(pick), 7, [0.10 0.30 0.60], 'filled', 'MarkerFaceAlpha', 0.35);
            xlim(ax, xl); ylim(ax, yl);
            tk = [0.001 0.002 0.005 0.01 0.02 0.05 0.1 0.2 0.5 1];
            tk = tk(log10(tk) >= xl(1) & log10(tk) <= xl(2));
            set(ax, 'XTick', log10(tk), 'XTickLabel', arrayfun(@(u) sprintf('%g\n%s', u, years(u)), tk, ...
                'UniformOutput', false));
            title(ax, sprintf('%d %s, age %d', x.k, S(x.k).name, snap_ages(j)), 'FontSize', 10, 'Interpreter', 'none');
            if j == 1, ylabel(ax, 'u2 (pension share)'); end
            if i == numel(J), xlabel(ax, 'u1 (income / total resources), log scale'); end
        end
    end
    out = fullfile(d, sprintf('occupancy_joint_%s.png', a));
    exportgraphics(fig, out, 'Resolution', 110); close(fig);
    fprintf('wrote %s\n', out);
end
end

% ------------------------------------------------------------------------
function heat(ax, ages, edges, U, cmap)
% Share of households per bin at each age, scaled to each age's largest bin.
M = zeros(numel(edges) - 1, numel(ages));
for t = 1:numel(ages)
    c = histcounts(U(:, t), edges);
    M(:, t) = c / max(max(c), 1);
end
mid = (edges(1:end-1) + edges(2:end)) / 2;
imagesc(ax, ages, mid, M); set(ax, 'YDir', 'normal'); colormap(ax, cmap); clim(ax, [0 1]);
end

function nodes(ax, y, col, sty)
for v = y(:).'
    yline(ax, v, sty, 'Color', col, 'LineWidth', 1.1, 'Alpha', 0.75);
end
end

function c = inband(U, g)
% Grid points inside the 5th-95th percentile range of U, per age.
lo = prctile(U, 5, 1); hi = prctile(U, 95, 1);
c = sum(g(:) >= lo & g(:) <= hi, 1);
end

function s = years(u)
% Total resources in years of income for an income share u.
y = 1 / u;
if y >= 10, s = sprintf('%.0f yr', y); else, s = sprintf('%.1f yr', y); end
end
