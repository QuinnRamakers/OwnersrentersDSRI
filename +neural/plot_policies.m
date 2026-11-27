function fig = plot_policies(p, pols, ref, opts)
%PLOT_POLICIES  Consumption and equity-share policies against liquid wealth, at chosen ages.
%
%   pols = {'grid, standard', neural.grid_policy_fn(r_std), 'grid_std'; ...
%           'network', load('neural/data/net_step18_renter_k3000_run1.mat'), 'net1'};
%   neural.plot_policies(r_std.p, pols, cmp.net, ages=[30 45 60 70 85], file='step18_renter_policies.png')
%
%   At each age the household holds the median pension pot, house (or rent
%   index) and q of the solvent households in ref (a profiles struct of
%   neural.compare_panels), and its liquid wealth X runs from 0 up; all in
%   multiples of current income Y (the model is homothetic, so this is the
%   whole policy along that line). Top row: consumption C/Y, with the floor
%   and the bankrupt region (resources below the floor, X left of the dotted
%   line). Bottom row: the liquid equity share. The grey band is the 5th to
%   95th percentile of X/Y among ref's solvent households at that age. pols
%   rows: a label, a grid policy (neural.grid_policy_fn) or an exported
%   network, and a style as neural.plot_lifecycles.

arguments
    p struct
    pols cell
    ref struct
    opts.ages double = [30 45 60 70 85]
    opts.title char = ''
    opts.file char = 'policies.png'
end

col = struct('grid_std', [0.55 0.55 0.55], 'grid_fine', [0.05 0.05 0.05], ...
    'net1', [42 120 214] / 255, 'net2', [235 104 52] / 255, 'net3', [27 175 122] / 255, 'net4', [237 161 0] / 255);
sty = struct('grid_std', '--', 'grid_fine', '-', 'net1', '-', 'net2', '-', 'net3', '-', 'net4', '-');
ink2 = [82 81 78] / 255;
[~, ~, ann_price] = config.model_inputs(p);
na = numel(opts.ages);
fig = figure('Color', [252 252 251] / 255, 'Position', [50 50 300 * na + 100 700], 'Visible', 'off');
tl = tiledlayout(fig, 2, na, 'TileSpacing', 'compact', 'Padding', 'compact');
axs = gobjects(2, na);
for j = 1:na
    axs(1, j) = nexttile(tl, j);
    axs(2, j) = nexttile(tl, na + j);
end
for j = 1:na
    t = opts.ages(j) - p.age0 + 1;
    A = ref.AY_med(t); H = ref.HY_med(t); q = ref.q_med(t);
    xmax = max(1.5 * ref.XY_p95(t), 1);
    X = linspace(0, xmax, 400).';
    n = numel(X);
    W = X + A + H + 1;
    u1 = 1 ./ W;
    u2 = (A + H) ./ (W - 1) .* ones(n, 1);
    u3 = A / max(A + H, 1e-12) * ones(n, 1);
    qv = q * ones(n, 1);
    LW = X + take_home(p, t, ann_price, A, H, q);
    F = p.phi_path(t);
    gone = LW < F;
    for a = 1:2
        ax = axs(a, j); hold(ax, 'on');
        lo = ref.XY_p05(t); hi = ref.XY_p95(t);
        patch(ax, [lo hi hi lo], [0 0 1 1] * 1e3, [0.9 0.9 0.89], 'EdgeColor', 'none', 'HandleVisibility', 'off');
        if any(gone), xline(ax, max(X(gone)), ':', 'Color', ink2, 'HandleVisibility', 'off'); end
    end
    ymax = 0;
    for k = 1:size(pols, 1)
        pol = pols{k, 2};
        if isfield(pol, 'W1')
            [s, pi_] = neural.net_policy(pol, p, t, u1, u2, u3, qv);
            C = F + s .* max(LW - F, 0);
        else
            [c, pi_] = pol.fn(t, u1, u2, u3, qv);
            C = max(c .* max(LW, 0), F);
        end
        C(gone) = F; pi_(gone) = NaN;
        saved = LW - C > 1e-9 * max(LW, 1);
        pi_(~saved) = NaN;
        plot(axs(1, j), X, C, sty.(pols{k, 3}), 'Color', col.(pols{k, 3}), 'LineWidth', 1.6, 'DisplayName', pols{k, 1});
        plot(axs(2, j), X, pi_, sty.(pols{k, 3}), 'Color', col.(pols{k, 3}), 'LineWidth', 1.6, 'DisplayName', pols{k, 1});
        ymax = max(ymax, max(C));
    end
    plot(axs(1, j), X, F * ones(n, 1), ':', 'Color', [0.8 0.2 0.2], 'LineWidth', 1, 'DisplayName', 'floor');
    ylim(axs(1, j), [0, 1.05 * ymax]); ylim(axs(2, j), [0 1.02]);
    xlim(axs(1, j), [0 xmax]); xlim(axs(2, j), [0 xmax]);
    title(axs(1, j), sprintf('age %d: consumption', opts.ages(j)), 'FontWeight', 'normal', 'FontSize', 11);
    title(axs(2, j), sprintf('age %d: equity share', opts.ages(j)), 'FontWeight', 'normal', 'FontSize', 11);
    subtitle(axs(1, j), sprintf('pot %.1f, house/rent %.1f, q %.2f (x income)', A, H, q), 'FontSize', 8, 'Color', ink2);
    for a = 1:2
        xlabel(axs(a, j), 'liquid wealth X / income', 'Color', ink2);
        set(axs(a, j), 'XGrid', 'on', 'YGrid', 'on', 'GridColor', [0.85 0.85 0.84], 'GridAlpha', 1, 'Box', 'off', ...
            'XColor', ink2, 'YColor', ink2, 'FontSize', 9, 'Layer', 'top');
    end
    if j == 1
        ylabel(axs(1, j), 'C / income', 'Color', ink2);
        ylabel(axs(2, j), 'share of savings in stocks', 'Color', ink2);
        legend(axs(1, j), 'Location', 'northwest', 'Interpreter', 'none', 'FontSize', 8, 'Box', 'off');
    end
end
if ~isempty(opts.title), title(tl, opts.title, 'FontSize', 13, 'Interpreter', 'none'); end
out = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'neural', 'data', 'figures');
if ~isfolder(out), mkdir(out); end
exportgraphics(fig, fullfile(out, opts.file), 'Resolution', 130);
end

function y = take_home(p, t, ann_price, A, H, q)
%TAKE_HOME  Liquid resources besides X, per unit of income, as simulate.paths_lna.
net_inc = 1 - p.tau_inc;
if p.is_owner
    if t <= numel(p.m_rate_path), m = p.m_rate_path(t); else, m = 0; end
    if strcmp(p.mortgage, 'annuity'), m = m * q; end
    th = p.theta;
    if p.maint_on_purchase, th = th * q; end
    hcr = th + m;
else
    hcr = p.alpha;
end
if t >= p.t_ret
    y = net_inc + A / ann_price(t) * net_inc - hcr * H;
else
    y = (1 - p.kappa(t)) * net_inc - hcr * H;
end
end
