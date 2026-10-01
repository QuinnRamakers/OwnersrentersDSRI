% The test the coordinate work has been missing: solve the model in each chart
% and see whether they agree.
%
% Three charts are three relabellings of one model, so at infinite resolution
% they must give the same answer. At finite resolution they differ by their own
% discretisation error, and that difference must SHRINK as the grid refines. If
% it does not, either the chart is wrong or the model is not identified there --
% and we already know which regions to expect each in.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
o = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
dims = {[10 10 8],[14 14 10],[18 18 12]};
charts = {'yw','yann','hk'};
R = cell(3,3);
for ic = 1:3
  for ig = 1:3
    p = config.params(); p.is_owner = false; p.coord1 = charts{ic};
    p.grid_mode='none'; p.polish_ver=2; p.use_refine=false;
    p = utility.build_state_grids(p, dims{ig}, 3);
    [~,mg,sl]=config.income_profile(p);
    pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(p);
    sk=grids.shock_grid(p); an=pension.annuity_price(p,pf,sk);
    tic; s=solver.solve_lifecycle_lna(p,pf,sk,an); el=toc;
    sm=simulate.forward(p,pf,s,an,4000,20260511,p.b0);
    r.chart=charts{ic}; r.n=numel(p.u1_grid)*numel(p.u2_grid)*numel(p.u3_grid);
    r.C=median(sm.C,1,'omitnan'); r.pi=mean(sm.pi,1,'omitnan'); r.ages=sm.ages; r.sec=el;
    d2=@(v) mean(abs(diff(v,2)))/mean(abs(v));
    r.rough_ret=100*d2(r.pi(41:60)); r.off=sm.diagnostics.n_offgrid_u1;
    R{ic,ig}=r;
    fprintf('%-5s n=%5d %4.0fs C25=%6.0f C45=%6.0f C70=%6.0f pi25=%.2f pi45=%.2f |d2pi|ret %.2f%% off-grid %d\n', ...
        charts{ic}, r.n, el, r.C(1), r.C(21), r.C(46), r.pi(1), r.pi(21), r.rough_ret, r.off);
  end
end
save([o 'chart_ladder.mat'],'R');

gap=@(a,b,i) 100*mean(abs(b(i)-a(i))./max(abs(a(i)),eps));
yo=1:15; mid=16:45; old=46:75;
fprintf('\nBETWEEN charts at each grid size -- must shrink if the charts agree\n');
fprintf('%-16s %8s %9s %9s %9s %12s\n','pair','nodes','25-39','40-69','70+','|dpi| 40-69');
for ig=1:3
  for pr = {[1 2],[1 3]}
    i=pr{1}; a=R{i(1),ig}; b=R{i(2),ig};
    fprintf('%-16s %8d %8.1f%% %8.1f%% %8.1f%% %12.3f\n', ...
        [a.chart ' vs ' b.chart], a.n, gap(a.C,b.C,yo), gap(a.C,b.C,mid), gap(a.C,b.C,old), ...
        mean(abs(b.pi(mid)-a.pi(mid))));
  end
end
fprintf('\nWITHIN each chart, successive refinements\n');
fprintf('%-6s %16s %9s %9s %9s\n','chart','refinement','25-39','40-69','70+');
for ic=1:3
  for ig=1:2
    a=R{ic,ig}; b=R{ic,ig+1};
    fprintf('%-6s %6d->%-9d %8.1f%% %8.1f%% %8.1f%%\n', charts{ic}, a.n, b.n, ...
        gap(a.C,b.C,yo), gap(a.C,b.C,mid), gap(a.C,b.C,old));
  end
end
fprintf('\nRetirement roughness of pi (ages 65-84)\n%-6s %9s %9s %9s\n','chart','small','mid','large');
for ic=1:3
    fprintf('%-6s %8.2f%% %8.2f%% %8.2f%%\n', charts{ic}, R{ic,1}.rough_ret, R{ic,2}.rough_ret, R{ic,3}.rough_ret);
end

f=figure('Position',[100 100 1180 760],'Color','w');
tl=tiledlayout(f,2,3,'Padding','compact','TileSpacing','compact');
cmap=[.85 .33 .10; .47 .67 .19; .20 .35 .75];
for ic=1:3
    ax=nexttile(tl,ic); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    for ig=1:3, plot(ax,R{ic,ig}.ages(1:75),R{ic,ig}.C(1:75),'Color',cmap(ig,:),'LineWidth',1.5); end
    xline(ax,67,':','Color',[.5 .5 .5]); xlim(ax,[25 99]); ylim(ax,[0 4.5e4]);
    title(ax,charts{ic},'FontWeight','normal'); if ic==1, ylabel(ax,'median consumption'); legend(ax,arrayfun(@(k) sprintf('%d',R{ic,k}.n),1:3,'uni',0),'Location','southeast','Box','off'); end
end
for ic=1:3
    ax=nexttile(tl,3+ic); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    for ig=1:3, plot(ax,R{ic,ig}.ages(1:75),R{ic,ig}.pi(1:75),'Color',cmap(ig,:),'LineWidth',1.5); end
    xline(ax,67,':','Color',[.5 .5 .5]); xlim(ax,[25 99]); ylim(ax,[0 1.05]);
    xlabel(ax,'age'); if ic==1, ylabel(ax,'mean equity share'); end
end
sgtitle(f,'Three charts of one model, three grid sizes each. Columns should agree in the limit.','FontWeight','normal','FontSize',12);
exportgraphics(f,[o 'fig_chart_ladder.png'],'Resolution',150);
disp('done');
