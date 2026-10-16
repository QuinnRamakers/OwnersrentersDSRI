function report(cover_lines, opts)
%REPORT  Pages and PDF of the DC-branch grid study.
%
%   report(cover_lines)                      % all pages, then the PDF
%   report(cover_lines, pages=false)         % the PDF from pages already drawn
%
%   Writes into <standard numerics dir>/pension_grid/pages/:
%     conv_<arm>.png            convergence_figure: gap to the reference against
%                               grid points, as-is uniform grids and the fix
%     grid_NN_<step>_<arm>.png  robustness_pages: every grid against the reference
%     occ_<arm>.png             occupancy_figure: where households live, against
%                               the standard grid and the fix's 32x32 grid
%     overlay_fix_<arm>.png     steps 6, 9-12 on the fix's 64x64 grid (figures.compare,
%                               pension view); overlay_asis_<arm>.png the same on
%                               the standard grid as the ladder solved it
%     step_JJ_KK_<arm>.png      each DC step against its parent on the 64x64 grid
%                               (figures.step_dashboard)
%   and pension_grid_study.pdf (cover, then the pages) in pension_grid/.
%   The fix is pi_nothing_saved = 'limit' with power-3 grids (case names
%   pow3_NxN_lim); the reference is pow3_96x96_lim where solved, else
%   pow3_64x64_lim.

arguments
    cover_lines cell
    opts.pages (1,1) logical = true
end

num = ladder.numerics('standard');
out = fullfile(num.dir, 'pension_grid', 'pages');
if ~isfolder(out), mkdir(out); end
S = ladder.steps();
dc = [12 10 11 9];
arms = {'owner', 'renter'};
fam = struct('name', {'as is: uniform grid, pi = 1 where nothing is saved', ...
                      'limit share, uniform 16x16', ...
                      'fix: limit share, power-3 grid', ...
                      'limit share, power-3 64x32 (more u1) and 32x64 (more u2)', ...
                      'limit share, points that follow age'}, ...
             'cases', {{'standard', 'uniform_32x32', 'uniform_64x64'}, ...
                       {'uniform_16x16_lim'}, ...
                       {'pow3_16x16_lim', 'pow3_32x32_lim', 'pow3_48x48_lim', 'pow3_64x64_lim'}, ...
                       {'pow3_64x32_lim', 'pow3_32x64_lim'}, ...
                       {'ageq_16x16_lim', 'ageq_24x24_lim'}});
pages = {};
if opts.pages
    for a = arms
        refs = cellfun(@(st) ref_name(st, a{1}), num2cell(dc), 'UniformOutput', false);
        f = fullfile(out, sprintf('conv_%s.png', a{1}));
        T = convergence_figure(dc, a{1}, refs, fam, f);
        writetable(T, fullfile(out, sprintf('conv_%s.csv', a{1})));
    end
    groups = struct('name', {'As is: uniform grids, pi = 1 where nothing is saved', ...
                             'Limit share: uniform 16x16, then power-3 grids', ...
                             'Limit share: other placements'}, ...
                    'cases', {{'standard', 'uniform_32x32', 'uniform_64x64'}, ...
                              {'uniform_16x16_lim', 'pow3_16x16_lim', 'pow3_32x32_lim', 'pow3_64x64_lim'}, ...
                              {'u1only_32x32_lim', 'u2only_32x32_lim', 'pow3_48x48_lim', 'ageq_16x16_lim', 'ageq_24x24_lim'}});
    for st = dc
        for a = arms
            robustness_pages(st, a, ref_name(st, a{1}), groups, out);
        end
    end
    g6 = struct('name', {'Uniform grids (u2 and u3 collapse without a pension)'}, ...
                'cases', {{'standard', 'uniform_32x32', 'uniform_64x64'}});
    robustness_pages(6, arms, 'uniform_128x128', g6, out);
    for a = arms
        occupancy_figure([6 9 10 11 12], a{1}, 'pow3_64x64_lim', {'uniform_16x16', 'pow3_32x32_lim'}, ...
            fullfile(out, sprintf('occ_%s.png', a{1})));
        for v = {'fix', 'asis'}
            if strcmp(v{1}, 'fix'), names = [{best6(a{1})}, repmat({'pow3_64x64_lim'}, 1, 4)];
            else, names = repmat({'standard'}, 1, 5); end
            st5 = [6 9 10 11 12];
            rs = cell(1, 5); labels = cell(1, 5);
            for i = 1:5
                rs{i} = case_load(st5(i), a{1}, names{i});
                k = ladder.index(st5(i), S);
                labels{i} = sprintf('%s %s (%s)', ladder.number(k, S), S(k).name, names{i});
            end
            if any(cellfun(@isempty, rs)), continue; end
            f = fullfile(out, sprintf('overlay_%s_%s.png', v{1}, a{1}));
            figures.compare(rs, labels, sprintf('Steps 6, 9-12, %s: %s', a{1}, ...
                strrep(strrep(v{1}, 'asis', 'standard grid as solved'), 'fix', 'the fix (limit share, power-3 64x64)')), ...
                f, view = 'pension');
            if strcmp(v{1}, 'fix')
                % Each DC step against the step it builds on, as ladder.compare draws them
                for i = 2:5
                    kP = ladder.index(st5(i - 1), S); kK = ladder.index(st5(i), S);
                    f = fullfile(out, sprintf('step_%s_%s_%s.png', ladder.number(kP, S, true), ...
                        ladder.number(kK, S, true), a{1}));
                    figures.step_dashboard(rs{i - 1}, rs{i}, labels(i - 1:i), sprintf(['Step %s, %s: %s ' ...
                        'against step %s, on the converged grid (limit share, power-3 64x64)'], ...
                        ladder.number(kK, S), S(kK).label, a{1}, ladder.number(kP, S)), f);
                end
            end
        end
    end
end

% Page order
for a = arms
    pages{end+1} = fullfile(out, sprintf('conv_%s.png', a{1})); %#ok<AGROW>
end
for a = arms
    pages{end+1} = fullfile(out, sprintf('occ_%s.png', a{1})); %#ok<AGROW>
end
for st = dc
    k = ladder.index(st, S);
    for a = arms
        pages{end+1} = fullfile(out, sprintf('grid_%s_%s_%s.png', ladder.number(k, S, true), S(k).name, a{1})); %#ok<AGROW>
    end
end
k6 = ladder.index(6, S);
for a = arms
    pages{end+1} = fullfile(out, sprintf('grid_%s_%s_%s.png', ladder.number(k6, S, true), S(k6).name, a{1})); %#ok<AGROW>
end
for a = arms
    pages{end+1} = fullfile(out, sprintf('overlay_asis_%s.png', a{1})); %#ok<AGROW>
    pages{end+1} = fullfile(out, sprintf('overlay_fix_%s.png', a{1})); %#ok<AGROW>
end
for a = arms
    for j = [6 9 10 11; 9 10 11 12]
        pages{end+1} = fullfile(out, sprintf('step_%s_%s_%s.png', ladder.number(ladder.index(j(1), S), S, true), ...
            ladder.number(ladder.index(j(2), S), S, true), a{1})); %#ok<AGROW>
    end
end

pdf = fullfile(num.dir, 'pension_grid', 'pension_grid_study.pdf');
if isfile(pdf), delete(pdf); end
cover(pdf, 'Grid study of the DC branch (steps 9-12)', cover_lines);
for i = 1:numel(pages)
    if isfile(pages{i}), add_png(pdf, pages{i}); else, fprintf('missing page %s\n', pages{i}); end
end
fprintf('Wrote %s\n', pdf);
end

function n = ref_name(st, arm)
n = 'pow3_96x96_lim';
if isempty(case_load(st, arm, n)), n = 'pow3_64x64_lim'; end
end

function cover(pdf, ttl, lines)
fig = figure('Visible', 'off', 'Position', [0 0 1700 2200], 'Color', 'w');
ax = axes(fig, 'Position', [0.05 0.03 0.9 0.94]); axis(ax, 'off');
text(ax, 0, 1, ttl, 'FontSize', 20, 'FontWeight', 'bold', 'VerticalAlignment', 'top', 'Interpreter', 'none');
text(ax, 0, 0.96, lines, 'FontSize', 11, 'VerticalAlignment', 'top', 'Interpreter', 'none');
exportgraphics(fig, pdf, 'Append', true, 'ContentType', 'image', 'Resolution', 100);
close(fig);
end

function add_png(pdf, file)
I = imread(file);
[h, w, ~] = size(I);
fig = figure('Visible', 'off', 'Position', [0 0 round(w / 1.3) round(h / 1.3)], 'Color', 'w');
ax = axes(fig, 'Position', [0 0 1 1]);
image(ax, I); axis(ax, 'image', 'off');
exportgraphics(fig, pdf, 'Append', true, 'ContentType', 'image', 'Resolution', 110);
close(fig);
end

function n = best6(arm)
% Step 6 has no pension and is converged on every grid; its finest solve
n = 'uniform_64x64';
if isempty(case_load(6, arm, n)), n = 'standard'; end
end
