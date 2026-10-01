function fig_rent_channel(out_dir)
%FIG_RENT_CHANNEL  The early-life ruin region is the rent obligation.
%
%   The region sits at low u1 -- income small relative to wealth -- and at the
%   production calibration its upper edge reaches into the band households of
%   34 actually occupy. alpha enters the budget only through the carrying-cost
%   rate, so scaling it scales the rent obligation and leaves everything else
%   alone. Scanning the same u1 line at three values of alpha, on one cube,
%   isolates the obligation from the resolution.
%
%   For a renter H is a rent index, not a house: config.h_process gives it no
%   resale and no bequest value, and its only role is to set the rent alpha*H.
%   The cube nevertheless counts it inside wealth, W = Y + X + A + H, so a
%   state with a small u1 and a large illiquid share describes a household
%   whose wealth is largely an obligation and whose income is small beside it.

if nargin < 1 || isempty(out_dir), out_dir = fileparts(mfilename('fullpath')); end
fd = fullfile(out_dir, 'factorial_figs');
L  = load(fullfile(out_dir, 'rent_channel.mat')); G = L.G;
[~, o] = sort([G.alpha], 'descend'); G = G(o);
nA = numel(G); g = 5;
col = [0.85 0.33 0.10; 0.45 0.30 0.70; 0.15 0.45 0.75];
col = col(1:nA, :);
AGES = 24 + G(1).t;

occ = [];
osrc = fullfile(out_dir, 'occupancy_src.mat');
if isfile(osrc), Q = load(osrc); occ = Q.s; end

f  = figure('Position', [10 10 640*numel(AGES) 880], 'Color', 'w', 'Visible', 'off');
tl = tiledlayout(f, 2, numel(AGES), 'Padding', 'compact', 'TileSpacing', 'compact');
h  = gobjects(nA, 1);
fprintf('\n=== the ruin region against the rent obligation, cube %s ===\n', mat2str(G(1).N));
fprintf('%-8s %-28s %10s %14s %14s\n', 'age', 'rent, % of take-home income', 'alpha', ...
    'ruin reaches u1', 'z at u1 = 0.13');
for ai = 1:numel(AGES)
    ax1 = nexttile(tl, ai);               hold(ax1, 'on'); grid(ax1, 'on'); ax1.GridAlpha = .12;
    ax2 = nexttile(tl, numel(AGES) + ai); hold(ax2, 'on'); grid(ax2, 'on'); ax2.GridAlpha = .12;
    for i = 1:nA
        u1 = G(i).u1(:).';
        fr = nan(size(u1)); zb = nan(size(u1));
        for j = 1:numel(u1)
            k  = sub2ind(G(i).N, j, G(i).i2(ai), G(i).i3(ai));
            fn = fullfile(G(i).dir, sprintf('scan_t%03d_k%06d.mat', G(i).t(ai), k));
            if ~isfile(fn), continue; end
            S = load(fn);
            Z = ((1-g)*S.rhs).^(1/(1-g)); Z(~isfinite(Z)) = 0; Z = max(Z, 0);
            zb(j) = max(Z(:));
            if zb(j) > 0, fr(j) = mean(Z(:) <= 0.02*zb(j)); end
        end
        hh = plot(ax1, u1, 100*fr, '-o', 'Color', col(i, :), 'LineWidth', 2, ...
            'MarkerSize', 4, 'MarkerFaceColor', col(i, :));
        plot(ax2, u1, zb, '-o', 'Color', col(i, :), 'LineWidth', 2, ...
            'MarkerSize', 4, 'MarkerFaceColor', col(i, :));
        if ai == 1, h(i) = hh; end
        k = find(fr > 0.01, 1, 'last'); ub = NaN; if ~isempty(k), ub = u1(k); end
        fprintf('%-8d %-28.0f %10.3f %14.4f %14.4f\n', AGES(ai), 100*G(i).rent_share, ...
            G(i).alpha, ub, interp1(u1, zb, 0.13));
    end
    if ~isempty(occ)
        tt = min(G(1).t(ai), size(occ.lambda, 2));
        q  = prctile(occ.lambda(:, tt), [5 95]);
        for ax = [ax1 ax2]
            yl = ylim(ax);
            patch(ax, [q(1) q(2) q(2) q(1)], [yl(1) yl(1) yl(2) yl(2)], [.55 .75 .95], ...
                'FaceAlpha', .20, 'EdgeColor', 'none');
            uistack(findobj(ax, 'Type', 'patch'), 'bottom');
            ylim(ax, yl);
        end
    end
    set([ax1 ax2], 'XScale', 'log');
    xlabel(ax1, 'u1  (income as a share of wealth)');
    ylabel(ax1, 'share of the (c, \pi) square that is ruin, %');
    title(ax1, sprintf('age %d', AGES(ai)), 'FontWeight', 'normal');
    xlabel(ax2, 'u1  (income as a share of wealth)');
    ylabel(ax2, 'best z at the node');
    title(ax2, sprintf('age %d: the value itself', AGES(ai)), 'FontWeight', 'normal');
end
ok = find(isgraphics(h)).';
lg = legend(h(ok), arrayfun(@(q) sprintf('\\alpha = %.3f  (rent = %.0f%% of take-home income)', ...
    q.alpha, 100*q.rent_share), G(ok), 'uni', 0), 'Box', 'off', 'NumColumns', numel(ok), ...
    'Interpreter', 'tex');
lg.Layout.Tile = 'south';
sgtitle(f, sprintf(['The early-life ruin region is the rent obligation. One cube (%s), three rent levels, ' ...
    'the same u1 line.\nShaded = where households of that age actually sit. ' ...
    'At the production calibration the region reaches into that band; at a third of the rent it is gone.'], ...
    mat2str(G(1).N)), 'FontWeight', 'normal', 'FontSize', 11, 'Interpreter', 'tex');
exportgraphics(f, fullfile(fd, 'S35_rent_channel.png'), 'Resolution', 120); close(f);
fprintf('\nS35 written\n');
end
