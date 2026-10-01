% Raise the entry buffer and see whether early life stops being pathological.
%
% p.b0 is the liquid wealth a household starts with, in years of gross income.
% Production is 0.0791 -- about EUR 3,400 -- against a rent that takes 44% of
% gross income from day one. It is also the welfare anchor, so it is spliced onto
% the u1 and u2 axes; build_state_grids handles that.
%
% Two things are being asked, and they are different:
%   (a) does consumption at 25 stop sitting on the search bound?
%   (b) does early-life consumption stop moving with the grid?
% (b) is the one that matters and needs two grid sizes per arm. A recorded
% earlier result says b0 = 1 fails on its own; that predates the grid fixes, so
% it is re-tested here rather than assumed.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
o = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
b0s  = [0.0791 0.25 0.5 1.0];
dims = {[14 14 10],[18 18 12]};
R = cell(numel(b0s), 2);
for ib = 1:numel(b0s)
  for ig = 1:2
    p = config.params(); p.is_owner = false;
    p.grid_mode='none'; p.polish_ver=2; p.use_refine=false;
    p.b0 = b0s(ib);
    p.lambda_lo=0.0008; p.lambda_hi=0.44; p.grid_pow=1.6;
    p.u2_lo=0.45; p.grid_pow_u2=1; p.u3_lo=0.03; p.u3_hi=0.96;
    p = utility.build_state_grids(p, dims{ig}, 3);
    [~,mg,sl]=config.income_profile(p);
    pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(p);
    sk=grids.shock_grid(p); an=pension.annuity_price(p,pf,sk);
    sol=solver.solve_lifecycle_lna(p,pf,sk,an);
    sm=simulate.forward(p,pf,sol,an,4000,20260511,p.b0);
    r.b0=b0s(ib); r.n=numel(p.u1_grid)*numel(p.u2_grid)*numel(p.u3_grid);
    r.C=median(sm.C,1,'omitnan'); r.pi=mean(sm.pi,1,'omitnan'); r.ages=sm.ages;
    r.cfrac=median(sm.c_frac(:,1));                    % consumption share at 25
    r.LW25=median(sm.LW(:,1));
    r.cbound=min(max(1e-3, 0.01/(r.LW25/median(sm.W(:,1)))), 0.5);
    F=p.phi_floor*sm.Y(:,1:size(sm.C,2));
    r.fl=100*mean(mean(sm.LW(:,1:size(F,2))<=F,1));
    r.off=sm.diagnostics.n_offgrid_u1+sm.diagnostics.n_offgrid_u2;
    R{ib,ig}=r;
    fprintf('b0=%.4f n=%5d  C25=%7.0f  c-share@25=%.3f (bound %.3f)  LW25=%7.0f  pi25=%.2f  floored %.2f%%  off %d\n', ...
        b0s(ib), r.n, r.C(1), r.cfrac, r.cbound, r.LW25, r.pi(1), r.fl, r.off);
  end
end
save([o 'entry_buffer.mat'],'R','b0s','-v7.3');

gap=@(a,b,i) 100*mean(abs(b(i)-a(i))./max(abs(a(i)),eps));
fprintf('\n(b) does early life stop moving with the grid?  drift 2560 -> 4800 nodes\n');
fprintf('%-10s %10s %10s %10s %12s\n','b0 (years)','25-39','40-69','70+','C25 small/large');
for ib=1:numel(b0s)
    a=R{ib,1}; b=R{ib,2};
    fprintf('%-10.4f %9.1f%% %9.1f%% %9.1f%% %6.0f / %-6.0f\n', b0s(ib), ...
        gap(a.C,b.C,1:15), gap(a.C,b.C,16:45), gap(a.C,b.C,46:75), a.C(1), b.C(1));
end

ages=R{1,2}.ages; K=1:75; cols=[.85 .33 .10; .93 .69 .13; .47 .67 .19; .20 .35 .75];
f=figure('Position',[80 60 1280 460],'Color','w');
tl=tiledlayout(f,1,3,'Padding','compact','TileSpacing','compact');
ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
for ib=1:numel(b0s), plot(ax,ages(K),R{ib,2}.C(K),'Color',cols(ib,:),'LineWidth',1.7); end
xline(ax,67,':','Color',[.5 .5 .5]); xlim(ax,[25 99]); xlabel(ax,'age');
ylabel(ax,'median consumption'); title(ax,'consumption, finest grid','FontWeight','normal');
legend(ax,arrayfun(@(b) sprintf('b0 = %.2f yr',b),b0s,'uni',0),'Location','southeast','Box','off');
ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
for ib=1:numel(b0s), plot(ax,ages(K),R{ib,2}.pi(K),'Color',cols(ib,:),'LineWidth',1.7); end
xline(ax,67,':','Color',[.5 .5 .5]); xlim(ax,[25 99]); ylim(ax,[0 1.05]);
xlabel(ax,'age'); title(ax,'equity share','FontWeight','normal');
ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
dr=arrayfun(@(ib) gap(R{ib,1}.C,R{ib,2}.C,1:15), 1:numel(b0s));
dm=arrayfun(@(ib) gap(R{ib,1}.C,R{ib,2}.C,16:45), 1:numel(b0s));
plot(ax,b0s,dr,'-o','Color',[.85 .33 .10],'LineWidth',1.8,'MarkerFaceColor',[.85 .33 .10]);
plot(ax,b0s,dm,'-o','Color',[.20 .35 .75],'LineWidth',1.8,'MarkerFaceColor',[.20 .35 .75]);
xlabel(ax,'entry buffer, years of income'); ylabel(ax,'|dC|/C between grids, %');
title(ax,'grid sensitivity vs entry buffer','FontWeight','normal');
legend(ax,{'ages 25-39','ages 40-69'},'Box','off','Location','northeast');
sgtitle(f,'Renter, designed grid, gh\_n=3. Does starting with more liquid wealth fix early life?','FontWeight','normal','FontSize',12);
exportgraphics(f,[o 'fig_entry_buffer.png'],'Resolution',150);
disp('done');
