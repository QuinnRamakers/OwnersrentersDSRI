function absorbing_economics(levels)
%ABSORBING_ECONOMICS  Step 16 with the absorbing floor at several c_min, against the yearly top-up.
%
%   From the repository root:
%       addpath diagnostics/nibud diagnostics/pension_grid
%       absorbing_economics                 % c_min 6,000, 8,000 and 10,000
%
%   For each arm (owner with maintenance on the current value, owner with
%   maintenance on the purchase price, renter) loads the summary-grid solves of
%   20 October, with the yearly top-up at phi_floor, and the same grids with
%   the absorbing floor (case suffix _cmin<n>, solved with solve_cases). Writes,
%   in summary_step16/ next to the ladder results:
%     16_absorbing_economics.png        by age, every arm and level: median
%                                       consumption, mean liquid saving and
%                                       liquid equity share of the solvent, the
%                                       share bankrupt and the yearly entry rate
%     16_absorbing_<arm>_cmin<n>.png    the dashboard of each arm and level
%     16_absorbing_<arm>_compare.png    each arm's levels over the top-up
%   and prints the checks and the main quantities at a few ages.

arguments
    levels (1,:) double = [6000 8000 10000]
end

num = ladder.numerics('standard');
out = fullfile(num.dir, 'summary_step16');
if ~isfolder(out), mkdir(out); end

arms = struct('tag', {'owner_current', 'owner_purchase', 'renter'}, ...
    'arm', {'owner', 'owner', 'renter'}, ...
    'base', {'pow3_16x16_lim_u3p2_qn4_nosweep', 'pow3_16x16_lim_u3p2_qn4_nosweep', 'pow3_16x16_lim_u3p2_u3n20'}, ...
    'mop', {'', '_mop', ''}, ...
    'label', {'Owner, maintenance on the current value', 'Owner, maintenance on the purchase price', 'Renter'});
nl = numel(levels);
R = cell(numel(arms), nl + 1);
for a = 1:numel(arms)
    A = arms(a);
    R{a, 1} = case_load(16, A.arm, [A.base A.mop]);
    for j = 1:nl
        R{a, j + 1} = case_load(16, A.arm, sprintf('%s_cmin%d%s', A.base, levels(j), A.mop));
    end
end
assert(~any(cellfun(@isempty, R(:))), 'absorbing_economics:missing', 'a case is not solved.');
names = [{'top-up at 1e-6'}, arrayfun(@(c) sprintf('c_{min} = EUR %s', group(c)), levels, 'UniformOutput', false)];
cols  = [0 0 0; 0.20 0.55 0.85; 0.85 0.45 0.10; 0.60 0.15 0.55; 0.25 0.65 0.35];

% One page: arms in rows
fig = figure('Visible', 'off', 'Position', [30 30 2300 1300], 'Color', 'w');
tl  = tiledlayout(fig, numel(arms), 5, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, {'Step 16: the absorbing consumption floor against the yearly top-up', ...
    ['Summary grids of 20 October; levels in multiples of entry income; saving and equity share over ' ...
     'solvent households; c_{min} is the floor of the median owner in euros, the same share of income for renters']}, ...
    'FontSize', 13, 'FontWeight', 'bold');
for a = 1:numel(arms)
    for k = 1:5
        ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
        ax.XLim = [25 100]; ax.FontSize = 9;
        xline(ax, 67, 'k:', 'HandleVisibility', 'off');
        for j = 1:nl + 1
            s = R{a, j}.summary; x = s.ages; ls = '-'; if j == 1, ls = '--'; end
            switch k
                case 1, y = s.C.p50 / s.Y0;
                case 2, y = s.X.mean / s.Y0;
                case 3, y = s.pi;  y(end) = NaN;
                case 4, y = 100 * s.floored;
                case 5
                    if j == 1, continue; end
                    y = 100 * s.abs_hazard;
            end
            plot(ax, x, y, ls, 'Color', cols(j, :), 'LineWidth', 1.8, 'DisplayName', names{j});
        end
        switch k
            case 1, ylabel(ax, 'times entry income'); t = 'median consumption';
            case 2, ylabel(ax, 'times entry income'); t = 'mean liquid saving';
            case 3, ylabel(ax, 'share'); ylim(ax, [0 1]); t = 'liquid equity share';
            case 4, ylabel(ax, '% of households'); t = 'bankrupt (top-up: floored this year)';
            case 5, ylabel(ax, '% a year'); t = 'yearly rate of going bankrupt';
        end
        title(ax, sprintf('%s: %s', A_label(arms(a)), t), 'FontSize', 10);
        if a == 1 && k == 1, legend(ax, 'Location', 'northwest', 'FontSize', 8); end
        if a == numel(arms), xlabel(ax, 'Age'); end
    end
end
exportgraphics(fig, fullfile(out, '16_absorbing_economics.png'), 'Resolution', 150);
close(fig);

% Dashboards, and each arm's levels over the top-up
for a = 1:numel(arms)
    for j = 1:nl
        r = R{a, j + 1};
        r.step = struct('number', '16', 'label', sprintf('%s, absorbing floor c_min = EUR %s', ...
            lower(arms(a).label), group(levels(j))));
        figures.dashboard(r, fullfile(out, sprintf('16_absorbing_%s_cmin%d.png', arms(a).tag, levels(j))));
    end
    figures.compare(R(a, :), strrep(names, 'c_{min}', 'c_min'), ...
        sprintf('Step 16, %s: absorbing floor at three levels against the yearly top-up', lower(arms(a).label)), ...
        fullfile(out, sprintf('16_absorbing_%s_compare.png', arms(a).tag)));
    close all
end

% Tables
for a = 1:numel(arms)
    fprintf('\n%s\n', arms(a).label);
    fprintf('  %-16s %8s %9s %9s %8s %9s %22s %8s %7s\n', '', 'entry', 'bound25', 'fl/bkr', 'offgrid', 'solve s', ...
        'bankrupt 40/67/100 %', 'C25/Y0', 'C40/Y0');
    for j = 1:nl + 1
        r = R{a, j}; c = r.checks; s = r.summary; at = @(v, age) v(s.ages == age);
        bk = '-';
        if isfield(c, 'abs_share') && all(isfinite(c.abs_share))
            bk = sprintf('%.1f/%.1f/%.1f', 100 * c.abs_share);
        end
        fprintf('  %-16s %8.3f %8.1f%% %8.2f%% %8d %9.0f %22s %8.2f %7.2f\n', strrep(names{j}, 'c_{min} = ', ''), ...
            c.ce_entry, 100 * c.c_bound_25_39, 100 * c.floored_share, sum(c.offgrid), r.timing.solve_sec, bk, ...
            at(s.C.p50, 25) / s.Y0, at(s.C.p50, 40) / s.Y0);
    end
    fprintf('  %-16s %5s %8s %8s %8s %6s %8s %9s\n', '', 'age', 'C/Y0', 'X/Y0', 'NW/Y0', 'pi', 'fl/bkr', 'entry %/y');
    for j = 1:nl + 1
        s = R{a, j}.summary;
        h = zeros(size(s.ages)); if isfield(s, 'abs_hazard'), h = s.abs_hazard; end
        for age = [25 30 40 55 66 80 95 100]
            m = s.ages == age;
            fprintf('  %-16s %5d %8.2f %8.2f %8.2f %6.2f %7.1f%% %8.2f%%\n', strrep(names{j}, 'c_{min} = ', ''), age, ...
                s.C.p50(m) / s.Y0, s.X.mean(m) / s.Y0, s.net_worth.mean(m) / s.Y0, s.pi(m), ...
                100 * s.floored(m), 100 * h(m));
        end
    end
end
end

function t = A_label(A)
t = A.label;
if strcmp(A.tag, 'owner_current'), t = 'Owner, current value'; end
if strcmp(A.tag, 'owner_purchase'), t = 'Owner, purchase price'; end
end

function s = group(x)
s = regexprep(sprintf('%d', round(x)), '(\d)(?=(\d{3})+$)', '$1,');
end
