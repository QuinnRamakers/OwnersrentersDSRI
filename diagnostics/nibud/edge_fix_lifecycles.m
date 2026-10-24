function T = edge_fix_lifecycles(fills, opts)
%EDGE_FIX_LIFECYCLES  The fill at the edge of bankruptcy as life cycles by age.
%
%   From the repository root:
%       addpath diagnostics/nibud diagnostics/pension_grid
%       T = edge_fix_lifecycles                                  % 'nearest'
%       T = edge_fix_lifecycles(["_fillnear", "_filllin"], also = "<folder>")
%
%   Step 16, renter, absorbing floor at EUR 5,000, sweep then active-set with
%   N_c 11. Loads the saved solves (case_load; nothing is solved): bunched
%   16x16 with 10, 20 and 40 evenly spaced u3 points and bunched 32x32 with
%   40, each without the fill (abs_fill = 'none') and with each fill in fills
%   (case suffixes _fillnear, _filllin). Two pages, in summary_step16/:
%     16_cmin<n>_renter_edge_grids.png   one row without the fill and one per
%                                        fill, each with the four grids (32x32
%                                        thick black): do the small grids land
%                                        on top of each other?
%     16_cmin<n>_renter_edge_pairs.png   one row per grid: without the fill
%                                        against with it
%   Columns: median consumption (grey: median gross and net income), mean
%   liquid saving, the liquid equity share and the cumulative share bankrupt;
%   multiples of entry income; solve minutes in the legends. Runs not solved
%   yet are left out. Returns the runtime table (also printed): run, grid
%   points, solve minutes, search routine and how many solves ran at once,
%   counted from the start and end times of the solves saved in pension_grid/
%   and in the folder opts.also (another checkout's pension_grid/).

arguments
    fills (1,:) string = "_fillnear"
    opts.c_min (1,1) double = 5000
    opts.also (1,1) string = ""
end

num = ladder.numerics('standard');
suf = sprintf('_cmin%d_as_nc11', opts.c_min);
grids = {'pow3_16x16_lim_u3even_u3n10', '16x16, u3 10'
         'pow3_16x16_lim_u3even_u3n20', '16x16, u3 20'
         'pow3_16x16_lim_u3even_u3n40', '16x16, u3 40'
         'pow3_32x32_lim_u3even_u3n40', '32x32, u3 40'};
vers = [{'', 'no fill'}; [cellstr(fills(:)), arrayfun(@fill_label, fills(:), 'UniformOutput', false)]];
ng = size(grids, 1); nv = size(vers, 1);
R = cell(ng, nv);
for g = 1:ng
    for v = 1:nv
        R{g, v} = case_load(16, 'renter', [grids{g, 1} suf vers{v, 1}]);
    end
end
assert(any(~cellfun(@isempty, R(:))), 'edge_fix_lifecycles:none', 'none of the runs is solved.');

out = fullfile(num.dir, 'summary_step16');
tag = sprintf('16_cmin%d_renter_edge', opts.c_min);
sub = sprintf(['Step 16, renter, absorbing floor at EUR %s; sweep then active-set, N_c 11. Means over solvent ' ...
    'households, medians for consumption; multiples of entry income; solve minutes in the legends'], group(opts.c_min));

% Page 1: per version, the four grids (the last thick black)
rows = cell(nv, 3);
for v = 1:nv
    rows(v, :) = {sprintf('%s', vers{v, 2}), R(:, v), grids(:, 2)};
end
page(rows, {'Do the small grids land on top of each other, without and with the fill at the edge of bankruptcy?', sub}, ...
    true, fullfile(out, [tag '_grids.png']));

% Page 2: per grid, without against with the fill
rows = cell(ng, 3);
for g = 1:ng
    rows(g, :) = {grids{g, 2}, R(g, :).', vers(:, 2)};
end
page(rows, {'Each grid without and with the fill at the edge of bankruptcy', sub}, ...
    false, fullfile(out, [tag '_pairs.png']));

% Runtime table
iv = load_intervals([string(fullfile(num.dir, 'pension_grid')), opts.also]);
run = strings(0, 1); nodes = strings(0, 1); minutes = zeros(0, 1); routine = strings(0, 1); at_once = zeros(0, 1);
for g = 1:ng
    for v = 1:nv
        r = R{g, v};
        if isempty(r), continue; end
        p = r.p;
        run(end+1, 1) = sprintf('%s, %s', grids{g, 2}, vers{v, 2}); %#ok<AGROW>
        nodes(end+1, 1) = sprintf('%dx%dx%d', p.N_u1, p.N_u2, p.N_u3); %#ok<AGROW>
        minutes(end+1, 1) = r.timing.solve_sec / 60; %#ok<AGROW>
        rt = sprintf('%s, N_c %d', p.fmincon_algorithm, p.N_c);
        if ~p.use_refine, rt = [rt ', no sweep']; end
        routine(end+1, 1) = rt; %#ok<AGROW>
        at_once(end+1, 1) = concurrent(r.timing, iv); %#ok<AGROW>
    end
end
T = table(run, nodes, minutes, routine, at_once, ...
    'VariableNames', {'run', 'grid_points', 'solve_minutes', 'search_routine', 'solves_at_once'});
fprintf('\n%-28s %-12s %8s  %-24s %s\n', 'run', 'grid points', 'minutes', 'search routine', 'solves at once');
for i = 1:height(T)
    fprintf('%-28s %-12s %8.0f  %-24s %d\n', T.run(i), T.grid_points(i), T.solve_minutes(i), T.search_routine(i), T.solves_at_once(i));
end
end

% ------------------------------------------------------------------------
function page(rows, ttl, last_black, file)
cols = [0.20 0.55 0.85; 0.85 0.45 0.10; 0.60 0.15 0.55; 0.25 0.65 0.35; 0.85 0.15 0.15];
pan = {'median consumption', 'mean liquid saving', 'liquid equity share', 'cumulative % bankrupt'};
nr = size(rows, 1);
fig = figure('Visible', 'off', 'Position', [30 30 2300 480 * nr + 90], 'Color', 'w');
tl  = tiledlayout(fig, nr, 4, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, ttl, 'FontSize', 13, 'FontWeight', 'bold');
for i = 1:nr
    rs = rows{i, 2}; labels = rows{i, 3};
    first = find(~cellfun(@isempty, rs), 1);
    for q = 1:4
        ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = 9.5; ax.XLim = [25 100];
        if q == 1 && ~isempty(first)
            sm = rs{first}.summary;
            plot(ax, sm.ages, sm.Y.p50 / sm.Y0, '-', 'Color', [0.8 0.8 0.8], 'LineWidth', 1.1, 'DisplayName', 'gross income (median)');
            plot(ax, sm.ages, sm.net_income.p50 / sm.Y0, '--', 'Color', [0.65 0.65 0.65], 'LineWidth', 1.1, 'DisplayName', 'net income (median)');
        end
        for n = 1:numel(rs)
            if isempty(rs{n}), continue; end
            col = cols(n, :); lw = 1.8;
            if last_black && n == numel(rs), col = [0 0 0]; lw = 3.0; end
            draw(ax, rs{n}, q, col, lw, sprintf('%s (%.0f min)', labels{n}, rs{n}.timing.solve_sec / 60));
        end
        xline(ax, 67, 'k:', 'HandleVisibility', 'off');
        if q == 3, ylim(ax, [0 1]); end
        if q == 4, ylabel(ax, '% of households'); elseif q == 3, ylabel(ax, 'share'); else, ylabel(ax, 'times entry income'); end
        if q == 1, legend(ax, 'Location', 'best', 'FontSize', 8); end
        title(ax, sprintf('%s: %s', rows{i, 1}, pan{q}), 'FontSize', 10);
        if i == nr, xlabel(ax, 'Age'); end
    end
end
exportgraphics(fig, file, 'Resolution', 120);
close(fig);
fprintf('Wrote %s\n', file);
end

function draw(ax, r, q, col, lw, label)
sm = r.summary;
switch q
    case 1, y = sm.C.p50 / sm.Y0;
    case 2, y = sm.X.mean / sm.Y0;
    case 3, y = sm.pi; y(end) = NaN;
    case 4, y = 100 * sm.floored;
end
plot(ax, sm.ages, y, '-', 'Color', col, 'LineWidth', lw, 'DisplayName', label);
end

function s = fill_label(f)
switch f
    case "_fillnear", s = 'fill nearest';
    case "_filllin",  s = 'fill linear';
    otherwise,        s = char(f);
end
end

function iv = load_intervals(dirs)
% Start and end time of every solve saved in the folders
iv = zeros(0, 2);
for d = dirs(strlength(dirs) > 0)
    f = dir(fullfile(d, '*.mat'));
    for i = 1:numel(f)
        try
            s = load(fullfile(f(i).folder, f(i).name), 'timing');
            iv(end+1, :) = interval(s.timing); %#ok<AGROW>
        catch
        end
    end
end
iv = unique(iv, 'rows');
end

function x = interval(tm)
% Solve and simulation, in days, ending when model.run stamped the result
e = datenum(datetime(tm.when));
x = [e - (tm.solve_sec + tm.sim_sec) / 86400, e];
end

function n = concurrent(tm, iv)
% Most solves running at the same time during this one, itself included
x = interval(tm);
ev = [x(1); iv(iv(:, 1) > x(1) & iv(:, 1) < x(2), 1)];
n = 1;
for k = 1:numel(ev)
    n = max(n, sum(iv(:, 1) <= ev(k) + 1e-9 & iv(:, 2) > ev(k)));
end
end

function s = group(x)
s = regexprep(sprintf('%d', round(x)), '(\d)(?=(\d{3})+$)', '$1,');
end
