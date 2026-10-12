function dashboards_pdf()
%DASHBOARDS_PDF  Every step-7 robustness and diagnosis test as dashboards, in one PDF.
%   Draws effect_*.png (each test against step 7 as run) and grid_*.png (each
%   test on the standard grid against a refined one) with figures.step_dashboard,
%   then collects them with the robustness pages of ladder.robustness(7) and
%   floors_overview.png (run floor_overview first) in step07_robustness_dashboards.pdf,
%   with an intro page per section listing the largest gap between the grids.
pth = step07_paths();
cd(pth.repo);
d = pth.res; out = pth.out; dd = pth.data;
own = [0.20 0.60 0.30]; ren = [0.45 0.20 0.55];
O0 = load(fullfile(d, '07_housing_owner.mat'));  O1 = load(fullfile(d, 'robustness', '07_housing_owner_dense_u1.mat'));
N0 = load(fullfile(d, '07_housing_renter.mat')); N1 = load(fullfile(d, 'robustness', '07_housing_renter_dense_u1.mat'));
GL = {'coarse grid [16 16 10]', 'fine grid [32 16 10]'};
GC = {'grid: [16 16 10] -> [32 16 10] (twice the points on the income axis)'};

pages = {}; sec = struct('title', {}, 'lines', {});
gapline = @(name, a, b) sprintf('%-46s  stock share %5.1f points   consumption %5.1f%%', name, gaps(a, b));

% 1. Step 7 as run
p1 = {fullfile(d, 'robustness', 'robust_07_housing_owner.png'), fullfile(d, 'robustness', 'robust_07_housing_renter.png')};
p1{end+1} = dash(O0, O1, GL, 'Step 7 as run, owner: coarse grid against fine grid', fullfile(out, 'grid_07_owner.png'), [0 0 0; own], GC);
p1{end+1} = dash(N0, N1, GL, 'Step 7 as run, renter: coarse grid against fine grid', fullfile(out, 'grid_07_renter.png'), [0 0 0; ren], GC);
sec(end+1) = struct('title', '1. Step 7 as run: does the answer depend on the optimiser or the grid?', 'lines', {{ ...
    'Pages: the robustness page for owners and for renters (other optimisers, the global search off, coarser', ...
    'and finer grids, each against the default), then the coarse against the fine grid as full dashboards.', '', ...
    'Largest gap between the coarse and the fine grid, ages 26-95:', ...
    gapline('owner', O0, O1), gapline('renter', N0, N1), '', ...
    'The optimisers agree (within 0.001 in the stock share); the grid does not.'}});
pages{end+1} = p1;

% 2. Owner: what drives it
C1 = load(fullfile(dd, 'owner_flat_prices.mat')); M = load(fullfile(dd, 'owner_no_maintenance.mat')); Q = load(fullfile(dd, 'owner_no_growth.mat'));
cases = {'constant house prices', C1, {'mu_H_level: 0.0373 -> 0 (no house-price growth)', 'sigma_H_level: 0.0835 -> 0.001 (no house-price risk)'}, 'flat_house_prices'
         'no maintenance', M, {'theta: 0.015 -> 0 (no maintenance cost)'}, 'no_maintenance'
         'house-price risk without growth', Q, {'mu_H_level: 0.0373 -> 0 (risk kept, growth removed)'}, 'no_growth'};
p2 = {}; L2 = {};
for k = 1:size(cases, 1)
    nmk = cases{k, 1}; C = cases{k, 2};
    p2{end+1} = dash(O0, C.std, {'step 7 as run', nmk}, sprintf('Owner, %s: against step 7 as run (coarse grid)', nmk), ...
        fullfile(out, ['effect_owner_' cases{k, 4} '.png']), [], cases{k, 3}); %#ok<AGROW>
    p2{end+1} = dash(C.std, C.dense, GL, sprintf('Owner, %s: coarse grid against fine grid', nmk), ...
        fullfile(out, ['grid_owner_' cases{k, 4} '.png']), [0 0 0; own], GC); %#ok<AGROW>
    L2{end+1} = gapline(nmk, C.std, C.dense); %#ok<AGROW>
end
sec(end+1) = struct('title', '2. Owner: which part of housing makes the answer depend on the grid?', 'lines', {[{ ...
    'For each change: first against step 7 as run, then its own coarse against fine grid.', '', ...
    'Largest gap between the coarse and the fine grid, ages 26-95:', gapline('step 7 as run', O0, O1)}, L2, {'', ...
    'With constant house prices the grids agree: the problem comes from the house-price channel.'}]});
pages{end+1} = p2;

% 3. Owner: higher floors
fl = [0.1 0.2 0.3 0.5]; p3 = {}; L3 = {};
for phi = fl
    F = load(fullfile(dd, sprintf('owner_floor_%03d.mat', round(100 * phi))));
    tg = sprintf('%03d', round(100 * phi)); ch = {sprintf('phi_floor: 1e-06 -> %g (floor %g x income)', phi, phi)};
    p3{end+1} = dash(O0, F.std, {'step 7 as run (floor 1e-6)', sprintf('floor %g', phi)}, ...
        sprintf('Owner, floor %g x income: against step 7 as run (coarse grid)', phi), ...
        fullfile(out, ['effect_owner_floor_' tg '.png']), [], ch); %#ok<AGROW>
    p3{end+1} = dash(F.std, F.dense, GL, sprintf('Owner, floor %g x income: coarse grid against fine grid', phi), ...
        fullfile(out, ['grid_owner_floor_' tg '.png']), [0 0 0; own], GC); %#ok<AGROW>
    L3{end+1} = gapline(sprintf('floor %g', phi), F.std, F.dense); %#ok<AGROW>
end
p3{end+1} = fullfile(out, 'floors_overview.png');
sec(end+1) = struct('title', '3. Owner: higher consumption floors', 'lines', {[{ ...
    'For each floor: first against step 7 as run, then its own coarse against fine grid. Last page: all floors.', '', ...
    'Largest gap between the coarse and the fine grid, ages 26-95:', gapline('floor 1e-6 (as run)', O0, O1)}, L3, {'', ...
    'Any floor of 0.1 or more removes the early-life collapse, but the grids still disagree in mid-life and retirement.'}]});
pages{end+1} = p3;

% 4. Renter
C2 = load(fullfile(dd, 'renter_floor_010.mat')); U2 = load(fullfile(dd, 'renter_u2_doubled.mat')); BB = load(fullfile(dd, 'renter_both_doubled.mat'));
p4 = {};
p4{end+1} = dash(N0, C2.std, {'step 7 as run (floor 1e-6)', 'floor 0.1'}, 'Renter, floor 0.1 x income: against step 7 as run (coarse grid)', ...
    fullfile(out, 'effect_renter_floor_010.png'), [], {'phi_floor: 1e-06 -> 0.1 (floor 0.1 x income)'});
p4{end+1} = dash(C2.std, C2.dense, GL, 'Renter, floor 0.1 x income: coarse grid against fine grid', ...
    fullfile(out, 'grid_renter_floor_010.png'), [0 0 0; ren], GC);
p4{end+1} = dash(N0, U2.r, {'coarse grid [16 16 10]', 'second axis doubled [16 32 10]'}, ...
    'Renter, step 7: doubling the second grid axis (house share)', fullfile(out, 'grid_renter_u2_doubled.png'), [0 0 0; ren], ...
    {'grid: [16 16 10] -> [16 32 10] (twice the points on the house-share axis)'});
p4{end+1} = dash(N0, BB.r, {'coarse grid [16 16 10]', 'both axes doubled [32 32 10]'}, ...
    'Renter, step 7: doubling both grid axes', fullfile(out, 'grid_renter_both_doubled.png'), [0 0 0; ren], ...
    {'grid: [16 16 10] -> [32 32 10]'});
p4{end+1} = dash(N1, BB.r, {'income axis doubled [32 16 10]', 'both axes doubled [32 32 10]'}, ...
    'Renter, step 7: from the fine grid, also doubling the second axis', fullfile(out, 'grid_renter_u1_then_both.png'), [0 0 0; ren], ...
    {'grid: [32 16 10] -> [32 32 10]'});
sec(end+1) = struct('title', '4. Renter: floor and grid', 'lines', {{ ...
    'Floor 0.1 against step 7 as run and its own grid test, then three grid refinements of step 7 as run.', '', ...
    'Largest gap, ages 26-95:', gapline('step 7, coarse vs fine (income axis)', N0, N1), ...
    gapline('floor 0.1, coarse vs fine', C2.std, C2.dense), gapline('step 7, house-share axis doubled', N0, U2.r), ...
    gapline('step 7, both axes doubled', N0, BB.r), gapline('step 7, fine vs both doubled', N1, BB.r), '', ...
    'The renter keeps moving as either axis is refined: milder than the owner, same mechanism (rent it cannot adjust).'}});
pages{end+1} = p4;

% One PDF: an intro page per section, then its dashboards
pdf = fullfile(out, 'step07_robustness_dashboards.pdf');
if isfile(pdf), delete(pdf); end
cover(pdf, 'Step 7 (housing): all robustness and diagnosis dashboards', { ...
    'Owner and renter, step 7 of the calibration ladder (housing without correlations), standard numerics.', ...
    '"Coarse grid" is the standard grid [16 16 10]; "fine grid" doubles the income axis [32 16 10].', ...
    'Each dashboard: lines are means across simulated households, bands the 10th-90th percentiles.', ...
    'The box at the bottom right lists what changed and the checks of both results.', '', ...
    'Sections:', '  1. Step 7 as run: optimiser and grid', '  2. Owner: which part of housing drives the grid dependence', ...
    '  3. Owner: higher consumption floors', '  4. Renter: floor and grid'});
for s = 1:numel(sec)
    cover(pdf, sec(s).title, sec(s).lines);
    for i = 1:numel(pages{s}), add_png(pdf, pages{s}{i}); end
end
fprintf('wrote %s (%.1f MB)\n', pdf, dir(pdf).bytes / 1e6);
end

% ------------------------------------------------------------------------
function f = dash(rA, rB, labels, ttl, file, colours, changes)
if isempty(colours)
    figures.step_dashboard(rA, rB, labels, ttl, file, changes = changes);
else
    figures.step_dashboard(rA, rB, labels, ttl, file, colours = colours, changes = changes);
end
f = file; fprintf('wrote %s\n', file);
end

function g = gaps(a, b)
s0 = a.summary; s1 = b.summary; ag = s0.ages(:).';
w = ag > 25 & ag <= 95; w2 = ag(1:end-1) > 25 & ag(1:end-1) <= 95;
dpi = abs(s1.pi(1:end-1) - s0.pi(1:end-1));
g = [100 * max(dpi(w2)), 100 * max(abs(s1.C.mean(w) ./ s0.C.mean(w) - 1))];
end

function cover(pdf, ttl, lines)
fig = figure('Visible', 'off', 'Position', [0 0 1600 900], 'Color', 'w');
ax = axes(fig, 'Position', [0.06 0.06 0.88 0.86]); axis(ax, 'off');
text(ax, 0, 1, ttl, 'FontSize', 22, 'FontWeight', 'bold', 'VerticalAlignment', 'top', 'Interpreter', 'none');
text(ax, 0, 0.86, lines, 'FontSize', 14, 'VerticalAlignment', 'top', 'Interpreter', 'none', 'FontName', 'Consolas');
exportgraphics(fig, pdf, 'Append', true, 'ContentType', 'image', 'Resolution', 100);
close(fig);
end

function add_png(pdf, file)
I = imread(file);
[h, w, ~] = size(I);
fig = figure('Visible', 'off', 'Position', [0 0 round(w / 1.3) round(h / 1.3)], 'Color', 'w');
ax = axes(fig, 'Position', [0 0 1 1]);
image(ax, I); axis(ax, 'image', 'off');
exportgraphics(fig, pdf, 'Append', true, 'ContentType', 'image', 'Resolution', 130);
close(fig);
end
