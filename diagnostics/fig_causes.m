function fig_causes(out_dir)
%FIG_CAUSES  What fixes the resolution dependence, and what does not.
%
%   Three arms against the 8064-node baseline: raise the consumption floor so
%   ruin is finite rather than catastrophic, trim the axes to the occupied
%   range, or both.
%
%   One caveat governs how the floor arm can be read. Raising phi_floor changes
%   the model, so that arm converges to a different limit than the reference it
%   is measured against, and its distance mixes a model difference with a
%   solution error. Only the trimmed arm, which changes node placement and
%   nothing else, is a clean convergence comparison. The floor arm is reported
%   because it is informative about direction, not as a measured convergence
%   rate.

if nargin<1||isempty(out_dir), out_dir=fileparts(mfilename('fullpath')); end
fd=fullfile(out_dir,'factorial_figs');
L=load(fullfile(out_dir,'convergence_causes.mat')); R=L.R;
B=load(fullfile(out_dir,'grid_convergence.mat')); RB=B.R;
b5=find([RB.gh]==5); [~,ob]=sort([RB(b5).n]); b5=b5(ob); ref=RB(b5(end));

dims={[12 12 8],[16 16 10],[20 20 12]}; nn=cellfun(@prod,dims);
arms=[{'baseline'} unique({R.arm},'stable')];
col=[0.20 0.20 0.20; 0.85 0.33 0.10; 0.15 0.45 0.75; 0.30 0.65 0.45];

E=nan(numel(arms),numel(dims),3);      % acc dpi, ret dpi, dC/C
for a=1:numel(arms)
    for i=1:numel(dims)
        s=pick(R,RB,b5,arms{a},dims{i});
        if isempty(s), continue; end
        acc=s.ages<=55; ret=s.ages>=67;
        dpi=s.pi_liq-ref.sim.pi_liq; dC=(s.C-ref.sim.C)./max(ref.sim.C,eps);
        E(a,i,:)=[sqrt(mean(dpi(acc).^2)) sqrt(mean(dpi(ret).^2)) sqrt(mean(dC.^2))];
    end
end

f=figure('Position',[10 10 1640 900],'Color','w','Visible','off');
tl=tiledlayout(f,2,3,'Padding','compact','TileSpacing','compact');
ttl={'equity share, accumulation (<=55)','equity share, retirement (>=67)','consumption path'};
h=gobjects(0);
for m=1:3
    ax=nexttile(tl,m); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    for a=1:numel(arms)
        hh=plot(ax,nn,squeeze(E(a,:,m)),'-o','Color',col(a,:),'LineWidth',2, ...
            'MarkerFaceColor',col(a,:),'MarkerSize',6);
        if m==1, h(a)=hh; end
    end
    set(ax,'XScale','log','YScale','log');
    xlabel(ax,'cube nodes'); ylabel(ax,'RMS deviation from the 8064-node solve');
    title(ax,ttl{m},'FontWeight','normal');
end

% simulated decisions: baseline vs trimmed at the largest matched cube
s0=pick(R,RB,b5,'baseline',dims{end});
s1=pick(R,RB,b5,'trimmed to occupancy',dims{end});
F={'C','consumption, EUR000',1e-3; 'saving','resources not consumed, EUR000',1e-3; ...
   'pi_liq','equity share, %',100};
for m=1:3
    ax=nexttile(tl,3+m); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    plot(ax,ref.sim.ages,ref.sim.(F{m,1})*F{m,3},'Color',[.1 .1 .1],'LineWidth',2.6);
    if ~isempty(s0), plot(ax,s0.ages,s0.(F{m,1})*F{m,3},'Color',col(1,:),'LineWidth',1.6,'LineStyle','--'); end
    if ~isempty(s1), plot(ax,s1.ages,s1.(F{m,1})*F{m,3},'Color',col(3,:),'LineWidth',1.8); end
    xline(ax,67,'-','Color',[.4 .4 .4]); xlim(ax,[25 95]);
    xlabel(ax,'age'); ylabel(ax,F{m,2});
    title(ax,F{m,2},'FontWeight','normal');
    if m==1
        legend(ax,{'8064 nodes (reference)','baseline grid, 4800','trimmed grid, 4800'}, ...
            'Box','off','Location','northwest','FontSize',8);
    end
end
lg=legend(h,arms,'Box','off','FontSize',9,'NumColumns',4); lg.Layout.Tile='south';
sgtitle(f,['What fixes the resolution dependence. Top: distance from the 8064-node answer, log-log, so a straight line falling to the right is convergence. ' ...
  'Bottom: the decisions themselves at 4800 nodes against the reference.'], ...
  'FontWeight','normal','FontSize',11,'Interpreter','tex');
exportgraphics(f,fullfile(fd,'S26_causes.png'),'Resolution',130); close(f);
fprintf('S26 written\n');

fprintf('\n=== how much each change is worth, at 4800 nodes ===\n');
fprintf('%-24s %12s %12s %12s\n','arm','dpi acc','dpi ret','dC/C');
for a=1:numel(arms)
    fprintf('%-24s %12.4f %12.4f %12.4f\n', arms{a}, E(a,end,1), E(a,end,2), E(a,end,3));
end
fprintf('\ntrimmed grid at 2560 nodes vs baseline at 4800 nodes:\n');
fprintf('   dC/C  %.4f  vs  %.4f\n', E(3,2,3), E(1,3,3));
fprintf('   dpi ret %.4f  vs  %.4f\n', E(3,2,2), E(1,3,2));
end

% ------------------------------------------------------------------------
function s = pick(R, RB, b5, arm, dim)
s=[];
if strcmp(arm,'baseline')
    k=b5(arrayfun(@(j) isequal(RB(j).dim,dim), b5));
    if ~isempty(k), s=RB(k(1)).sim; end
else
    k=find(strcmp({R.arm},arm) & arrayfun(@(r) isequal(r.dim,dim), R),1);
    if ~isempty(k), s=R(k).sim; end
end
end
