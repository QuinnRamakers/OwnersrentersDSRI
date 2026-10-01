% The same exercise for the owner.
%
% The renter's trims are NOT reused. Occupancy is endogenous -- that is what
% caught out the u2 floor last time -- and the owner's budget is different: the
% carrying cost is theta + m_rate_t rather than alpha, it scales with H, and the
% mortgage payment stops after N_mort years rather than at retirement. So:
% solve on the default grid, measure where owners actually go, design from that,
% solve again, compare.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
o = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';

    function [r, p] = solve_sim(p, tag)
        p = utility.build_state_grids(p, [18 18 12], 5);
        [~,mg,sl]=config.income_profile(p);
        pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(p);
        sk=grids.shock_grid(p); an=pension.annuity_price(p,pf,sk);
        tic; sol=solver.solve_lifecycle_lna(p,pf,sk,an); el=toc;
        sm=simulate.forward(p,pf,sol,an,6000,20260511,p.b0);
        r.tag=tag; r.p=p; r.sim=sm; r.sec=el;
        r.n=numel(p.u1_grid)*numel(p.u2_grid)*numel(p.u3_grid);
        r.off=sm.diagnostics.n_offgrid_u1+sm.diagnostics.n_offgrid_u2;
        fprintf('%-9s %d nodes gh_n=%d %.0fs off-grid %d\n', tag, r.n, p.gh_n, el, r.off);
    end
base = @() setfield(setfield(setfield(setfield(config.params(),'is_owner',true), ...
        'grid_mode','none'),'polish_ver',2),'use_refine',false);

% --- 1. default grid, and measure where owners go -------------------------
[D, pD] = solve_sim(base(), 'default');
s=D.sim; T=pD.T; tt=3:T-1;
U={s.Y./s.W, (s.A+s.H)./max(s.X+s.A+s.H,eps), s.A./max(s.A+s.H,eps)};
nm={'u1','u2','u3'};
fprintf('\nOwner occupancy, %d household-years (renter figures in brackets)\n', numel(U{1}(:,tt)));
ren=[0.0022 0.3852; 0.5869 1.0000; 0.0350 0.9509];
EX=zeros(3,2);
fprintf('%-5s %10s %10s      %-22s\n','axis','min','max','renter');
for j=1:3
    v=U{j}(:,tt); v=v(isfinite(v)); EX(j,:)=[min(v) max(v)];
    fprintf('%-5s %10.4f %10.4f      [%.4f, %.4f]\n', nm{j}, EX(j,1), EX(j,2), ren(j,1), ren(j,2));
end

% --- 2. design from the owner's own occupancy, with margin ----------------
MG = 0.12;
tgt = zeros(3,2);
for j=1:3
    sp = EX(j,2)-EX(j,1);
    tgt(j,:) = [max(EX(j,1)-MG*sp, 0), min(EX(j,2)+MG*sp, 1)];
end
tgt(1,1)=max(tgt(1,1),0.002);
tgt(2,2)=1; tgt(3,2)=min(tgt(3,2),1);
fprintf('\nowner design: u1 [%.4f %.4f]  u2 [%.4f %.4f]  u3 [%.4f %.4f]\n', tgt');

q = base();
q.lambda_lo=tgt(1,1); q.lambda_hi=tgt(1,2); q.grid_pow=1.6;
q.u2_lo=tgt(2,1);     q.grid_pow_u2=1;
q.u3_lo=tgt(3,1);     q.u3_hi=tgt(3,2);
[B, pB] = solve_sim(q, 'designed');

% --- 3. compare -----------------------------------------------------------
A=D.sim; C=B.sim; ages=A.ages; K=1:75;
med=@(M) median(M,1,'omitnan'); mn=@(M) mean(M,1,'omitnan');
FA=pD.phi_floor*A.Y(:,1:size(A.C,2)); FB=pB.phi_floor*C.Y(:,1:size(C.C,2));
flA=100*mean(A.LW(:,1:size(FA,2))<=FA,1); flB=100*mean(C.LW(:,1:size(FB,2))<=FB,1);
d2=@(v) 100*mean(abs(diff(v,2)))/mean(abs(v));
fprintf('\n%-26s %12s %12s %10s\n','OWNER','default','designed','change');
row=@(l,a,b) fprintf('%-26s %12.0f %12.0f %9.1f%%\n', l, a, b, 100*(b/a-1));
row('consumption at 25', med(A.C(:,1)),  med(C.C(:,1)));
row('consumption at 40', med(A.C(:,16)), med(C.C(:,16)));
row('consumption at 55', med(A.C(:,31)), med(C.C(:,31)));
row('consumption at 70', med(A.C(:,46)), med(C.C(:,46)));
row('consumption at 85', med(A.C(:,61)), med(C.C(:,61)));
row('financial wealth 66', med(A.X(:,42)+A.A(:,42)), med(C.X(:,42)+C.A(:,42)));
fprintf('%-26s %12.2f %12.2f\n','equity share at 25', mn(A.pi(:,1)),  mn(C.pi(:,1)));
fprintf('%-26s %12.2f %12.2f\n','equity share at 45', mn(A.pi(:,21)), mn(C.pi(:,21)));
fprintf('%-26s %12.2f %12.2f\n','equity share at 75', mn(A.pi(:,51)), mn(C.pi(:,51)));
fprintf('%-26s %11.2f%% %11.2f%%\n','|d2 pi| midlife 40-64', d2(mn(A.pi(:,16:40))), d2(mn(C.pi(:,16:40))));
fprintf('%-26s %11.2f%% %11.2f%%\n','|d2 pi| retirement 65-84', d2(mn(A.pi(:,41:60))), d2(mn(C.pi(:,41:60))));
fprintf('%-26s %11.2f%% %11.2f%%\n','floored, all ages', mean(flA), mean(flB));
% did the design still hold once policies moved?
U2=(C.A+C.H)./max(C.X+C.A+C.H,eps); U1=C.Y./C.W; U3=C.A./max(C.A+C.H,eps);
fprintf('\nre-measured on the designed grid: u1 [%.4f %.4f] u2 [%.4f %.4f] u3 [%.4f %.4f], off-grid %d\n', ...
    min(min(U1(:,tt))),max(max(U1(:,tt))), min(min(U2(:,tt))),max(max(U2(:,tt))), ...
    min(min(U3(:,tt))),max(max(U3(:,tt))), B.off);
save([o 'owner_grid_run.mat'],'D','B','-v7.3');

f=figure('Position',[80 60 1280 780],'Color','w');
tl=tiledlayout(f,2,3,'Padding','compact','TileSpacing','compact');
cA=[.85 .33 .10]; cB=[.20 .35 .75];
P={med(A.C(:,K)),med(C.C(:,K)); mn(A.pi(:,K)),mn(C.pi(:,K)); ...
   med(A.X(:,K)+A.A(:,K)),med(C.X(:,K)+C.A(:,K)); flA,flB};
ttl={'median consumption','mean equity share of liquid wealth', ...
     'median financial wealth, liquid + DC','% of households at the floor'};
yl={'EUR/yr','','EUR','%'};
for k=1:4
    ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    plot(ax,ages(1:numel(P{k,1})),P{k,1},'Color',cA,'LineWidth',1.8);
    plot(ax,ages(1:numel(P{k,2})),P{k,2},'Color',cB,'LineWidth',1.8);
    xline(ax,67,':','Color',[.5 .5 .5]); xline(ax,25+pD.N_mort,'--','Color',[.6 .6 .6]);
    xlim(ax,[25 99]); title(ax,ttl{k},'FontWeight','normal'); ylabel(ax,yl{k}); xlabel(ax,'age');
    if k==2, ylim(ax,[0 1.05]); end
    if k==1, legend(ax,{'default grid','designed grid'},'Location','southeast','Box','off'); end
end
for jj=1:2
    ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    V=U{jj}; lo=prctile(V(:,tt),1,1); hi=prctile(V(:,tt),99,1);
    fill(ax,[ages(tt) fliplr(ages(tt))],[lo fliplr(hi)],[.4 .4 .4],'FaceAlpha',.18,'EdgeColor','none');
    ga={pD.u1_grid,pD.u2_grid}; gb={pB.u1_grid,pB.u2_grid};
    for i=1:numel(ga{jj}), yline(ax,ga{jj}(i),'-','Color',[cA .55],'LineWidth',.8); end
    for i=1:numel(gb{jj}), yline(ax,gb{jj}(i),'-','Color',[cB .55],'LineWidth',.8); end
    xlim(ax,[27 99]); xlabel(ax,'age'); ylabel(ax,nm{jj});
    title(ax,sprintf('%s nodes vs the population (grey)',nm{jj}),'FontWeight','normal');
end
sgtitle(f,'OWNER. Renter trims not reused -- designed from the owner''s own occupancy. Dashed line = mortgage ends.', ...
        'FontWeight','normal','FontSize',12);
exportgraphics(f,[o 'fig_owner_grid.png'],'Resolution',150);
disp('done');
