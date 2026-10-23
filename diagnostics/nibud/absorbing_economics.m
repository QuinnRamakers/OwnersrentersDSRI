function absorbing_economics(levels, opts)
%ABSORBING_ECONOMICS  Step 16 with the absorbing floor at several c_min, against the yearly top-up.
%
%   From the repository root:
%       addpath diagnostics/nibud diagnostics/pension_grid
%       absorbing_economics                          % c_min 4,000 to 12,000
%       absorbing_economics([6000 8000], dashboards = false)
%
%   For each arm (owner with maintenance on the current value, owner with
%   maintenance on the purchase price, renter) loads the summary-grid solves of
%   20 October, with the yearly top-up at phi_floor, and the same grids with
%   the absorbing floor (case suffix _cmin<n>, solved with solve_cases). Levels
%   not solved yet are left out and listed. Writes, in summary_step16/ next to
%   the ladder results:
%     16_absorbing_economics.png        by age, every arm and level: median
%                                       consumption; mean liquid saving, liquid
%                                       equity share and median housing cost
%                                       over net income of the solvent; the
%                                       share bankrupt; the yearly entry rate
%     16_absorbing_<arm>_cmin<n>.png    the dashboard of each arm and level
%     16_absorbing_<arm>_compare.png    each arm's levels over the top-up
%   and prints the checks and the main quantities at a few ages.

arguments
    levels (1,:) double = [4000 6000 8000 10000 12000]
    opts.dashboards (1,1) logical = true
end

num = ladder.numerics('standard');
out = fullfile(num.dir, 'summary_step16');
if ~isfolder(out), mkdir(out); end

arms = struct('tag', {'owner_current', 'owner_purchase', 'renter'}, ...
    'arm', {'owner', 'owner', 'renter'}, ...
    'base', {'pow3_16x16_lim_u3p2_qn4_nosweep', 'pow3_16x16_lim_u3p2_qn4_nosweep', 'pow3_16x16_lim_u3p2_u3n20'}, ...
    'mop', {'', '_mop', ''}, ...
    'label', {'Owner, maintenance on the current value', 'Owner, maintenance on the purchase price', 'Renter'}, ...
    'short', {'Owner, current value', 'Owner, purchase price', 'Renter'});
nl = numel(levels);
R = cell(numel(arms), nl + 1);
for a = 1:numel(arms)
    A = arms(a);
    R{a, 1} = case_load(16, A.arm, [A.base A.mop]);
    assert(~isempty(R{a, 1}), 'absorbing_economics:missing', 'the top-up case of %s is not solved.', A.label);
    for j = 1:nl
        R{a, j + 1} = case_load(16, A.arm, sprintf('%s_cmin%d%s', A.base, levels(j), A.mop));
        if isempty(R{a, j + 1}), fprintf('not solved yet: %s, c_min %d\n', A.label, levels(j)); end
    end
end
names = [{'top-up at 1e-6'}, arrayfun(@(c) sprintf('c_{min} = EUR %s', group(c)), levels, 'UniformOutput', false)];
cols  = [0 0 0; parula_like(nl)];

% One page: arms in rows
nk  = 6;
fig = figure('Visible', 'off', 'Position', [20 20 2600 1300], 'Color', 'w');
tl  = tiledlayout(fig, numel(arms), nk, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {'Step 16: the absorbing consumption floor against the yearly top-up (dashed black)', ...
    ['Summary grids of 20 October; levels in multiples of entry income; saving, equity share and housing cost over ' ...
     'solvent households; c_{min} is the median owner''s floor in euros, the same share of income for renters']}, ...
    'FontSize', 13, 'FontWeight', 'bold');
for a = 1:numel(arms)
    for k = 1:nk
        ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
        ax.XLim = [25 100]; ax.FontSize = 9;
        xline(ax, 67, 'k:', 'HandleVisibility', 'off');
        for j = 1:nl + 1
            ls = '-'; lw = 1.7; if j == 1, ls = '--'; lw = 1.4; end
            if isempty(R{a, j})
                % keep the legend of the first panel complete
                if a == 1 && k == 1 && any(~cellfun(@isempty, R(:, j)))
                    plot(ax, NaN, NaN, ls, 'Color', cols(j, :), 'LineWidth', lw, 'DisplayName', names{j});
                end
                continue
            end
            s = R{a, j}.summary; x = s.ages;
            switch k
                case 1, y = s.C.p50 / s.Y0;
                case 2, y = s.X.mean / s.Y0;
                case 3, y = s.pi; y(end) = NaN;
                case 4, y = s.burden;
                case 5, y = 100 * s.floored;
                case 6
                    if j == 1, continue; end
                    y = 100 * s.abs_hazard;
            end
            plot(ax, x, y, ls, 'Color', cols(j, :), 'LineWidth', lw, 'DisplayName', names{j});
        end
        switch k
            case 1, ylabel(ax, 'times entry income'); t = 'median consumption';
            case 2, ylabel(ax, 'times entry income'); t = 'mean liquid saving';
            case 3, ylabel(ax, 'share'); ylim(ax, [0 1]); t = 'liquid equity share';
            case 4, ylabel(ax, 'share'); t = 'housing cost / net income (median)';
            case 5, ylabel(ax, '% of households'); t = 'bankrupt (top-up: floored that year)';
            case 6, ylabel(ax, '% a year'); t = 'rate of going bankrupt';
        end
        title(ax, sprintf('%s: %s', arms(a).short, t), 'FontSize', 10);
        if a == 1 && k == 1, legend(ax, 'Location', 'northwest', 'FontSize', 8); end
        if a == numel(arms), xlabel(ax, 'Age'); end
    end
end
exportgraphics(fig, fullfile(out, '16_absorbing_economics.png'), 'Resolution', 140);
close(fig);

% Dashboards, and each arm's levels over the top-up
if opts.dashboards
    for a = 1:numel(arms)
        have = find(~cellfun(@isempty, R(a, :)));
        for j = have(have > 1)
            r = R{a, j};
            r.step = struct('number', '16', 'label', sprintf('%s, absorbing floor c_min = EUR %s', ...
                lower(arms(a).label), group(levels(j - 1))));
            figures.dashboard(r, fullfile(out, sprintf('16_absorbing_%s_cmin%d.png', arms(a).tag, levels(j - 1))));
        end
        sel = have(1 : min(numel(have), 6));
        if numel(sel) >= 2
            figures.compare(R(a, sel), strrep(names(sel), 'c_{min}', 'c_min'), ...
                sprintf('Step 16, %s: absorbing floor against the yearly top-up', lower(arms(a).label)), ...
                fullfile(out, sprintf('16_absorbing_%s_compare.png', arms(a).tag)));
        end
        close all
    end
end

% Tables
for a = 1:numel(arms)
    fprintf('\n%s\n', arms(a).label);
    fprintf('  %-16s %8s %9s %9s %8s %9s %22s %8s %7s\n', '', 'entry', 'bound25', 'fl/bkr', 'offgrid', 'solve s', ...
        'bankrupt 40/67/100 %', 'C25/Y0', 'C40/Y0');
    for j = 1:nl + 1
        r = R{a, j}; if isempty(r), continue; end
        c = r.checks; s = r.summary; at = @(v, age) v(s.ages == age);
        bk = '-';
        if isfield(c, 'abs_share') && all(isfinite(c.abs_share))
            bk = sprintf('%.1f/%.1f/%.1f', 100 * c.abs_share);
        end
        fprintf('  %-16s %8.3f %8.1f%% %8.2f%% %8d %9.0f %22s %8.2f %7.2f\n', strrep(names{j}, 'c_{min} = ', ''), ...
            c.ce_entry, 100 * c.c_bound_25_39, 100 * c.floored_share, sum(c.offgrid), r.timing.solve_sec, bk, ...
            at(s.C.p50, 25) / s.Y0, at(s.C.p50, 40) / s.Y0);
    end
    fprintf('  %-16s %5s %8s %8s %8s %6s %7s %8s %9s\n', '', 'age', 'C/Y0', 'X/Y0', 'NW/Y0', 'pi', 'burden', 'fl/bkr', 'entry %/y');
    for j = 1:nl + 1
        r = R{a, j}; if isempty(r), continue; end
        s = r.summary;
        h = zeros(size(s.ages)); if isfield(s, 'abs_hazard'), h = s.abs_hazard; end
        for age = [25 30 40 55 66 80 95 100]
            m = s.ages == age;
            fprintf('  %-16s %5d %8.2f %8.2f %8.2f %6.2f %7.2f %7.1f%% %8.2f%%\n', strrep(names{j}, 'c_{min} = ', ''), age, ...
                s.C.p50(m) / s.Y0, s.X.mean(m) / s.Y0, s.net_worth.mean(m) / s.Y0, s.pi(m), s.burden(m), ...
                100 * s.floored(m), 100 * h(m));
        end
    end
end
end

function c = parula_like(n)
% Colours from cool (low floor) to warm (high floor)
base = [0.10 0.45 0.85; 0.20 0.65 0.75; 0.35 0.70 0.35; 0.90 0.60 0.10; 0.80 0.20 0.20; 0.55 0.15 0.55];
if n <= size(base, 1)
    c = base(round(linspace(1, size(base, 1) - (n < 6), n)), :);
else
    c = interp1(linspace(0, 1, size(base, 1)), base, linspace(0, 1, n));
end
end

function s = group(x)
s = regexprep(sprintf('%d', round(x)), '(\d)(?=(\d{3})+$)', '$1,');
end
