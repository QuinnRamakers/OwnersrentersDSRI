function axes_pdf(numerics)
%AXES_PDF  The grid-axis pages of steps 6 and 9-12 and the runtime map, in one PDF.
%
%   axes_pdf()               % standard numerics
%
%   Run after ladder.grid_axes(k) for k = 6, 9, 10, 11, ladder.grid_axes(12,
%   ladders=true) and runtime_map. Writes <numerics dir>/robustness/grid_axes.pdf:
%   an intro page with the largest gap of each one-axis variant to the step as
%   solved, then the runtime map, then one page per step and arm.

if nargin < 1, numerics = 'standard'; end
num = ladder.numerics(numerics); S = ladder.steps(); d = fullfile(num.dir, 'robustness');
arms = {'nohousing_renter', 'nohousing_owner'};
pdf = fullfile(d, 'grid_axes.pdf');
if isfile(pdf), delete(pdf); end

one = {'u1 x2', [32 16 10], 5, 1, 1; 'u2 x2', [16 32 10], 5, 1, 1; 'u3 x2', [16 16 20], 5, 1, 1; ...
       '7 shock nodes', [16 16 10], 7, 1, 1};
L = {'Each axis refined on its own, standard numerics [16 16 10] with 5 quadrature nodes:', ...
     '  u1  income over total resources; 1/u1 is total resources in years of income', ...
     '  u2  the pension account (and house) against liquid savings', ...
     '  u3  the pension account against the house: collapsed without housing', ...
     '  quadrature: nodes per shock (income, stocks)', '', ...
     'Largest gap to the step as solved, ages 26-95: equity share, consumption %, liquid savings in years of income', ...
     sprintf('  %-26s %-18s %s', 'step, arm', 'variant', '  pi      C     X/Y')};
for k = [6 9 10 11 12]
    for a = arms
        f0 = ladder.result_file(num, k, S(k).name, a{1});
        if ~isfile(f0), continue; end
        s0 = load(f0, 'summary'); s0 = s0.summary; w = s0.ages >= 26 & s0.ages <= 95;
        for i = 1:size(one, 1)
            s1 = find_run(d, k, S(k).name, a{1}, one(i, 2:5));
            if isempty(s1), continue; end
            L{end+1} = sprintf('  %-26s %-18s %5.3f %5.1f%% %6.3f', sprintf('%d %s, %s', k, S(k).name, ...
                erase(a{1}, 'nohousing_')), one{i, 1}, max(abs(s1.pi(w) - s0.pi(w))), ...
                100 * max(abs(s1.C.mean(w) ./ s0.C.mean(w) - 1)), ...
                max(abs(s1.X.mean(w) - s0.X.mean(w)) ./ s0.Y.mean(w))); %#ok<AGROW>
        end
    end
end
cover(pdf, 'Which grid axis matters, and what it costs', L);
add_png(pdf, fullfile(d, 'runtime_map.png'));
for k = [12 11 10 9 6]
    for a = arms
        f = fullfile(d, sprintf('robust_axes_%02d_%s_%s.png', k, S(k).name, a{1}));
        if isfile(f), add_png(pdf, f); end
    end
end
fprintf('wrote %s (%.1f MiB)\n', pdf, dir(pdf).bytes / 2^20);
end

% ------------------------------------------------------------------------
function s = find_run(d, k, name, arm, spec)
% The summary of the saved run with these grid dims, quadrature and placement.
s = [];
L = builtin('dir', fullfile(d, sprintf('%02d_%s_%s_*.mat', k, name, arm)));
for i = 1:numel(L)
    r = load(fullfile(d, L(i).name), 'p');
    p = r.p;
    if isequal(p.grid_dims, spec{1}) && p.gh_n == spec{2} && p.grid_pow == spec{3} && ...
            p.grid_pow_u2 == spec{4} && strcmp(p.fmincon_algorithm, 'interior-point') && p.use_refine
        r = load(fullfile(d, L(i).name), 'summary'); s = r.summary; return
    end
end
end

function cover(pdf, ttl, lines)
fig = figure('Visible', 'off', 'Position', [0 0 1600 1000], 'Color', 'w');
ax = axes(fig, 'Position', [0.04 0.04 0.92 0.90]); axis(ax, 'off');
text(ax, 0, 1, ttl, 'FontSize', 20, 'FontWeight', 'bold', 'VerticalAlignment', 'top', 'Interpreter', 'none');
fs = 12; if numel(lines) > 30, fs = 8.5; end
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
