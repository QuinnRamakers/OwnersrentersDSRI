% Solve on the designed node placement and show what moves.
%
% Current coordinates throughout. Closer to production than anything else in
% this session: gh_n = 5 rather than 3, the finest grid used so far. The
% derivative-free refinement is still off -- it was measured to move consumption
% at 25 by 0.8% and pi by 0.02, and turning it on would take this from twenty
% minutes to an hour.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
o = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
arms = {'default','designed'};
S = cell(1,2);
for ia = 1:2
    p = config.params(); p.is_owner = false;
    p.grid_mode='none'; p.polish_ver=2; p.use_refine=false;
    if ia == 2
        p.lambda_hi=0.42; p.grid_pow=1.6;
        p.u2_lo=0.45;     p.grid_pow_u2=1;
        p.u3_lo=0.03;     p.u3_hi=0.96;
    end
    p = utility.build_state_grids(p, [18 18 12], 5);
    [~,mg,sl]=config.income_profile(p);
    pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(p);
    sk=grids.shock_grid(p); an=pension.annuity_price(p,pf,sk);
    tic; sol=solver.solve_lifecycle_lna(p,pf,sk,an); el=toc;
    sm=simulate.forward(p,pf,sol,an,6000,20260511,p.b0);
    r.arm=arms{ia}; r.p=p; r.sim=sm; r.sec=el;
    r.n=numel(p.u1_grid)*numel(p.u2_grid)*numel(p.u3_grid);
    r.off=sm.diagnostics.n_offgrid_u1+sm.diagnostics.n_offgrid_u2;
    fprintf('%-9s %d nodes (%dx%dx%d) gh_n=%d  %.0fs  off-grid %d\n', arms{ia}, r.n, ...
        numel(p.u1_grid), numel(p.u2_grid), numel(p.u3_grid), p.gh_n, el, r.off);
    S{ia}=r;
end
save([o 'final_grid_run.mat'],'S','-v7.3');

A=S{1}.sim; B=S{2}.sim; ages=A.ages; T=S{1}.p.T; K=1:75;
med=@(M) median(M,1,'omitnan'); mn=@(M) mean(M,1,'omitnan');
FA = S{1}.p.phi_floor*A.Y(:,1:size(A.C,2)); FB = S{2}.p.phi_floor*B.Y(:,1:size(B.C,2));
flA = 100*mean(A.LW(:,1:size(FA,2))<=FA,1); flB = 100*mean(B.LW(:,1:size(FB,2))<=FB,1);

fprintf('\n%-26s %12s %12s %10s\n','', 'default','designed','change');
row=@(lab,a,b) fprintf('%-26s %12.0f %12.0f %9.1f%%\n', lab, a, b, 100*(b/a-1));
row('consumption at 25',  med(A.C(:,1)),  med(B.C(:,1)));
row('consumption at 40',  med(A.C(:,16)), med(B.C(:,16)));
row('consumption at 55',  med(A.C(:,31)), med(B.C(:,31)));
row('consumption at 70',  med(A.C(:,46)), med(B.C(:,46)));
row('consumption at 85',  med(A.C(:,61)), med(B.C(:,61)));
row('financial wealth 66',med(A.X(:,42)+A.A(:,42)), med(B.X(:,42)+B.A(:,42)));
fprintf('%-26s %12.2f %12.2f\n','equity share at 25', mn(A.pi(:,1)),  mn(B.pi(:,1)));
fprintf('%-26s %12.2f %12.2f\n','equity share at 45', mn(A.pi(:,21)), mn(B.pi(:,21)));
fprintf('%-26s %12.2f %12.2f\n','equity share at 75', mn(A.pi(:,51)), mn(B.pi(:,51)));
d2=@(v) 100*mean(abs(diff(v,2)))/mean(abs(v));
fprintf('%-26s %11.2f%% %11.2f%%\n','|d2 pi| midlife 40-64', d2(mn(A.pi(:,16:40))), d2(mn(B.pi(:,16:40))));
fprintf('%-26s %11.2f%% %11.2f%%\n','|d2 pi| retirement 65-84', d2(mn(A.pi(:,41:60))), d2(mn(B.pi(:,41:60))));
fprintf('%-26s %11.2f%% %11.2f%%\n','floored, all ages', mean(flA), mean(flB));

f=figure('Position',[80 60 1280 780],'Color','w');
tl=tiledlayout(f,2,3,'Padding','compact','TileSpacing','compact');
cA=[.85 .33 .10]; cB=[.20 .35 .75];
pan=@(ax,ttl,yl) deal(title(ax,ttl,'FontWeight','normal'), ylabel(ax,yl), xlabel(ax,'age'));

ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
plot(ax,ages(K),med(A.C(:,K)),'Color',cA,'LineWidth',1.8);
plot(ax,ages(K),med(B.C(:,K)),'Color',cB,'LineWidth',1.8);
xline(ax,67,':','Color',[.5 .5 .5]); xlim(ax,[25 99]);
title(ax,'median consumption','FontWeight','normal'); ylabel(ax,'EUR/yr'); xlabel(ax,'age');
legend(ax,{'default grid','designed grid'},'Location','southeast','Box','off');

ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
plot(ax,ages(K),mn(A.pi(:,K)),'Color',cA,'LineWidth',1.8);
plot(ax,ages(K),mn(B.pi(:,K)),'Color',cB,'LineWidth',1.8);
xline(ax,67,':','Color',[.5 .5 .5]); xlim(ax,[25 99]); ylim(ax,[0 1.05]);
title(ax,'mean equity share of liquid wealth','FontWeight','normal'); xlabel(ax,'age');

ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
plot(ax,ages(K),med(A.X(:,K)+A.A(:,K)),'Color',cA,'LineWidth',1.8);
plot(ax,ages(K),med(B.X(:,K)+B.A(:,K)),'Color',cB,'LineWidth',1.8);
xline(ax,67,':','Color',[.5 .5 .5]); xlim(ax,[25 99]);
title(ax,'median financial wealth, liquid + DC','FontWeight','normal'); ylabel(ax,'EUR'); xlabel(ax,'age');

ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
plot(ax,ages(1:numel(flA)),flA,'Color',cA,'LineWidth',1.8);
plot(ax,ages(1:numel(flB)),flB,'Color',cB,'LineWidth',1.8);
xline(ax,67,':','Color',[.5 .5 .5]); xlim(ax,[25 99]);
title(ax,'% of households at the consumption floor','FontWeight','normal'); xlabel(ax,'age');

ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
u1A=A.Y./A.W; tt=3:T-1;
lo=prctile(u1A(:,tt),1,1); hi=prctile(u1A(:,tt),99,1);
fill(ax,[ages(tt) fliplr(ages(tt))],[lo fliplr(hi)],[.4 .4 .4],'FaceAlpha',.18,'EdgeColor','none');
for i=1:numel(S{1}.p.u1_grid), yline(ax,S{1}.p.u1_grid(i),'-','Color',[cA .55],'LineWidth',.8); end
for i=1:numel(S{2}.p.u1_grid), yline(ax,S{2}.p.u1_grid(i),'-','Color',[cB .55],'LineWidth',.8); end
xlim(ax,[27 99]); ylim(ax,[0 0.62]);
title(ax,'u1 nodes vs the population (grey)','FontWeight','normal'); ylabel(ax,'u1 = Y/W'); xlabel(ax,'age');

ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
u2A=(A.A+A.H)./max(A.X+A.A+A.H,eps);
lo=prctile(u2A(:,tt),1,1); hi=prctile(u2A(:,tt),99,1);
fill(ax,[ages(tt) fliplr(ages(tt))],[lo fliplr(hi)],[.4 .4 .4],'FaceAlpha',.18,'EdgeColor','none');
for i=1:numel(S{1}.p.u2_grid), yline(ax,S{1}.p.u2_grid(i),'-','Color',[cA .55],'LineWidth',.8); end
for i=1:numel(S{2}.p.u2_grid), yline(ax,S{2}.p.u2_grid(i),'-','Color',[cB .55],'LineWidth',.8); end
xlim(ax,[27 99]); ylim(ax,[0 1.02]);
title(ax,'u2 nodes vs the population (grey)','FontWeight','normal'); ylabel(ax,'u2'); xlabel(ax,'age');

sgtitle(f,sprintf('Renter, %d nodes, gh\\_n=5, 6000 paths. Same model, same coordinates, nodes moved.', S{1}.n), ...
        'FontWeight','normal','FontSize',12);
exportgraphics(f,[o 'fig_final_grid.png'],'Resolution',150);
disp('done');
