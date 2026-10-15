function report_bounds()
%REPORT_BOUNDS  The step-7 diagnostics with the new consumption bounds, in one PDF.
%
%   report_bounds()
%
%   The consumption search now runs from the consumption floor to all liquid
%   resources (15 October 2026). Reads the step-7 owner solves made with the
%   new bounds in ladder/standard_16x16x10_gh5/grid_design/lbfloor/
%   (solve_grids(..., out=...)) and the log-wealth solves made with the old
%   bounds in grid_design/, and writes lbfloor/step7_new_bounds.pdf: figures
%   1-4 for the current against the log-wealth grid, figures 1-3 for the new
%   against the old bounds, the overlay and robustness pages, and the
%   twelve-panel dashboards.

repo = fileparts(fileparts(fileparts(mfilename('fullpath'))));
cd(repo);
addpath(fullfile(repo, 'diagnostics', 'step07'), fullfile(repo, 'diagnostics', 'grid_design'));
res = fullfile(repo, 'ladder', 'standard_16x16x10_gh5');
gd  = fullfile(res, 'grid_design'); nb = fullfile(gd, 'lbfloor');
newf = @(n) fullfile(nb, ['owner_' n '.mat']);
oldf = @(n) fullfile(gd, ['owner_' n '.mat']);

% Figures 1-3 as for step 7 as run: the current grid, coarse (16x16) against
% fine (income axis doubled, 32x16), new bounds. The pair doubles as its own
% contrast so that only it sets the ranges.
c16 = newf('uniform_16x16'); f32 = newf('uniform_32x16');
if ~all(cellfun(@isfile, fullfile(nb, {'ruin_1_why_new_bounds.png', 'ruin_2_cliff_new_bounds.png', ...
        'ruin_3_landscape_new_bounds.png', 'ruin_3_landscape_zoom100_new_bounds.png'})))
    ruin_figures([], files={c16, f32, c16, f32}, names={'coarse grid', 'fine grid', 'coarse grid', 'fine grid'}, ...
        main='', alt='', tag='_new_bounds', out=nb, figures=1:3, fig1_pair=true);
end

% Figures 1-4: the current grid against the log-wealth grid, new bounds
if ~isfile(fullfile(nb, 'ruin_4_cut_grids.png'))
    ruin_figures([], files={newf('uniform_16x16'), newf('uniform_32x16'), newf('logwealth_16x16'), newf('logwealth_32x32')}, ...
        names={'current grid 16x16', 'current grid 32x16', 'log-wealth grid 16x16', 'log-wealth grid 32x32'}, ...
        main='current grid', alt='log-wealth grid', tag='_grids', out=nb, figures=1:4);
end
% Figures 1-3: new bounds against old bounds, log-wealth 16x16 and 32x32
if ~isfile(fullfile(nb, 'ruin_3_landscape_zoom100_bounds.png'))
    ruin_figures([], files={newf('logwealth_16x16'), newf('logwealth_32x32'), oldf('logwealth_16x16'), oldf('logwealth_32x32')}, ...
        names={'new bounds, log-wealth 16x16', 'new bounds, log-wealth 32x32', 'old bounds, log-wealth 16x16', ...
        'old bounds, log-wealth 32x32'}, main='new bounds', alt='old bounds', tag='_bounds', out=nb, figures=1:3);
end

% Overlay and robustness pages against new-bound log-wealth 32x32
L = @(f) getfield(load(f), 'r');
ref = L(newf('logwealth_32x32'));
names = {'logwealth_16x16', 'uniform_16x16', 'uniform_32x16', 'power_32x32'};
labs  = {'log-wealth 16x16', 'current 16x16', 'current 32x16', 'power 2, 32x32'};
have  = cellfun(@(n) isfile(newf(n)), names);
R = cellfun(@(n) L(newf(n)), names(have), 'UniformOutput', false);
old32 = L(oldf('logwealth_32x32'));
figures.compare([{ref}, R, {old32}], [{'new bounds, log-wealth 32x32'}, strcat({'new bounds, '}, labs(have)), ...
    {'old bounds, log-wealth 32x32'}], 'Step 7 owner with the new consumption bounds: grids, and the old bounds', ...
    fullfile(nb, 'compare_owner_new_bounds.png'));
groups = struct('name', {'Other grids, new bounds', 'Old bounds'}, 'rs', {R, {old32}}, ...
    'labels', {strcat({'new bounds, '}, labs(have)), {'old bounds, log-wealth 32x32'}});
try
    figures.robustness(ref, 'new bounds, log-wealth 32x32', groups, ...
        'Step 7 owner: every solve against the new bounds on log-wealth 32x32', fullfile(nb, 'robustness_owner_new_bounds.png'));
catch err
    warning('report_bounds:robustness', 'robustness page not drawn: %s', err.message);
    close all
end
for n = {'logwealth_32x32', 'uniform_16x16'}
    if isfile(newf(n{1}))
        figures.dashboard(L(newf(n{1})), fullfile(nb, sprintf('dashboard_owner_%s_new_bounds.png', n{1})));
    end
end

% The cover numbers
allr = [{ref}, R, {old32}]; allL = [{'new bounds, log-wealth 32x32'}, strcat({'new bounds, '}, labs(have)), ...
    {'old bounds, log-wealth 32x32'}];
tab = {sprintf('%-34s %8s %8s %8s %10s %7s', 'solve', 'C at 30', 'C at 45', 'C at 75', 'bankrupt', 'solve')};
for i = 1:numel(allr)
    s = allr{i}.summary; a = s.ages;
    tab{end+1} = sprintf('%-34s %7.1fk %7.1fk %7.1fk %9.2f%% %6.0f s', allL{i}, s.C.mean(a == 30) / 1e3, ...
        s.C.mean(a == 45) / 1e3, s.C.mean(a == 75) / 1e3, 100 * allr{i}.checks.floored_share, allr{i}.timing.solve_sec); %#ok<AGROW>
end

pdf = fullfile(nb, 'step7_new_bounds.pdf');
if isfile(pdf), delete(pdf); end
cover(pdf, 'Step 7 owner with the new consumption bounds', [{ ...
    'Since 15 October 2026 the consumption search runs from the consumption floor (1e-6 x gross income) to all', ...
    'liquid resources. Before, it ran from 1% of total wealth (house included, capped at half of liquid resources)', ...
    'to 1 - 1e-6 of liquid resources. Floor 1e-6, starting savings 0.079 years of income, standard numerics.', '', ...
    'Mean consumption (thousand EUR, 2025), bankrupt household-years and solve time:', ''}, tab, {'', ...
    'Sections:', '  0. Figures 1-3 as for step 7 as run: coarse grid (16x16) against fine grid (32x16)', ...
    '  1. Figures 1-4: the current grid (16x16, 32x16) against the log-wealth grid (16x16, 32x32)', ...
    '  2. Figures 1-3: the new bounds against the old bounds, log-wealth 16x16 and 32x32', ...
    '  3. The overlay and robustness pages, and the twelve-panel dashboards', '', ...
    'Log-wealth 64x48 and 128x96 and the renter were not re-solved with the new bounds (time).'}]);
sec = {
    '0. Step 7 as run with the new bounds: coarse grid (16x16) against fine grid (32x16)', ...
        cellfun(@(f) fullfile(nb, [f '_new_bounds.png']), {'ruin_1_why', 'ruin_2_cliff', 'ruin_3_landscape', ...
        'ruin_3_landscape_zoom100'}, 'UniformOutput', false)
    '1. Current grid against log-wealth grid, new bounds', ...
        cellfun(@(f) fullfile(nb, [f '_grids.png']), {'ruin_1_why', 'ruin_2_cliff', 'ruin_3_landscape', ...
        'ruin_3_landscape_zoom100', 'ruin_4_cut'}, 'UniformOutput', false)
    '2. New bounds against old bounds, log-wealth grid', ...
        cellfun(@(f) fullfile(nb, [f '_bounds.png']), {'ruin_1_why', 'ruin_2_cliff', 'ruin_3_landscape', ...
        'ruin_3_landscape_zoom100'}, 'UniformOutput', false)
    '3. Overlay, robustness and dashboards', ...
        cellfun(@(f) fullfile(nb, f), {'compare_owner_new_bounds.png', 'robustness_owner_new_bounds.png', ...
        'dashboard_owner_logwealth_32x32_new_bounds.png', 'dashboard_owner_uniform_16x16_new_bounds.png'}, ...
        'UniformOutput', false)
    };
for s = 1:size(sec, 1)
    f = sec{s, 2}; ok = cellfun(@isfile, f);
    lines = {''};
    if any(~ok)
        [~, nm, ext] = cellfun(@fileparts, f(~ok), 'UniformOutput', false);
        lines = [{'Not drawn, skipped:'}, strcat({'  '}, nm, ext)];
    end
    cover(pdf, sec{s, 1}, lines);
    for g = f(ok), add_png(pdf, g{1}); end
end
fprintf('wrote %s (%.1f MiB)\n', pdf, dir(pdf).bytes / 2^20);
end

% ------------------------------------------------------------------------
function cover(pdf, ttl, lines)
fig = figure('Visible', 'off', 'Position', [0 0 1600 1000], 'Color', 'w');
ax = axes(fig, 'Position', [0.04 0.04 0.92 0.90]); axis(ax, 'off');
text(ax, 0, 1, ttl, 'FontSize', 20, 'FontWeight', 'bold', 'VerticalAlignment', 'top', 'Interpreter', 'none');
text(ax, 0, 0.93, lines, 'FontSize', 12, 'VerticalAlignment', 'top', 'Interpreter', 'none', 'FontName', 'Consolas');
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
