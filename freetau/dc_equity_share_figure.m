function f = dc_equity_share_figure(S, p, X0_FRAC)
%DC_EQUITY_SHARE_FIGURE  Presentation figure: equity share by account over the
%accumulation phase, under free DC choice.
%
%   f = DC_EQUITY_SHARE_FIGURE(S, p, X0_FRAC) draws the mean applied equity
%   share by age for the DC account (tau_A) and the private liquid account
%   (pi), one panel per tenure. Only working-age transitions are shown: after
%   retirement the DC fund is annuitised and every tau_A is zero, so the
%   retired stretch is flat at zero and carries no information.
%
%   Both arms come from the free-choice solution, so the plan's glide path is
%   not on the figure -- it belongs to the imposed-glide arm, and drawing it
%   here would put two different regimes on one set of axes.
%
%   One panel per tenure rather than four lines on shared axes: the DC and
%   private profiles cross repeatedly between tenures, and the DC-vs-private
%   gap is the comparison worth reading, so it gets its own axes.
%
%   S must have fields .renter and .owner, each with
%     ages_tr    1 x (T-1) age of each transition
%     tau_free   1 x (T-1) mean applied DC equity share
%     pi_free    1 x (T-1) mean applied private-account equity share
%   p is the parameter struct (retirement_age, gamma) and X0_FRAC the initial
%   liquid buffer used in the simulation, both only for labelling.

dc_col = [0.00 0.45 0.70];   % DC account       (Okabe-Ito, colour-blind safe)
pv_col = [0.84 0.37 0.00];   % private account
faint  = [0.55 0.55 0.55];

tenures = {'renter', 'owner'};

f  = figure('Color','w', 'Position',[100 100 1120 540]);
tl = tiledlayout(f, 1, 2, 'TileSpacing','compact', 'Padding','compact');

for i = 1:numel(tenures)
    ten  = tenures{i};
    keep = S.(ten).ages_tr < p.retirement_age;     % accumulation phase only
    age  = S.(ten).ages_tr(keep);

    ax = nexttile(tl); hold(ax,'on');
    hdc = plot(ax, age, 100*S.(ten).tau_free(keep), '-', 'LineWidth',2.6, 'Color',dc_col);
    hpv = plot(ax, age, 100*S.(ten).pi_free(keep),  '-', 'LineWidth',2.6, 'Color',pv_col);

    xline(ax, p.retirement_age, ':', 'Color',faint, 'LineWidth',1.2, ...
          'Label','retirement', 'LabelOrientation','horizontal', ...
          'LabelHorizontalAlignment','left', 'LabelVerticalAlignment','top', ...
          'FontSize',10, 'Color',faint);

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

    xlim(ax, [age(1) p.retirement_age + 1]);
    ylim(ax, [0 100]);
    yticks(ax, 0:20:100);
    title(ax, ten, 'FontSize',15, 'FontWeight','bold');

    if i == 1
        ytickformat(ax, '%g%%');
        ylabel(ax, 'equity share', 'FontSize',14);
        lg = legend([hdc hpv], {'DC account (\tau_A)', 'private account (\pi)'}, ...
                    'Location','southwest', 'FontSize',13, 'Box','off');
        lg.ItemTokenSize = [30 18];
    else
        ax.YTickLabel = [];                        % shared scale with the left panel
    end
end

xlabel(tl, 'age', 'FontSize',14);
title(tl, 'Equity share in the DC and private accounts, free DC choice', ...
      'FontSize',16, 'FontWeight','bold');
subtitle(tl, sprintf(['mean applied share across simulated households, accumulation phase; ' ...
                      '\\gamma = %g, X_0 = %.1f yr of income'], p.gamma, X0_FRAC), ...
         'FontSize',12, 'Color',faint);
end
