% Solve on the designed grid. Current coordinates throughout.
%
% Design (all four are existing or newly exposed p fields, no stored table):
%   lambda_hi = 0.42   u1 never exceeded 0.385 in 438,000 household-years
%   grid_pow  = 1.6    u1 falls through life, bunch its nodes low
%   u2_lo     = 0.55   u2 never fell below 0.587; 0.60 clipped, 0.55 does not
%   u3_lo/hi  = 0.03 / 0.96   u3 never left [0.035, 0.951]
%
% Occupancy is endogenous: it was measured on the default grid, so the new grid
% may move it. The last block re-measures on the new grid and reports whether the
% design still holds -- one iteration of a fixed point, not an assumption.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
o = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
dims = {[10 10 8],[14 14 10],[18 18 12]};
arms = {'default','designed'};
R = cell(2,3);
for ia = 1:2
  for ig = 1:3
    p = config.params(); p.is_owner = false;
    p.grid_mode='none'; p.polish_ver=2; p.use_refine=false;
    if ia == 2
        p.lambda_hi = 0.42; p.grid_pow = 1.6;
        p.u2_lo = 0.55; p.grid_pow_u2 = 1;
        p.u3_lo = 0.03; p.u3_hi = 0.96;
    end
    p = utility.build_state_grids(p, dims{ig}, 3);
    [~,mg,sl]=config.income_profile(p);
    pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(p);
    sk=grids.shock_grid(p); an=pension.annuity_price(p,pf,sk);
    tic; s=solver.solve_lifecycle_lna(p,pf,sk,an); el=toc;
    sm=simulate.forward(p,pf,s,an,4000,20260511,p.b0);
    r.arm=arms{ia}; r.n=numel(p.u1_grid)*numel(p.u2_grid)*numel(p.u3_grid); r.sec=el;
    r.C=median(sm.C,1,'omitnan'); r.pi=mean(sm.pi,1,'omitnan'); r.ages=sm.ages;
    d2=@(v) 100*mean(abs(diff(v,2)))/mean(abs(v));
    r.rough_ret=d2(r.pi(41:60)); r.rough_mid=d2(r.pi(16:40));
    r.off=sm.diagnostics.n_offgrid_u1 + sm.diagnostics.n_offgrid_u2;
    r.p=p; r.sim=sm; R{ia,ig}=r;
    fprintf('%-9s n=%5d %4.0fs C25=%6.0f C45=%6.0f C70=%6.0f pi25=%.2f |d2pi| mid %.2f%% ret %.2f%% off %d\n', ...
        arms{ia}, r.n, el, r.C(1), r.C(21), r.C(46), r.pi(1), r.rough_mid, r.rough_ret, r.off);
  end
end
save([o 'grid_ladder2.mat'],'R','-v7.3');

gap=@(a,b,i) 100*mean(abs(b(i)-a(i))./max(abs(a(i)),eps));
yo=1:15; mid=16:45; old=46:75;
fprintf('\nDrift between successive refinements (mean |dC|/C)\n');
fprintf('%-10s %16s %9s %9s %9s %11s\n','grid','refinement','25-39','40-69','70+','|dpi| 40-69');
for ia=1:2
  for ig=1:2
    a=R{ia,ig}; b=R{ia,ig+1};
    fprintf('%-10s %6d->%-9d %8.1f%% %8.1f%% %8.1f%% %11.3f\n', arms{ia}, a.n, b.n, ...
      gap(a.C,b.C,yo), gap(a.C,b.C,mid), gap(a.C,b.C,old), mean(abs(b.pi(mid)-a.pi(mid))));
  end
end
fprintf('\nRoughness of pi\n%-10s %22s %22s\n','grid','midlife 40-64','retirement 65-84');
for ia=1:2
  fprintf('%-10s', arms{ia});
  for f = {'rough_mid','rough_ret'}
    fprintf('   %6.2f %6.2f %6.2f    ', R{ia,1}.(f{1}), R{ia,2}.(f{1}), R{ia,3}.(f{1}));
  end
  fprintf('\n');
end

% --- endogeneity: re-measure occupancy on the designed grid ---------------
fprintf('\nOccupancy re-measured on the DESIGNED grid (was measured on the default)\n');
sm = R{2,3}.sim; p2 = R{2,3}.p;
X=sm.X;A=sm.A;H=sm.H;Y=sm.Y;W=sm.W; tt=3:p2.T-1;
U={Y./W,(A+H)./max(X+A+H,eps),A./max(A+H,eps)};
gs={p2.u1_grid,p2.u2_grid,p2.u3_grid}; nm={'u1','u2','u3'};
fprintf('%-6s %10s %10s %12s %12s %10s\n','axis','min','max','axis lo','axis hi','outside');
for j=1:3
    v=U{j}(:,tt); v=v(isfinite(v));
    off=sum(v<gs{j}(1)-1e-12 | v>gs{j}(end)+1e-12);
    fprintf('%-6s %10.4f %10.4f %12.4f %12.4f %10d\n', nm{j}, min(v), max(v), gs{j}(1), gs{j}(end), off);
end
fprintf('\nnodes in the 1-99%% band on the designed grid (mean / worst / starved)\n');
for j=1:3
    lo=prctile(U{j}(:,tt),1,1); hi=prctile(U{j}(:,tt),99,1);
    c=arrayfun(@(t) sum(gs{j}>=lo(t)&gs{j}<=hi(t)),1:numel(tt));
    fprintf('  %-4s %5.1f / %d / %d\n', nm{j}, mean(c), min(c), sum(c<2));
end

f=figure('Position',[100 100 1180 420],'Color','w');
tl=tiledlayout(f,1,3,'Padding','compact','TileSpacing','compact');
cmap=[.85 .33 .10; .47 .67 .19; .20 .35 .75];
for ia=1:2
    ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    for ig=1:3, plot(ax,R{ia,ig}.ages(1:75),R{ia,ig}.pi(1:75),'Color',cmap(ig,:),'LineWidth',1.5); end
    xline(ax,67,':','Color',[.5 .5 .5]); xlim(ax,[25 99]); ylim(ax,[0 1.05]);
    xlabel(ax,'age'); title(ax,[arms{ia} ' -- equity share'],'FontWeight','normal');
    if ia==1, ylabel(ax,'mean equity share'); legend(ax,arrayfun(@(k) sprintf('%d',R{ia,k}.n),1:3,'uni',0),'Location','south','Box','off'); end
end
ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
for ia=1:2, plot(ax,R{ia,3}.ages(1:75),R{ia,3}.C(1:75),'Color',cmap(ia*2-1,:),'LineWidth',1.6); end
xline(ax,67,':','Color',[.5 .5 .5]); xlim(ax,[25 99]); xlabel(ax,'age');
title(ax,'consumption, finest grid','FontWeight','normal');
legend(ax,arms,'Location','southeast','Box','off');
sgtitle(f,'Current coordinates, axes trimmed to the measured range','FontWeight','normal','FontSize',12);
exportgraphics(f,[o 'fig_grid_ladder2.png'],'Resolution',150);
disp('done');
