% Point 3, drawn: what "does not converge" looks like. No solve, replots
% converge_test.mat.
o = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
L = load([o 'converge_test.mat']); R = L.R;
n = cellfun(@(r) r.n, R(:,1));
f = figure('Position',[100 100 1180 420],'Color','w');
tl = tiledlayout(f,1,2,'Padding','compact','TileSpacing','compact');

ax = nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
sh = {'-o','-s','-^'}; cmap = [.85 .33 .10; .47 .67 .19; .20 .35 .75];
for ig = 1:3
    plot(ax, R{ig,1}.ages(1:75), R{ig,1}.C(1:75), sh{ig}, 'Color', cmap(ig,:), ...
         'LineWidth',1.4,'MarkerIndices',1:8:75,'MarkerSize',4);
end
xline(ax,40,':','Color',[.4 .4 .4]); xline(ax,67,':','Color',[.6 .6 .6]);
xlim(ax,[25 99]); xlabel(ax,'age'); ylabel(ax,'median consumption, EUR/yr');
title(ax,'linear-z (production default), three grid sizes','FontWeight','normal');
legend(ax, arrayfun(@(k) sprintf('%d nodes',n(k)), 1:3, 'uni',0), 'Location','southeast','Box','off');
text(ax, 27, 3.4e4, {'ages 25-39 keep moving','ages 40+ have settled'}, 'FontSize',10,'Color',[.3 .3 .3]);

ax = nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
c25 = cellfun(@(r) r.C(1), R);
plot(ax, n, c25(:,1), '-o','Color',[.92 .41 .20],'LineWidth',1.8,'MarkerFaceColor',[.92 .41 .20]);
plot(ax, n, c25(:,2), '-o','Color',[.16 .47 .84],'LineWidth',1.8,'MarkerFaceColor',[.16 .47 .84]);
xlabel(ax,'grid nodes'); ylabel(ax,'median consumption at 25, EUR/yr');
title(ax,'consumption at 25 as the grid refines','FontWeight','normal');
legend(ax,{'linear-z','kappa'},'Location','east','Box','off'); ylim(ax,[0 1.8e4]);
for k=1:3
    text(ax, n(k), c25(k,1)-1100, sprintf('%.0f',c25(k,1)),'HorizontalAlignment','center','FontSize',9,'Color',[.6 .27 .13]);
    text(ax, n(k), c25(k,2)+1100, sprintf('%.0f',c25(k,2)),'HorizontalAlignment','center','FontSize',9,'Color',[.10 .31 .55]);
end
sgtitle(f,'Refining the grid should stop changing the answer. In the twenties it does not.','FontWeight','normal','FontSize',12);
exportgraphics(f,[o 'fig_divergence.png'],'Resolution',150);
disp('ok');
