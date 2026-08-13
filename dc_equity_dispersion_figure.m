function f = dc_equity_dispersion_figure(S, p, X0_FRAC)
%DC_EQUITY_DISPERSION_FIGURE  Presentation figure: the spread of individually
%optimal DC equity shares against the plan's single default.
%
%   f = DC_EQUITY_DISPERSION_FIGURE(S, p, X0_FRAC) shades the 10th-90th
%   percentile of the chosen DC equity share across simulated households, draws
%   the median through it, and overlays the plan's glide path. One panel per
%   tenure, accumulation phase only.
%
%   The glide path belongs here in a way it does not on the mean-share figure:
%   it is a RULE the plan writes down (p.tau_S), not the outcome of the
%   imposed-glide solution, so nothing from a second regime is on these axes.
%   The comparison is "what the plan prescribes" against "what households would
%   pick", which is the question the free-tau extension exists to ask.
%
%   S must have fields .renter and .owner, each with
%     ages_tr    1 x (T-1) age of each transition
%     tau_p10 / tau_p50 / tau_p90   percentiles of the chosen DC share
%     tau_glide  1 x (T-1) the plan's glide path
%   p is the parameter struct and X0_FRAC the initial liquid buffer, both only
%   for labelling.

band_col = [0.62 0.76 0.87];   % 10-90 spread of household choices
med_col  = [0.00 0.34 0.55];   % median choice
glide_col= [0.10 0.10 0.10];   % the plan's default
faint    = [0.55 0.55 0.55];

tenures = {'renter', 'owner'};

f  = figure('Color','w', 'Position',[100 100 1120 540]);
tl = tiledlayout(f, 1, 2, 'TileSpacing','compact', 'Padding','compact');

for i = 1:numel(tenures)
    ten  = tenures{i};
    keep = S.(ten).ages_tr < p.retirement_age;    % accumulation phase only
    age  = S.(ten).ages_tr(keep);
    lo   = 100*S.(ten).tau_p10(keep);
    hi   = 100*S.(ten).tau_p90(keep);

    ax = nexttile(tl); hold(ax,'on');
    hb = fill(ax, [age fliplr(age)], [lo fliplr(hi)], band_col, ...
              'EdgeColor','none', 'FaceAlpha',0.55);
    hm = plot(ax, age, 100*S.(ten).tau_p50(keep),   '-',  'LineWidth',2.6, 'Color',med_col);
    hg = plot(ax, age, 100*S.(ten).tau_glide(keep), '--', 'LineWidth',2.6, 'Color',glide_col);

    ax.FontSize  = 13;
    ax.LineWidth = 1.0;
    ax.TickDir   = 'out';
    ax.XColor    = [0.2 0.2 0.2];
    ax.YColor    = [0.2 0.2 0.2];
    ax.YGrid     = 'on';
    ax.GridColor = [0.8 0.8 0.8];
    ax.GridAlpha = 0.9;
    ax.Layer     = 'bottom';
    box(ax,'off');

    xlim(ax, [age(1) p.retirement_age]);
    ylim(ax, [0 100]);
    yticks(ax, 0:20:100);
    title(ax, ten, 'FontSize',15, 'FontWeight','bold');

    if i == 1
        ytickformat(ax, '%g%%');
        ylabel(ax, 'DC equity share', 'FontSize',14);
        lg = legend([hb hm hg], {'what households choose (10th-90th pct)', ...
                                 'median household', ...
                                 'what the plan gives them (default)'}, ...
                    'Location','southwest', 'FontSize',12, 'Box','off');
        lg.ItemTokenSize = [30 18];
    else
        ax.YTickLabel = [];                       % shared scale with the left panel
    end
end

xlabel(tl, 'age', 'FontSize',14);
title(tl, 'One default glide path, many optimal portfolios', ...
      'FontSize',16, 'FontWeight','bold');
subtitle(tl, sprintf(['DC equity share households would choose if free to, vs the plan default; ' ...
                      'accumulation phase, \\gamma = %g, X_0 = %.1f yr of income'], ...
                     p.gamma, X0_FRAC), ...
         'FontSize',12, 'Color',faint);
end
