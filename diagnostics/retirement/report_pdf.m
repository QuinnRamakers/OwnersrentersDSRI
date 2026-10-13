function report_pdf(numerics)
%REPORT_PDF  Every page of the retirement steps (9-12) and their sensitivities, in two PDFs.
%
%   report_pdf()              % standard numerics
%   report_pdf('quick')
%
%   Run from the repository root after
%       ladder.run(9:12); for k = 9:12, ladder.compare(k); end
%       ladder.compare('dc_glide', against='dc_bonds')
%       ladder.overlay([6 9 10 11 12], view='pension', name='retirement')
%       ladder.overlay([9 10 11], view='pension', name='dc_funds')
%       ladder.sensitivity('aow')
%       for k = 9:12, ladder.robustness(k); end
%   Collects the saved pages, with an intro page per section that lists the
%   main numbers, in <numerics dir>/retirement_dashboards_part1.pdf
%   (sections 1-3: overview, steps 9 and 10) and _part2.pdf (sections 4-6:
%   steps 11 and 12, sensitivities), each under 30 MB so it can be sent, and
%   each opening with the same cover page. Pages that have not been drawn
%   are listed on the intro page and skipped.

if nargin < 1, numerics = 'standard'; end
num = ladder.numerics(numerics); d = num.dir; S = ladder.steps();
arms = {'nohousing_renter', 'nohousing_owner'};
parts = {1:3, 4:6};

intro = { ...
    'All four steps build on step 6 (corr_SL), the baseline without housing; taxes and the REIT are off.', ...
    '  9  dc_bonds   DC contributions of 18.6% above the franchise, fund all in bonds, annuity at 67;', ...
    '                first pillar stays at CGM''s 68.2% of final income', ...
    ' 10  dc_stocks  fund all in stocks, in retirement too', ...
    ' 11  dc_glide   the production glide: 80% stocks until 39, to 0% at 67, bonds in retirement', ...
    ' 12  aow        first pillar falls to the AOW''s 30.7% of final income', ...
    'Then step 12 with the replacement rate at 0.20 and 0.40 and the contribution rate at 0.10 and 0.30.', '', ...
    'Standard numerics [16 16 10], 5 quadrature nodes, 10,000 households. Lines are means across households,', ...
    'bands the 10th-90th percentiles; levels in thousands of 2025 euros.', '', ...
    'Robustness in short (pages in sections 2-5): the optimisers agree at every step. The grid does not, around', ...
    'retirement: with the pension account, the finer grids raise the liquid equity share at 55-65 by up to 0.14 and', ...
    'lower liquid savings in retirement by 5-12%. Step 6, without the account, is grid-converged. Every direction', ...
    'between steps holds on the finer grids; the sizes around 55-66 do not.', '', ...
    'Sections:', '  1. Overview: all steps on one page', '  2-5. Each step against the one it builds on, its dashboards and robustness', ...
    '  6. Sensitivity of step 12 to the replacement rate and the contribution rate', '', ...
    'Part 1 holds sections 1-3, part 2 sections 4-6.'};

sec = {};
% 1. Overview
P = {}; for a = arms, P{end+1} = fullfile(d, sprintf('overlay_retirement_%s.png', a{1})); end %#ok<AGROW>
for a = arms, P{end+1} = fullfile(d, sprintf('overlay_dc_funds_%s.png', a{1})); end %#ok<AGROW>
L = [{'Overlay of steps 6 (black, no DC), 9, 10, 11 and 12 per arm; then the three funds (9, 10, 11) with 9 in black.', ''}, ...
     table_lines(d, S, [6 9 10 11 12], arms)];
sec(end+1, :) = {'1. Overview: the DC account turned on, three funds, then the AOW', L, P};

% 2-5. Each step
for k = 9:12
    j = ladder.parent(k);
    P = {};
    for a = arms, P{end+1} = fullfile(d, sprintf('compare_%02d_%02d_%s.png', j, k, a{1})); end %#ok<AGROW>
    if k == 11
        for a = arms, P{end+1} = fullfile(d, sprintf('compare_09_11_%s.png', a{1})); end %#ok<AGROW>
    end
    P{end+1} = fullfile(d, sprintf('owner_renter_%02d.png', k)); %#ok<AGROW>
    for a = arms, P{end+1} = fullfile(d, sprintf('%02d_%s_%s.png', k, S(k).name, a{1})); end %#ok<AGROW>
    for a = arms, P{end+1} = fullfile(d, 'robustness', sprintf('robust_%02d_%s_%s.png', k, S(k).name, a{1})); end %#ok<AGROW>
    L = [wrap(sprintf('Step %d %s against step %d %s. %s', k, S(k).name, j, S(j).name, S(k).note), 105), {'', ...
          'Pages: the step against its parent per arm, renter against owner, the twelve-panel dashboard per arm,'}, {...
          'and the robustness page per arm (other optimisers, the global search off, coarser and finer grids).', ''}, ...
         robust_lines(d, k, S(k).name, arms)];
    sec(end+1, :) = {sprintf('%d. Step %d: %s', k - 7, k, S(k).label), L, P}; %#ok<AGROW>
end

% 6. Sensitivities
P = {}; vary = S(12).vary;
for a = arms
    for f = fieldnames(vary).'
        P{end+1} = fullfile(d, 'sensitivity', sprintf('sens_12_aow_%s_%s.png', a{1}, f{1})); %#ok<AGROW>
        for v = vary.(f{1})
            P{end+1} = fullfile(d, 'sensitivity', sprintf('sens_12_aow_%s_%s_%s.png', a{1}, f{1}, ...
                strrep(sprintf('%g', v), '.', 'p'))); %#ok<AGROW>
        end
    end
end
L = [{'Step 12 with one primitive moved at a time (illustrative values): per arm, an overlay of each primitive,', ...
      'then each value against step 12 on the twelve-panel page.', ''}, sens_lines(d, arms, vary)];
sec(end+1, :) = {'6. Step 12: replacement rate 0.20 / 0.40, contribution rate 0.10 / 0.30', L, P};

for q = 1:numel(parts)
    pdf = fullfile(d, sprintf('retirement_dashboards_part%d.pdf', q));
    if isfile(pdf), delete(pdf); end
    cover(pdf, sprintf('Retirement steps 9-12: the DC pension without housing (part %d of %d)', ...
        q, numel(parts)), intro);
    for s = parts{q}
        have = cellfun(@isfile, sec{s, 3});
        L = sec{s, 2};
        if any(~have)
            [~, nm, ext] = cellfun(@fileparts, sec{s, 3}(~have), 'UniformOutput', false);
            L = [L, {'', 'Not drawn yet, skipped:'}, strcat({'  '}, nm, ext)]; %#ok<AGROW>
        end
        cover(pdf, sec{s, 1}, L);
        for f = sec{s, 3}(have), add_png(pdf, f{1}); end
    end
    mb = dir(pdf).bytes / 2^20;
    fprintf('wrote %s (%.1f MiB)\n', pdf, mb);
    if mb > 30, warning('report_pdf:size', '%s is over 30 MiB; move a section to the other part.', pdf); end
end
end

% ------------------------------------------------------------------------
function L = table_lines(d, S, ks, arms)
% Median consumption, mean liquid savings, mean DC account (over entry income)
% and the mean liquid equity share at a few ages.
ages = [35 45 55 66 75 85];
L = {sprintf('%-22s %-24s %s', '', '', strjoin(arrayfun(@(a) sprintf('%6d', a), ages, 'UniformOutput', false), ''))};
for a = arms
    L{end+1} = a{1}; %#ok<AGROW>
    for k = ks
        f = fullfile(d, sprintf('%02d_%s_%s.mat', k, S(k).name, a{1}));
        if ~isfile(f), continue; end
        s = load(f, 'summary'); s = s.summary; m = ismember(s.ages, ages);
        rows = {'consumption / Y0', s.C.p50(m) / s.Y0; 'liquid savings / Y0', s.X.mean(m) / s.Y0; ...
                'DC account / Y0', s.A.mean(m) / s.Y0; 'liquid equity share', s.pi(m)};
        for r = 1:size(rows, 1)
            lab = ''; if r == 1, lab = sprintf('%d %s', k, S(k).name); end
            L{end+1} = sprintf('  %-20s %-24s %s', lab, rows{r, 1}, sprintf('%6.2f', rows{r, 2})); %#ok<AGROW>
        end
    end
end
end

function L = robust_lines(d, k, name, arms)
% Largest gap to the step as run, ages 26-95, per robustness variant.
vars = {'as_sweep', 'active-set with sweep'; 'sqp_sweep', 'sqp with sweep'; 'ip_nosweep', 'interior-point, no sweep'; ...
        'as_nosweep', 'active-set, no sweep'; 'coarse', 'grid [9 9 6], 3 nodes'; 'quick', 'grid [12 12 8], 3 nodes'; ...
        'fine', 'grid [20 20 12], 5 nodes'; 'dense_u1', 'grid [32 16 10], 5 nodes'};
L = {'Robustness, largest gap to the step as run over ages 26-95 (stock share in points, consumption in %,', ...
     'liquid savings in years of income):'};
for a = arms
    f0 = fullfile(d, sprintf('%02d_%s_%s.mat', k, name, a{1}));
    if ~isfile(f0), continue; end
    s0 = load(f0, 'summary'); s0 = s0.summary; w = s0.ages >= 26 & s0.ages <= 95;
    L{end+1} = ['  ' a{1}]; %#ok<AGROW>
    for v = 1:size(vars, 1)
        f = fullfile(d, 'robustness', sprintf('%02d_%s_%s_%s.mat', k, name, a{1}, vars{v, 1}));
        if ~isfile(f), continue; end
        s1 = load(f, 'summary'); s1 = s1.summary;
        L{end+1} = sprintf('    %-26s %5.1f  %5.1f%%  %5.2f', vars{v, 2}, 100 * max(abs(s1.pi(w) - s0.pi(w))), ...
            100 * max(abs(s1.C.mean(w) ./ s0.C.mean(w) - 1)), max(abs(s1.X.mean(w) - s0.X.mean(w)) ./ s0.Y.mean(w))); %#ok<AGROW>
    end
end
end

function L = sens_lines(d, arms, vary)
ages = [35 45 55 66 75 85];
L = {sprintf('%-30s %s', '', strjoin(arrayfun(@(a) sprintf('%6d', a), ages, 'UniformOutput', false), ''))};
for a = arms
    L{end+1} = a{1}; %#ok<AGROW>
    files = {fullfile(d, sprintf('12_aow_%s.mat', a{1}))}; labs = {'step 12'};
    for f = fieldnames(vary).'
        for v = vary.(f{1})
            files{end+1} = fullfile(d, 'sensitivity', sprintf('12_aow_%s_%s_%s.mat', a{1}, f{1}, ...
                strrep(sprintf('%g', v), '.', 'p'))); %#ok<AGROW>
            labs{end+1} = sprintf('%s %g', f{1}, v); %#ok<AGROW>
        end
    end
    for i = 1:numel(files)
        if ~isfile(files{i}), continue; end
        s = load(files{i}, 'summary'); s = s.summary; m = ismember(s.ages, ages);
        L{end+1} = sprintf('  %-18s C/Y0   %s', labs{i}, sprintf('%6.2f', s.C.p50(m) / s.Y0)); %#ok<AGROW>
        L{end+1} = sprintf('  %-18s X/Y0   %s', '', sprintf('%6.2f', s.X.mean(m) / s.Y0)); %#ok<AGROW>
        L{end+1} = sprintf('  %-18s pi     %s', '', sprintf('%6.2f', s.pi(m))); %#ok<AGROW>
    end
end
end

function lines = wrap(s, n)
% Break a line into pieces of at most n characters.
lines = {};
while numel(s) > n
    cut = find(s(1:n) == ' ', 1, 'last');
    if isempty(cut), cut = n; end
    lines{end+1} = s(1:cut - 1); %#ok<AGROW>
    s = strtrim(s(cut:end));
end
lines{end+1} = s;
end

function cover(pdf, ttl, lines)
fig = figure('Visible', 'off', 'Position', [0 0 1600 1000], 'Color', 'w');
ax = axes(fig, 'Position', [0.04 0.04 0.92 0.90]); axis(ax, 'off');
text(ax, 0, 1, ttl, 'FontSize', 20, 'FontWeight', 'bold', 'VerticalAlignment', 'top', 'Interpreter', 'none');
fs = 13; if numel(lines) > 30, fs = 9; end
text(ax, 0, 0.93, lines, 'FontSize', fs, 'VerticalAlignment', 'top', 'Interpreter', 'none', 'FontName', 'Consolas');
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
