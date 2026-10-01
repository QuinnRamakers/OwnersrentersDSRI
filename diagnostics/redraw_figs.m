function redraw_figs(sp, outdir)
%REDRAW_FIGS  Readable versions of the optimiser figures.
%
%   The first attempt plotted the raw Bellman objective, which is dominated by
%   the consumption dimension and spans orders of magnitude, so every panel
%   saturated. Everything here is on one interpretable scale: percent of
%   certainty equivalent below the best point available at that node.

if nargin<1||isempty(sp), sp='C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/'; end
if nargin<2||isempty(outdir), outdir='C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc/diagnostics/factorial_figs/'; end
fig_landscape(sp, outdir);
fig_sweep(sp, outdir);
end

% =======================================================================
function fig_landscape(sp, outdir)
g=5; ceof=@(v) ((1-g)*v).^(1/(1-g));
L = load([sp 'scan_ce.mat']);        % loss, dpi, rng_rel, npk, tt, kk
sd = [sp 'scans/']; F = dir([sd 'scan_*.mat']);

% two genuine traps (big CE loss) and, for contrast, one numerical tie:
% far away in pi but worth nothing, which is what the naive metric overcounts.
trap = find(L.loss > 0.01 & L.npk > 1);
[~,o1] = sort(L.loss(trap),'descend'); trap = trap(o1);
tie  = find(L.dpi > 0.5 & L.loss < 1e-6);
pick = [trap(1); trap(2); tie(1)];
lab  = {'a real trap','a real trap','a numerical tie'};

mk   = {'o','s','^','d','v'};
mcol = [0.85 0.33 0.10; 0.55 0.40 0.10; 0.60 0.25 0.65; 0.95 0.62 0.20; 0.15 0.45 0.75];

f=figure('Position',[20 20 1580 900],'Color','w','Visible','off');
tl=tiledlayout(f,2,3,'Padding','compact','TileSpacing','compact');
for q=1:3
    S = load([sd F(pick(q)).name]);
    tok=regexp(F(pick(q)).name,'scan_t(\d+)_k(\d+)','tokens'); tok=tok{1};
    age = 24+str2double(tok{1});
    cmax = ceof(S.gmax(3));
    P = 100*(ceof(S.rhs)/cmax - 1);          % % CE below the node's best
    P(~isfinite(P)) = -50;

    % ---- top: the surface, clipped so the structure near the top is visible
    ax=nexttile(tl,q); hold(ax,'on');
    lo = max(-3, prctile(P(:),5));
    imagesc(ax,S.pi,S.c,max(P,lo)); axis(ax,'xy'); clim(ax,[lo 0]);
    colormap(ax, flipud(parula));
    cb=colorbar(ax); cb.Label.String='% CE below best';
    plot(ax,S.seed(2),S.seed(1),'o','MarkerSize',13,'LineWidth',2.2,'Color',[1 1 1]);
    plot(ax,S.gmax(2),S.gmax(1),'p','MarkerSize',20,'MarkerFaceColor',[1 1 1],'MarkerEdgeColor',[0 0 0],'LineWidth',1);
    for m=1:size(S.land,1)
        if isfinite(S.land(m,1))
            plot(ax,S.land(m,2),S.land(m,1),mk{m},'MarkerSize',9, ...
                'MarkerFaceColor',mcol(m,:),'MarkerEdgeColor','k','LineWidth',.7);
        end
    end
    xlim(ax,[0 1]); ylim(ax,[min(S.c) max(S.c)]);
    xlabel(ax,'equity share \pi'); ylabel(ax,'consumption share c');
    title(ax,sprintf('age %d  --  %s', age, lab{q}),'FontWeight','normal');

    % ---- bottom: the pi slice, same units
    [~,icb]=min(abs(S.c-S.gmax(1)));
    y = 100*(ceof(S.rhs(icb,:))/cmax - 1);
    ax=nexttile(tl,q+3); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    area(ax,S.pi,y,'FaceColor',[.20 .35 .75],'FaceAlpha',.12,'LineStyle','none','BaseValue',min(y)-1e-9);
    plot(ax,S.pi,y,'Color',[.1 .1 .1],'LineWidth',2);
    xline(ax,S.seed(2),'-','Color',[.45 .45 .45],'LineWidth',2);
    plot(ax,S.gmax(2),0,'p','MarkerSize',18,'MarkerFaceColor',[.95 .85 .2],'MarkerEdgeColor','k');
    for m=1:size(S.land,1)
        if isfinite(S.land(m,2))
            [~,j]=min(abs(S.pi-S.land(m,2)));
            plot(ax,S.land(m,2),y(j),mk{m},'MarkerSize',9, ...
                'MarkerFaceColor',mcol(m,:),'MarkerEdgeColor','k','LineWidth',.7);
        end
    end
    rg = max(y)-min(y);
    if rg < 1e-9
        ylim(ax,[-1 0.2]);
        text(ax,0.5,-0.5,sprintf('objective varies by %.1e %% across all of \\pi', rg), ...
            'HorizontalAlignment','center','FontSize',9,'Color',[.35 .35 .35]);
    else
        ylim(ax,[min(y)-0.08*rg, 0.08*rg]);
    end
    xlim(ax,[0 1]); xlabel(ax,'equity share \pi'); ylabel(ax,'% CE below best');
    title(ax,sprintf('worth %.2f%% CE across \\pi', 100*(1-min(ceof(S.rhs(icb,:)))/max(ceof(S.rhs(icb,:))))), ...
        'FontWeight','normal');
    if q==1
        legend(ax,[{'','objective','seed (warm start)','global optimum'}, S.methods], ...
            'Box','off','Location','southeast','FontSize',7.5);
    end
end
sgtitle(f,['Why the equity share is hard to find. Colour and height are percent of certainty equivalent below the best point at that node. ' ...
  'Left and middle: the objective has a low plateau and a separate higher one, and a solver started at the warm start stays on the low one. ' ...
  'Right: a node where pi is numerically irrelevant, which the raw pi-distance metric wrongly counts as a failure.'], ...
  'FontWeight','normal','FontSize',10.5,'Interpreter','tex');
exportgraphics(f,[outdir 'S3_objective_landscape.png'],'Resolution',130); close(f);
fprintf('S3 written\n');
end

% =======================================================================
function fig_sweep(sp, outdir)
L = load([sp 'optimiser_study.mat']); S=L.S;
ref = find(strcmp('B refine (reference)',{S.name}),1);
a = S(ref).out.ages;
% group: does the method search pi globally?
glob = false(1,numel(S));
for i=1:numel(S)
    glob(i) = contains(S(i).name,'refine') || contains(S(i).name,'multistart');
end
gi = find(glob); li = find(~glob);
cG = [0.05 0.05 0.05; 0.15 0.45 0.75; 0.30 0.65 0.45];
cL = [0.85 0.33 0.10; 0.95 0.62 0.20; 0.75 0.50 0.15; 0.60 0.25 0.65; 0.55 0.15 0.35];

f=figure('Position',[20 20 1520 660],'Color','w','Visible','off');
tl=tiledlayout(f,1,2,'Padding','compact','TileSpacing','compact');

ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12; h=gobjects(0); nm={};
for j=1:numel(li)
    i=li(j); h(end+1)=plot(ax,a,100*S(i).out.pi,'Color',cL(j,:),'LineWidth',1.7,'LineStyle','--'); nm{end+1}=S(i).name;
end
for j=1:numel(gi)
    i=gi(j); lw=3.0*(i==ref)+2.0*(i~=ref);
    h(end+1)=plot(ax,a,100*S(i).out.pi,'Color',cG(j,:),'LineWidth',lw); nm{end+1}=S(i).name;
end
xline(ax,67,'-','Color',[.4 .4 .4],'LineWidth',1.2);
xlim(ax,[60 95]); ylim(ax,[30 100]);
xlabel(ax,'age'); ylabel(ax,'% of liquid savings in equity');
title(ax,'retirement equity share: dashed = searches \pi locally, solid = searches \pi globally','FontWeight','normal');
lg = legend(ax,h,nm,'Box','off','FontSize',8.5,'NumColumns',4); lg.Layout.Tile='south';

ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
for j=1:numel(li)
    i=li(j); plot(ax,a,100*(S(i).out.pi-S(ref).out.pi),'Color',cL(j,:),'LineWidth',1.7,'LineStyle','--');
end
for j=1:numel(gi)
    i=gi(j); plot(ax,a,100*(S(i).out.pi-S(ref).out.pi),'Color',cG(j,:),'LineWidth',2.0);
end
yline(ax,0,'-','Color',[.5 .5 .5]); xline(ax,67,'-','Color',[.4 .4 .4],'LineWidth',1.2);
xlim(ax,[60 95]);
xlabel(ax,'age'); ylabel(ax,'equity share minus the global-search answer (pp)');
title(ax,'every locally-started method falls below, by 2pp to 55pp depending on the method','FontWeight','normal');

sgtitle(f,['Only a global sweep of \pi finds the retirement optimum. Renter, 12x12x8 cube, gh_n=3, 2000 paths. ' ...
  'Widening the finite-difference step or changing algorithm does not help; the methods split purely on whether they search \pi globally.'], ...
  'FontWeight','normal','FontSize',11,'Interpreter','tex');
exportgraphics(f,[outdir 'S2_optimiser_sweep.png'],'Resolution',140); close(f);
fprintf('S2 written\n');
end
