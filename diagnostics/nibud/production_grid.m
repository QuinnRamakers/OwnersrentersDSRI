function production_grid(c_min)
%PRODUCTION_GRID  Step 16 grid test with the absorbing floor, one axis at a time.
%
%   From the repository root:
%       addpath diagnostics/nibud diagnostics/pension_grid
%       production_grid           % c_min = 5,000
%
%   Owner (maintenance on the current value, q at 4) and renter, all with the
%   absorbing floor at c_min and the exact bankruptcy test, solved with
%   solve_cases. Each axis is refined with the others held at the bunched
%   16x16 grid (u3 at 10 points bunched toward 0, gh_n 5):
%     u1 x u2      16x16 and 24x24 (owner) or 32x32 (renter) against the
%                  finest, 32x32 (owner) or 48x48 (renter)
%     u3           10, 20 and 40 points bunched toward 0 (grid_pow_u3 2), and
%                  20 and 40 evenly spaced, against 80 bunched
%     quadrature   gh_n 5 against 7
%     search       active-set with the wider sweep round (_as_nc11) against
%                  the default routine, on 24x24 (owner) or 32x32 (renter)
%     production   the numerics of config.params as they are (uniform
%                  20x20, u3 at 12, q at 8, pi = 1 where nothing is saved)
%                  against the finest u1 x u2 grid
%   Gaps are policy_gaps: each grid's policies at the reference's households.
%   Stop rule: 2% in consumption and 0.02 in the liquid equity share. Cases
%   not solved yet are left out. Writes, in summary_step16/ next to the
%   ladder results:
%     16_cmin<n>_grid_gaps.png         gaps by age, one column per axis
%     16_cmin<n>_grid_lifecycles.png   the main cases by age: median
%                                      consumption, liquid saving, liquid
%                                      equity share, cumulative % bankrupt
%     16_cmin<n>_<arm>_grid_compare.png   figures.compare: the candidate grid
%                                      (or the finest u1 x u2 grid) against
%                                      the others
%   and prints the gaps by age band and each case's checks.

arguments
    c_min (1,1) double = 5000
end

num = ladder.numerics('standard');
out = fullfile(num.dir, 'summary_step16');
if ~isfolder(out), mkdir(out); end
suf = sprintf('_cmin%d', c_min);
tag = sprintf('16_cmin%d', c_min);
bands = {[26 39], [40 54], [55 66], [67 89], [90 95]};

% Case names carry %s where the floor's suffix goes (before _as_nc11)
O.arm = 'owner'; O.title = 'Owner, maintenance on the current value';
O.cases = {'pow3_16x16_lim_u3p2_qn4%s', '16x16'
           'pow3_24x24_lim_u3p2_qn4%s', '24x24'
           'pow3_32x32_lim_u3p2_qn4%s', '32x32'
           'pow3_16x16_lim_u3p2_qn4_u3n20%s', '16x16, u3 20'
           'pow3_16x16_lim_u3p2_qn4_u3n40%s', '16x16, u3 40'
           'pow3_16x16_lim_u3p2_qn4_gh7%s', '16x16, gh 7'
           'uniform_20x20_u3n12%s', 'production numerics'
           'pow3_16x16_lim_u3p2_qn4_u3n80%s_as_nc11', '16x16, u3 80'
           'pow3_16x16_lim_u3even_qn4_u3n20%s_as_nc11', '16x16, u3 20 even'
           'pow3_24x24_lim_u3p2_qn4%s_as_nc11', '24x24, active-set'};
O.axes = struct('name', {'u1 x u2', 'u3', 'quadrature', 'search routine', 'production numerics'}, ...
                'pairs', {[1 3; 2 3], [1 8; 4 8; 5 8; 9 8], [1 6], [10 2], [7 3]});
O.show = [1 2 3 5 8 7];            % the lifecycle page
O.ref = 3;                         % reference of the overlay page
Rt.arm = 'renter'; Rt.title = 'Renter';
Rt.cases = {'pow3_16x16_lim_u3p2%s', '16x16'
            'pow3_32x32_lim_u3p2%s', '32x32'
            'pow3_48x48_lim_u3p2%s', '48x48'
            'pow3_16x16_lim_u3p2_u3n20%s', '16x16, u3 20'
            'pow3_16x16_lim_u3p2_u3n40%s', '16x16, u3 40'
            'pow3_16x16_lim_u3p2_gh7%s', '16x16, gh 7'
            'uniform_20x20_u3n12%s', 'production numerics'
            'pow3_16x16_lim_u3p2_u3n80%s', '16x16, u3 80'
            'pow3_16x16_lim_u3even_u3n20%s_as_nc11', '16x16, u3 20 even'
            'pow3_16x16_lim_u3even_u3n40%s_as_nc11', '16x16, u3 40 even'
            'pow3_32x32_lim_u3p2%s_as_nc11', '32x32, active-set'
            'pow3_32x32_lim_u3even_u3n40%s_as_nc11', 'candidate: 32x32, u3 40 even'};
Rt.axes = struct('name', {'u1 x u2', 'u3', 'quadrature', 'search routine', 'production numerics'}, ...
                 'pairs', {[1 3; 2 3], [1 8; 4 8; 5 8; 9 8; 10 8], [1 6], [11 2], [7 3]});
Rt.show = [1 2 3 5 8 7 12];
Rt.ref = 12;
A = {O, Rt};

for k = 1:2
    X = A{k};
    X.names  = cellfun(@(c) sprintf(c, suf), X.cases(:, 1).', 'UniformOutput', false);
    X.labels = X.cases(:, 2).';
    X.r = cellfun(@(c) case_load(16, X.arm, c), X.names, 'UniformOutput', false);
    X.have = ~cellfun(@isempty, X.r);
    if any(~X.have)
        fprintf('%s, not solved yet: %s\n', X.title, strjoin(X.names(~X.have), ', '));
    end
    X.G = cell(1, numel(X.axes));
    for j = 1:numel(X.axes)
        P = X.axes(j).pairs;
        X.G{j} = cell(1, size(P, 1));
        for i = 1:size(P, 1)
            if all(X.have(P(i, :)))
                X.G{j}{i} = policy_gaps(X.r{P(i, 1)}, X.r{P(i, 2)}, bands);
            end
        end
    end
    if ~X.have(X.ref), X.ref = 3; end
    A{k} = X;
end

% Gaps by age: rows owner consumption, owner share, renter consumption,
% renter share; one column per axis
na = numel(O.axes);
cols = [0.85 0.45 0.10; 0.20 0.55 0.85; 0.60 0.15 0.55; 0.25 0.65 0.35; 0.55 0.40 0.10];
fig = figure('Visible', 'off', 'Position', [30 30 2700 1500], 'Color', 'w');
tl  = tiledlayout(fig, 4, na, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {sprintf('Step 16, absorbing floor at c_{min} = EUR %s: grid test one axis at a time', group(c_min)), ...
    'Each grid''s policies at the reference''s households; dotted: stop rule (2% in consumption, 0.02 in the liquid equity share)'}, ...
    'FontSize', 13, 'FontWeight', 'bold');
for k = 1:2
    X = A{k};
    for row = 1:2
        for j = 1:na
            ax = nexttile(tl, ((k - 1) * 2 + row - 1) * na + j);
            hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = 9; ax.XLim = [25 100];
            P = X.axes(j).pairs;
            drawn = false;
            for i = 1:size(P, 1)
                G = X.G{j}{i};
                if isempty(G), continue; end
                if row == 1, y = 100 * G.C_age; else, y = G.pi_age; end
                y(y <= 0) = NaN;
                plot(ax, G.ages, y, '-', 'Color', cols(i, :), 'LineWidth', 1.8, 'DisplayName', ...
                    sprintf('%s vs %s', X.labels{P(i, 1)}, X.labels{P(i, 2)}));
                drawn = true;
            end
            set(ax, 'YScale', 'log');
            if row == 1
                yline(ax, 2, 'k:', 'HandleVisibility', 'off'); ylabel(ax, 'consumption gap, %');
                ylim(ax, [1e-3 Inf]);
            else
                yline(ax, 0.02, 'k:', 'HandleVisibility', 'off'); ylabel(ax, 'equity share gap');
                ylim(ax, [1e-4 1]);
            end
            xline(ax, 67, 'k:', 'HandleVisibility', 'off');
            if drawn, legend(ax, 'Location', 'northeast', 'FontSize', 7.5); end
            what = {'consumption', 'liquid equity share'};
            title(ax, sprintf('%s, %s: %s', X.title, X.axes(j).name, what{row}), 'FontSize', 9);
            if k == 2 && row == 2, xlabel(ax, 'Age'); end
        end
    end
end
exportgraphics(fig, fullfile(out, [tag '_grid_gaps.png']), 'Resolution', 120);
close(fig);

% The main cases by age
lc = [0.55 0.55 0.55; 0.20 0.55 0.85; 0 0 0; 0.85 0.45 0.10; 0.60 0.15 0.55; 0.85 0.15 0.15; 0.25 0.65 0.35];
fig = figure('Visible', 'off', 'Position', [30 30 2300 1150], 'Color', 'w');
tl  = tiledlayout(fig, 2, 4, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {sprintf('Step 16, absorbing floor at c_{min} = EUR %s: the grids by age', group(c_min)), ...
    'Medians and means over the panel of each solve; wealth and shares over solvent households; multiples of entry income'}, ...
    'FontSize', 13, 'FontWeight', 'bold');
ttl = {'median consumption', 'mean liquid saving', 'liquid equity share', 'cumulative % bankrupt'};
for k = 1:2
    X = A{k};
    for q = 1:4
        ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = 9; ax.XLim = [25 100];
        for n = 1:numel(X.show)
            i = X.show(n);
            if ~X.have(i), continue; end
            sm = X.r{i}.summary;
            switch q
                case 1, y = sm.C.p50 / sm.Y0;
                case 2, y = sm.X.mean / sm.Y0;
                case 3, y = sm.pi; y(end) = NaN;
                case 4, y = 100 * sm.floored;
            end
            lw = 1.6; if i == X.ref, lw = 2.6; end
            plot(ax, sm.ages, y, '-', 'Color', lc(n, :), 'LineWidth', lw, 'DisplayName', X.labels{i});
        end
        xline(ax, 67, 'k:', 'HandleVisibility', 'off');
        if q == 3, ylim(ax, [0 1]); end
        if q == 1, legend(ax, 'Location', 'best', 'FontSize', 8); end
        title(ax, sprintf('%s: %s', X.title, ttl{q}), 'FontSize', 10);
        if k == 2, xlabel(ax, 'Age'); end
    end
end
exportgraphics(fig, fullfile(out, [tag '_grid_lifecycles.png']), 'Resolution', 130);
close(fig);

% Overlays: the candidate (or the finest u1 x u2 grid) against the others
for k = 1:2
    X = A{k};
    order = [X.ref, setdiff(X.show, X.ref, 'stable')];
    order = order(X.have(order));
    order = order(1:min(6, end));
    if numel(order) >= 2
        figures.compare(X.r(order), X.labels(order), sprintf('Step 16, %s, absorbing floor at c_min = EUR %s: grids', ...
            lower(X.title), group(c_min)), fullfile(out, sprintf('%s_%s_grid_compare.png', tag, X.arm)));
        close all
    end
end

% Tables
head = sprintf('%-52s', 'consumption % / share');
for b = bands, head = [head sprintf('  %5d-%-5d', b{1}(1), b{1}(2))]; end %#ok<AGROW>
for k = 1:2
    X = A{k};
    fprintf('\n%s: policies at the reference''s households\n%s\n', X.title, head);
    for j = 1:numel(X.axes)
        P = X.axes(j).pairs;
        for i = 1:size(P, 1)
            if isempty(X.G{j}{i}), continue; end
            nm = sprintf('%s: %s vs %s', X.axes(j).name, X.labels{P(i, 1)}, X.labels{P(i, 2)});
            fprintf('%-52s%s\n', nm, gap_row(X.G{j}{i}));
        end
    end
    fprintf('\n%-30s %13s %7s %7s %7s %7s %9s %8s %8s\n', '', 'nodes', 'bkr yr', 'at 40', 'at 67', 'at 100', 'entry', 'offgrid', 'solve s');
    for i = find(X.have)
        r = X.r{i}; c = r.checks; p = r.p;
        fprintf('%-30s %13s %6.2f%% %6.2f%% %6.2f%% %6.1f%% %9.4f %8s %8.0f\n', X.labels{i}, ...
            sprintf('%dx%dx%dx%d', p.N_u1, p.N_u2, p.N_u3, p.N_q), 100 * c.floored_share, 100 * c.abs_share, ...
            c.ce_entry, mat2str(c.offgrid), r.timing.solve_sec);
    end
    fprintf('\n%-30s %5s %8s %8s %6s\n', '', 'age', 'C/Y0', 'X/Y0', 'pi');
    for i = X.show(X.have(X.show))
        s = X.r{i}.summary;
        for age = [30 40 55 66 80 95]
            m = s.ages == age;
            fprintf('%-30s %5d %8.3f %8.3f %6.3f\n', X.labels{i}, age, s.C.p50(m) / s.Y0, s.X.mean(m) / s.Y0, s.pi(m));
        end
    end
end
end

function s = gap_row(G)
s = '';
for k = 1:numel(G.C)
    s = [s sprintf('  %5.1f/%5.3f', 100 * G.C(k), G.pi(k))]; %#ok<AGROW>
end
end

function s = group(x)
s = regexprep(sprintf('%d', round(x)), '(\d)(?=(\d{3})+$)', '$1,');
end
