function fig_refinement(sp, outdir)
%FIG_REFINEMENT  What the derivative-free refinement actually does.
%
%   refine_cpi_u runs four rounds. Round 1 evaluates pi at 21 points spanning
%   the whole interval, which is a global sweep rather than a local refinement,
%   and that is the round that crosses the cliff. Rounds 2 to 4 shrink a window
%   around the incumbent and only polish. The trajectory plotted here is the
%   one recorded inside the solver on the node's own objective.

if nargin<1||isempty(sp), sp='C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/'; end
if nargin<2||isempty(outdir), outdir='C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc/diagnostics/factorial_figs/'; end
g=5; ceof=@(v) ((1-g)*v).^(1/(1-g));
sd=[sp 'scans/']; F=dir([sd 'scan_*.mat']); M=numel(F);

% pick two nodes where the refinement has real work to do
% Select nodes where the SEED sits well below the best pi, so the figure shows
% the refinement crossing in pi rather than merely polishing c.
% The seed's value is the one at its OWN c, not the envelope at its pi: the
% refinement starts from that point, so the gain has to be measured from it.
seedloss=zeros(M,1); age=zeros(M,1); npk=zeros(M,1); dpi_move=zeros(M,1); closed=zeros(M,1);
for i=1:M
    S=load([sd F(i).name]);
    if ~isfield(S,'refine')||isempty(S.refine), continue; end
    pr=ceof(max(S.rhs,[],1)); pmax=max(pr);
    [~,ics]=min(abs(S.c-S.seed(1))); [~,ips]=min(abs(S.pi-S.seed(2)));
    sv=ceof(S.rhs(ics,ips));
    seedloss(i)=(pmax-sv)/pmax;
    dpi_move(i)=abs(S.refine(4).best(2)-S.seed(2));      % did it move in pi?
    closed(i)=(ceof(S.refine(4).best(3))-sv)/pmax;       % how much it recovered
    tok=regexp(F(i).name,'scan_t(\d+)','tokens'); age(i)=24+str2double(tok{1}{1});
    pr2=pr/pmax; npk(i)=sum(pr2(2:end-1)>pr2(1:end-2) & pr2(2:end-1)>pr2(3:end));
end
% rank by how much the refinement actually recovers, so the figure shows it
% doing its job rather than a node where the seed's c defeats it
cand=find(closed>0.02 & npk>=2 & dpi_move>0.08);
[~,o]=sort(closed(cand),'descend'); cand=cand(o);
% two different ages so the figure is not two copies of one case
pick=cand(1);
other=cand(age(cand)~=age(cand(1)));
if ~isempty(other), pick=[pick; other(1)]; elseif numel(cand)>1, pick=[pick; cand(2)]; end
fprintf('refinement-gain candidates: %d\n', numel(cand));

rcol=[0.85 0.33 0.10; 0.20 0.45 0.75; 0.30 0.65 0.45; 0.55 0.25 0.65];
f=figure('Position',[20 20 1620 820],'Color','w','Visible','off');
tl=tiledlayout(f,numel(pick),3,'Padding','compact','TileSpacing','compact');
for q=1:numel(pick)
    S=load([sd F(pick(q)).name]);
    tok=regexp(F(pick(q)).name,'scan_t(\d+)','tokens'); ag=24+str2double(tok{1}{1});
    pr=ceof(max(S.rhs,[],1)); vrf=max([pr, arrayfun(@(r) ceof(S.refine(r).best(3)),1:4)]); y=100*(pr/vrf-1);

    % ---- 1: round 1 sweeps the whole interval
    ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    plot(ax,S.pi,y,'Color',[.15 .15 .15],'LineWidth',2.2);
    [~,jsq]=min(abs(S.pi-S.seed(2))); [~,icq]=min(abs(S.c-S.seed(1)));
    ysq=100*(ceof(S.rhs(icq,jsq))/vrf-1);
    ylo=min([y(:); ysq]); ry=-ylo; yl=[ylo-0.10*ry, 0.10*ry]; ylim(ax,yl);
    for pv=S.refine(1).pi
        plot(ax,[pv pv],[yl(1) yl(1)+0.05*(yl(2)-yl(1))],'-','Color',rcol(1,:),'LineWidth',1.4);
    end
    xline(ax,S.seed(2),'-','Color',[.5 .5 .5],'LineWidth',2.4);
    [~,js]=min(abs(S.pi-S.seed(2)));
    [~,icsA]=min(abs(S.c-S.seed(1))); ysA=100*(ceof(S.rhs(icsA,js))/vrf-1);
    plot(ax,S.seed(2),ysA,'o','MarkerSize',11,'MarkerFaceColor',[.9 .9 .9],'MarkerEdgeColor','k','LineWidth',1);
    b1=S.refine(1).best;
    b1v=100*(ceof(b1(3))/vrf-1);
    plot(ax,b1(2),b1v,'o','MarkerSize',12,'MarkerFaceColor',rcol(1,:),'MarkerEdgeColor','k','LineWidth',1);
    annotation_arrow(ax,S.seed(2),ysA,b1(2),b1v);
    xlim(ax,[0 1]);
    xlabel(ax,'equity share \pi  (fraction of liquid savings in equity)');
    ylabel(ax,{'% certainty equivalent below','the best \pi  (0 = optimal)'});
    title(ax,{sprintf('age %d, round 1: 21 points spanning all of \\pi',ag), ...
              sprintf('seed \\pi = %.2f jumps to \\pi = %.2f', S.seed(2), b1(2))}, ...
          'FontWeight','normal');
    if q==1, legend(ax,{'objective (c optimised out)','round-1 evaluations','seed (warm start)', ...
                        'value at the seed','where round 1 lands'},'Box','off','Location','southwest','FontSize',8); end

    % ---- 2: rounds 2-4 shrink around the incumbent
    ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    plot(ax,S.pi,y,'Color',[.15 .15 .15],'LineWidth',2.2);
    lo=min([S.refine(2).pi, S.refine(3).pi, S.refine(4).pi]);
    hi=max([S.refine(2).pi, S.refine(3).pi, S.refine(4).pi]);
    w=max(hi-lo,0.02); xlim(ax,[max(0,lo-w) min(1,hi+w)]);
    inw=S.pi>=max(0,lo-w) & S.pi<=min(1,hi+w);
    yy=y(inw); ryy=max(max(yy)-min(yy),1e-9);
    ylim(ax,[min(yy)-0.15*ryy, max(yy)+0.15*ryy]);
    for r=2:4
        for pv=S.refine(r).pi
            xline(ax,pv,'-','Color',[rcol(r,:) 0.45],'LineWidth',1.1);
        end
        br=S.refine(r).best; [~,jr]=min(abs(S.pi-br(2)));
        plot(ax,br(2),y(jr),'o','MarkerSize',11-2*(r-2),'MarkerFaceColor',rcol(r,:), ...
            'MarkerEdgeColor','k','LineWidth',1);
    end
    xlabel(ax,'equity share \pi'); ylabel(ax,'% CE below the best \pi');
    title(ax,'rounds 2-4: window shrinks by 4x each time','FontWeight','normal');
    if q==1, legend(ax,{'objective','round 2','round 3','round 4'},'Box','off','Location','southeast','FontSize',8); end

    % ---- 3: how much each round is worth
    ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    % Start from the seed's own value, at its own c. Using the envelope at the
    % seed's pi instead would compare a best-case c against the refinement's
    % actual one and make the refinement look like it went backwards.
    [~,ics2]=min(abs(S.c-S.seed(1))); [~,ips2]=min(abs(S.pi-S.seed(2)));
    vals=[ceof(S.rhs(ics2,ips2)), arrayfun(@(r) ceof(S.refine(r).best(3)), 1:4)];
    vref=max([max(pr), vals]);
    vy=100*(vals/vref-1);
    b=bar(ax,0:4,vy,0.6,'FaceColor',[.75 .78 .85],'EdgeColor',[.3 .3 .3]);
    b.FaceColor='flat'; b.CData(1,:)=[.6 .6 .6]; b.CData(2,:)=rcol(1,:);
    for r=3:5, b.CData(r,:)=rcol(r-1,:); end
    yline(ax,0,'-','Color',[.2 .2 .2],'LineWidth',1.2);
    set(ax,'XTick',0:4,'XTickLabel',{'seed','r1','r2','r3','r4'});
    ylabel(ax,{'% certainty equivalent below','the best point found'});
    xlabel(ax,'incumbent after each round');
    title(ax,sprintf('round 1 closes %.1f of the %.1f pp gap; rounds 2-4 add %.2f', ...
        abs(vy(1))-abs(vy(2)), abs(vy(1)), abs(vy(2))-abs(vy(5))),'FontWeight','normal');
end
sgtitle(f,['How the refinement finds the peak. It is named like a local polish but round 1 is a global sweep: 21 equally spaced values of \pi across the whole interval. ' ...
  'That is the round that crosses the cliff; rounds 2 to 4 only shrink a window around the winner and add very little.'], ...
  'FontWeight','normal','FontSize',11,'Interpreter','tex');
exportgraphics(f,[outdir 'S4_refinement_mechanism.png'],'Resolution',140); close(f);
fprintf('S4 written\n');
end

% ------------------------------------------------------------------------
function annotation_arrow(ax,x0,y0,x1,y1)
%ANNOTATION_ARROW  Simple in-axes arrow from the seed to the round-1 winner.
if abs(x1-x0) < 1e-9 && abs(y1-y0) < 1e-9, return; end
plot(ax,[x0 x1],[y0 y1],'-','Color',[.35 .35 .35],'LineWidth',1.2);
dx=x1-x0; dy=y1-y0; L=hypot(dx,dy);
xr=diff(xlim(ax)); yr=diff(ylim(ax));
hx=0.03*xr*dx/L; hy=0.03*yr*dy/L;
plot(ax,x1,y1,'>','MarkerSize',6,'MarkerFaceColor',[.35 .35 .35],'MarkerEdgeColor','none');
end
