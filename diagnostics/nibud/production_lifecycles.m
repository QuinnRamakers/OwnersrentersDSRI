function T = production_lifecycles(c_min)
%PRODUCTION_LIFECYCLES  The c_min grid and search-routine study as life cycles by age.
%
%   From the repository root:
%       addpath diagnostics/nibud diagnostics/pension_grid
%       T = production_lifecycles          % c_min = 5,000
%
%   One page per question, owner (maintenance on the current value) on top
%   and renter below; each panel overlays the runs by age: median
%   consumption (grey: median gross and net income of the first run),
%   mean liquid saving, the liquid equity share and the cumulative share
%   bankrupt. Levels are multiples of entry income. Each run's solve time is
%   in its legend. Pages, in summary_step16/:
%     16_cmin<n>_life_density.png      more grid points on wealth (u1 x u2)
%     16_cmin<n>_life_u3.png           more points, and their spacing, on
%                                      the pension-against-housing axis (u3)
%     16_cmin<n>_life_quadrature.png   more quadrature nodes per shock
%     16_cmin<n>_life_search.png       the per-node search routine
%     16_cmin<n>_life_production.png   today's production numerics against
%                                      the finest grid solved
%   Runs not solved yet are left out. Returns the runtime table (also
%   printed): run, nodes, solve minutes and search routine. Solves that
%   shared the machine with others ran slower than alone.

arguments
    c_min (1,1) double = 5000
end

num = ladder.numerics('standard');
out = fullfile(num.dir, 'summary_step16');
suf = sprintf('_cmin%d', c_min);
tag = sprintf('16_cmin%d', c_min);

% name (%s where the floor's suffix goes), label
own = {'pow3_16x16_lim_u3p2_qn4%s', '16x16'
       'pow3_24x24_lim_u3p2_qn4%s', '24x24'
       'pow3_32x32_lim_u3p2_qn4%s', '32x32'
       'pow3_16x16_lim_u3p2_qn4_u3n20%s', '16x16, u3 at 20'
       'pow3_16x16_lim_u3p2_qn4_u3n40%s', '16x16, u3 at 40'
       'pow3_16x16_lim_u3p2_qn4_u3n80%s_as_nc11', '16x16, u3 at 80'
       'pow3_16x16_lim_u3even_qn4_u3n20%s_as_nc11', '16x16, u3 at 20 even'
       'pow3_16x16_lim_u3p2_qn4_gh7%s', '16x16, 7 nodes'
       'pow3_24x24_lim_u3p2_qn4%s_as_nc11', '24x24, active-set'
       'uniform_20x20_u3n12%s', 'production numerics'};
ren = {'pow3_16x16_lim_u3p2%s', '16x16'
       'pow3_32x32_lim_u3p2%s', '32x32'
       'pow3_48x48_lim_u3p2%s', '48x48'
       'pow3_16x16_lim_u3p2_u3n20%s', '16x16, u3 at 20'
       'pow3_16x16_lim_u3p2_u3n40%s', '16x16, u3 at 40'
       'pow3_16x16_lim_u3p2_u3n80%s', '16x16, u3 at 80'
       'pow3_16x16_lim_u3even_u3n20%s_as_nc11', '16x16, u3 at 20 even'
       'pow3_16x16_lim_u3even_u3n40%s_as_nc11', '16x16, u3 at 40 even'
       'pow3_16x16_lim_u3p2_gh7%s', '16x16, 7 nodes'
       'pow3_32x32_lim_u3p2%s_as_nc11', '32x32, active-set'
       'uniform_20x20_u3n12%s', 'production numerics'
       'pow3_32x32_lim_u3even_u3n40%s_as_nc11', '32x32, u3 at 40 even'};
R.owner  = load_all('owner', own, suf);
R.renter = load_all('renter', ren, suf);

% Pages: the question, then the runs per tenure (labels), first run drawn thick
pages = {
  'density', 'More grid points on wealth (u1 x u2): does the life cycle change?', ...
     {'16x16', '24x24', '32x32'}, {'16x16', '32x32', '48x48'}
  'u3', 'More points on the pension-against-housing axis (u3), bunched toward 0 or evenly spaced', ...
     {'16x16', '16x16, u3 at 20', '16x16, u3 at 40', '16x16, u3 at 80', '16x16, u3 at 20 even'}, ...
     {'16x16', '16x16, u3 at 20', '16x16, u3 at 40', '16x16, u3 at 80', '16x16, u3 at 20 even', '16x16, u3 at 40 even'}
  'quadrature', 'More quadrature nodes per shock: 5 (today) against 7', ...
     {'16x16', '16x16, 7 nodes'}, {'16x16', '16x16, 7 nodes'}
  'search', 'The search at each grid point: today''s routine (interior-point) against active-set with a wider sweep', ...
     {'24x24', '24x24, active-set'}, {'32x32', '32x32, active-set'}
  'production', 'Today''s production numerics (uniform 20x20, u3 at 12) against the finest grids solved', ...
     {'production numerics', '32x32', '16x16, u3 at 40', '16x16, u3 at 80'}, ...
     {'production numerics', '48x48', '16x16, u3 at 80', '32x32, u3 at 40 even'}};
for k = 1:size(pages, 1)
    page(R, pages(k, :), c_min, fullfile(out, sprintf('%s_life_%s.png', tag, pages{k, 1})));
end

% Runtime table
T = [runtimes(R.owner, 'owner'); runtimes(R.renter, 'renter')];
fprintf('\n%-7s %-24s %-14s %8s  %s\n', 'tenure', 'run', 'nodes', 'minutes', 'search routine');
for i = 1:height(T)
    fprintf('%-7s %-24s %-14s %8.0f  %s\n', T.tenure(i), T.run(i), T.nodes(i), T.minutes(i), T.routine(i));
end
end

% ------------------------------------------------------------------------
function S = load_all(arm, cases, suf)
S = struct('label', {}, 'r', {});
for i = 1:size(cases, 1)
    r = case_load(16, arm, sprintf(cases{i, 1}, suf));
    if isempty(r), continue; end
    S(end+1) = struct('label', cases{i, 2}, 'r', r); %#ok<AGROW>
end
end

function page(R, pg, c_min, file)
cols = [0 0 0; 0.85 0.45 0.10; 0.20 0.55 0.85; 0.60 0.15 0.55; 0.25 0.65 0.35; 0.85 0.15 0.15];
arms = {'owner', 'renter'};
names = {'Owner, maintenance on the current value', 'Renter'};
ttl = {'median consumption', 'mean liquid saving', 'liquid equity share', 'cumulative % bankrupt'};
fig = figure('Visible', 'off', 'Position', [30 30 2300 1150], 'Color', 'w');
tl  = tiledlayout(fig, 2, 4, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {pg{2}, sprintf(['Step 16, absorbing floor at EUR %s. Means over solvent households, medians for ' ...
    'consumption; multiples of entry income; solve minutes in the legend'], group(c_min))}, ...
    'FontSize', 13, 'FontWeight', 'bold');
for a = 1:2
    S = R.(arms{a});
    want = pg{2 + a};
    sel = cellfun(@(l) find(strcmp({S.label}, l), 1), want, 'UniformOutput', false);
    have = ~cellfun(@isempty, sel);
    sel = [sel{have}]; want = want(have);
    for q = 1:4
        ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = 9.5; ax.XLim = [25 100];
        if q == 1 && ~isempty(sel)
            sm = S(sel(1)).r.summary;
            plot(ax, sm.ages, sm.Y.p50 / sm.Y0, '-', 'Color', [0.75 0.75 0.75], 'LineWidth', 1.2, 'DisplayName', 'gross income (median)');
            plot(ax, sm.ages, sm.net_income.p50 / sm.Y0, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1.2, 'DisplayName', 'net income (median)');
        end
        for n = 1:numel(sel)
            r = S(sel(n)).r; sm = r.summary;
            switch q
                case 1, y = sm.C.p50 / sm.Y0;
                case 2, y = sm.X.mean / sm.Y0;
                case 3, y = sm.pi; y(end) = NaN;
                case 4, y = 100 * sm.floored;
            end
            lw = 1.6; if n == 1, lw = 2.6; end
            plot(ax, sm.ages, y, '-', 'Color', cols(n, :), 'LineWidth', lw, 'DisplayName', ...
                sprintf('%s (%.0f min)', want{n}, r.timing.solve_sec / 60));
        end
        xline(ax, 67, 'k:', 'HandleVisibility', 'off');
        if q == 3, ylim(ax, [0 1]); end
        if q == 4, ylabel(ax, '% of households'); elseif q == 3, ylabel(ax, 'share'); else, ylabel(ax, 'times entry income'); end
        if q == 1, legend(ax, 'Location', 'best', 'FontSize', 8.5); end
        title(ax, sprintf('%s: %s', names{a}, ttl{q}), 'FontSize', 10.5);
        if a == 2, xlabel(ax, 'Age'); end
    end
end
exportgraphics(fig, file, 'Resolution', 130);
close(fig);
end

function T = runtimes(S, arm)
n = numel(S);
run = strings(n, 1); nodes = strings(n, 1); minutes = zeros(n, 1); routine = strings(n, 1);
for i = 1:n
    p = S(i).r.p;
    run(i) = S(i).label;
    nodes(i) = sprintf('%dx%dx%dx%d', p.N_u1, p.N_u2, p.N_u3, p.N_q);
    minutes(i) = S(i).r.timing.solve_sec / 60;
    rt = p.fmincon_algorithm;
    if p.N_c ~= 41, rt = [rt sprintf(', N_c %d', p.N_c)]; end
    if ~p.use_refine, rt = [rt ', no sweep']; end
    routine(i) = rt;
end
T = table(repmat(string(arm), n, 1), run, nodes, minutes, routine, ...
    'VariableNames', {'tenure', 'run', 'nodes', 'minutes', 'routine'});
end

function s = group(x)
s = regexprep(sprintf('%d', round(x)), '(\d)(?=(\d{3})+$)', '$1,');
end
