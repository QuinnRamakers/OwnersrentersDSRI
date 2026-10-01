% Does node placement fix the early-life divergence?
%
% The convergence ladder that found linear-z diverging in the twenties ran on
% the production default placement, which leaves 17-20 of 73 ages with at most
% one node under the population on u1 and 11 on u2. That is a confound: a
% sequence of badly-placed grids can fail to converge for reasons that have
% nothing to do with the model.
%
% Three placements, three sizes each, production default interpolant. The arm
% whose answer stops moving under refinement is the better grid. Node counts
% under the population are a proxy; THIS is the thing the proxy was standing in
% for, so if they disagree, this wins.
%
% It also settles a recorded conflict: an earlier session found logratio spacing
% WORSE than uniform on a smoothness/accuracy measure (0.111 vs 0.055), which is
% the opposite of what the node counts predict.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
o = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
dims = {[10 10 8],[14 14 10],[18 18 12]};
arms = {'default','logratio','handover'};
R = cell(3,3);
for ia = 1:3
  for ig = 1:3
    p = config.params(); p.is_owner = false;
    p.grid_mode='none'; p.polish_ver=2; p.use_refine=false; p.interp_object='z';
    switch arms{ia}
        case 'logratio', p.grid_space = 'logratio';
        case 'handover', p.lambda_hi=0.42; p.grid_pow=2; p.grid_pow_u2=1; p.u2_lo=0.60;
    end
    p = utility.build_state_grids(p, dims{ig}, 3);
    [~,mg,sl] = config.income_profile(p);
    prof.mu_growth=mg; prof.sigma_l_log=sl; prof.p_surv=config.survival(p);
    shk = grids.shock_grid(p); ann = pension.annuity_price(p, prof, shk);
    tic; sol = solver.solve_lifecycle_lna(p, prof, shk, ann); el=toc;
    sim = simulate.forward(p, prof, sol, ann, 4000, 20260511, p.b0);
    r.arm=arms{ia}; r.n=numel(p.u1_grid)*numel(p.u2_grid)*numel(p.u3_grid); r.sec=el;
    r.C=median(sim.C,1,'omitnan'); r.pi=mean(sim.pi,1,'omitnan'); r.ages=sim.ages;
    d2=@(v) mean(abs(diff(v,2)))/mean(abs(v));
    r.rough_pi_ret = 100*d2(r.pi(41:60));      % ages 65-84, the retirement roughness
    R{ia,ig}=r;
    fprintf('%-9s n=%5d %4.0fs  C25=%6.0f C45=%6.0f pi25=%.2f pi45=%.2f  |d2pi| ret %.2f%%\n', ...
        arms{ia}, r.n, el, r.C(1), r.C(21), r.pi(1), r.pi(21), r.rough_pi_ret);
  end
end
save([o 'placement_ladder.mat'],'R');

gap=@(a,b,i) 100*mean(abs(b(i)-a(i))./max(abs(a(i)),eps));
yo=1:15; mid=16:45; old=46:75;
fprintf('\nDrift between successive refinements (mean |dC|/C). Converging = falling.\n');
fprintf('%-10s %16s %9s %9s %9s %12s\n','placement','refinement','25-39','40-69','70+','|dpi| 25-39');
for ia=1:3
  for ig=1:2
    a=R{ia,ig}; b=R{ia,ig+1};
    fprintf('%-10s %6d->%-9d %8.1f%% %8.1f%% %8.1f%% %12.3f\n', arms{ia}, a.n, b.n, ...
      gap(a.C,b.C,yo), gap(a.C,b.C,mid), gap(a.C,b.C,old), mean(abs(b.pi(yo)-a.pi(yo))));
  end
end
fprintf('\nConsumption at 25 by grid size\n%-10s %10s %10s %10s\n','placement','small','mid','large');
for ia=1:3
    fprintf('%-10s %10.0f %10.0f %10.0f\n', arms{ia}, R{ia,1}.C(1), R{ia,2}.C(1), R{ia,3}.C(1));
end
fprintf('\nRetirement roughness of pi (ages 65-84, mean |2nd diff| / level)\n%-10s %10s %10s %10s\n','placement','small','mid','large');
for ia=1:3
    fprintf('%-10s %9.2f%% %9.2f%% %9.2f%%\n', arms{ia}, R{ia,1}.rough_pi_ret, R{ia,2}.rough_pi_ret, R{ia,3}.rough_pi_ret);
end

f=figure('Position',[100 100 1180 420],'Color','w'); tl=tiledlayout(f,1,3,'Padding','compact','TileSpacing','compact');
cmap=[.85 .33 .10; .47 .67 .19; .20 .35 .75];
for ia=1:3
    ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    for ig=1:3, plot(ax,R{ia,ig}.ages(1:75),R{ia,ig}.C(1:75),'Color',cmap(ig,:),'LineWidth',1.5); end
    xline(ax,40,':','Color',[.4 .4 .4]); xline(ax,67,':','Color',[.6 .6 .6]);
    xlim(ax,[25 99]); ylim(ax,[0 4.5e4]); xlabel(ax,'age'); title(ax,arms{ia},'FontWeight','normal');
    if ia==1, ylabel(ax,'median consumption'); legend(ax,arrayfun(@(k) sprintf('%d nodes',R{ia,k}.n),1:3,'uni',0),'Location','southeast','Box','off'); end
end
sgtitle(f,'Same interpolant, three node placements: do the three grid sizes land on top of each other?','FontWeight','normal','FontSize',12);
exportgraphics(f,[o 'fig_placement_ladder.png'],'Resolution',150);
disp('done');
