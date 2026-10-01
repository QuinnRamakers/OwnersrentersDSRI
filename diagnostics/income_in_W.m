% Should labour income sit inside W, or should the first coordinate be the
% ratio of income to financial wealth?
%
% Algebra first. With F = X + A + H and x = Y/F,
%       u1 = Y/W = Y/(F+Y) = x/(1+x),
% so the two are the SAME coordinate under a monotone map. Nothing about the
% model changes; only where the nodes fall changes. This measures that, by
% putting the same 16 nodes on the axis three ways and counting how many land
% under the population.
%
% Where the choice is NOT innocuous is the scale. V = (scale * z)^(1-gamma), and
% F can reach zero while W = F + Y cannot, since income is strictly positive.
% The last block checks how close F actually gets.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
o = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
L = load([o 'occ_sim.mat']); sim=L.sim; p=L.p;
X=sim.X;A=sim.A;H=sim.H;Y=sim.Y;W=sim.W;T=p.T; ages=sim.ages; tt=3:T-1;
F = X+A+H;  xr = Y./F;  u1 = Y./W;

fprintf('Identity check: max |u1 - x/(1+x)| = %.3g\n\n', max(abs(u1(:) - xr(:)./(1+xr(:)))));

fprintf('Income/financial-wealth ratio x = Y/F, by age\n%6s %10s %10s %10s\n','age','p1','median','p99');
for a=[27 35 45 55 66 67 80 90]
    t=a-p.age0+1; q=prctile(xr(:,t),[1 50 99]);
    fprintf('%6d %10.3f %10.3f %10.3f\n',a,q(1),q(2),q(3));
end

lo=prctile(u1(:,tt),1,1); hi=prctile(u1(:,tt),99,1);
N=16;
g={}; nm={};
nm{end+1}='uniform in u1 = Y/W (current)';      g{end+1}=linspace(0.002,0.6,N).';
xs=xr(:,tt); xs=xs(isfinite(xs)&xs>0);
lgx=logspace(log10(prctile(xs,0.5)),log10(prctile(xs,99.5)),N).';
nm{end+1}='geometric in x = Y/F (coauthor)';    g{end+1}=sort(lgx./(1+lgx));
v=u1(:,tt); v=v(isfinite(v));
nm{end+1}='quantile-placed in u1 (measured)';   g{end+1}=unique(prctile(v,linspace(0.5,99.5,N)).');

fprintf('\nNodes under the population on the first axis, %d nodes each\n',N);
fprintf('%-36s %8s %8s %14s\n','placement','mean','worst','starved ages');
for k=1:numel(g)
    cnt=arrayfun(@(t) sum(g{k}>=lo(t)&g{k}<=hi(t)),1:numel(tt));
    fprintf('%-36s %8.1f %8d %14d\n',nm{k},mean(cnt),min(cnt),sum(cnt<2));
end

fprintf('\nHow close does financial wealth F get to zero? (F in years of current income)\n');
fprintf('%6s %12s %12s %12s\n','age','p0.1','p1','median');
for a=[27 35 45 55 66 67 80 90]
    t=a-p.age0+1; q=prctile(F(:,t)./Y(:,t),[0.1 1 50]);
    fprintf('%6d %12.3f %12.3f %12.3f\n',a,q(1),q(2),q(3));
end
fprintf('\nmin F/Y over all households and ages: %.4f   (W/Y can never go below 1)\n', ...
        min(min(F(:,tt)./Y(:,tt))));
fprintf('share of household-years with F < 0.5 years of income: %.2f%%\n', ...
        100*mean(reshape(F(:,tt)./Y(:,tt) < 0.5,[],1)));

f=figure('Position',[100 100 1180 400],'Color','w');
tl=tiledlayout(f,1,3,'Padding','compact','TileSpacing','compact');
for k=1:numel(g)
    ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.1;
    fill(ax,[ages(tt) fliplr(ages(tt))],[lo fliplr(hi)],[.16 .47 .84],'FaceAlpha',.2,'EdgeColor','none');
    plot(ax,ages(tt),median(u1(:,tt),1),'Color',[.16 .47 .84],'LineWidth',1.5);
    for i=1:numel(g{k}), yline(ax,g{k}(i),'-','Color',[.75 .4 .2 .55],'LineWidth',.7); end
    xline(ax,67,':','Color',[.3 .3 .3]); xlim(ax,[27 99]); ylim(ax,[0 0.62]);
    title(ax,nm{k},'FontWeight','normal','FontSize',10); xlabel(ax,'age');
    if k==1, ylabel(ax,'u1 = Y/W'); end
end
sgtitle(f,'Same coordinate, same 16 nodes, three placements','FontWeight','normal','FontSize',12);
exportgraphics(f,[o 'fig_income_in_W.png'],'Resolution',150);
disp('figure written');
