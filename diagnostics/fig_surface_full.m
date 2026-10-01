function fig_surface_full(sp, outdir)
%FIG_SURFACE_FULL  Unclipped surfaces across ages, with where each method lands.
%
%   S6 clips at -12% so the ridge is readable. Here nothing is clipped, which
%   shows how little of the (c, pi) square is usable at all: the shelf along the
%   top is everything, and the rest is the ruin plain. One node per scanned age,
%   chosen for genuine basin structure in pi with the warm start in the wrong
%   basin, and every optimiser's landing point drawn at the value it actually
%   attains.

if nargin<1||isempty(sp)
    sp='C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
end
if nargin<2||isempty(outdir)
    outdir='C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc/diagnostics/factorial_figs/';
end
g=5; ceof=@(v) ((1-g)*v).^(1/(1-g));
sd=[sp 'scans/']; F=dir([sd 'scan_*.mat']); M=numel(F);
RIPPLE=1e-4;

nb=zeros(M,1); wrong=false(M,1); loss=zeros(M,1); age=zeros(M,1);
for i=1:M
    S=load([sd F(i).name]);
    pr=ceof(max(S.rhs,[],1));
    e=local_basins(pr, RIPPLE);
    nb(i)=numel(unique(e));
    [~,ips]=min(abs(S.pi-S.seed(2))); [~,jb]=max(pr);
    wrong(i)=e(ips)~=jb; loss(i)=(max(pr)-pr(e(ips)))/max(pr);
    tok=regexp(F(i).name,'scan_t(\d+)','tokens'); age(i)=24+str2double(tok{1}{1});
end

% One node per age, and a DIFFERENT cube node each time: taking the hardest
% node at every age returns the same state over and over, which made the first
% version of this figure six panels of four states.
kof = zeros(M,1);
for i=1:M
    tok=regexp(F(i).name,'scan_t\d+_k(\d+)','tokens'); kof(i)=str2double(tok{1}{1});
end
ages = sort(unique(age)).';
pick = []; ag_of = []; used = [];
for a = ages
    ib = find(age==a & nb>=2 & wrong);
    if isempty(ib), ib = find(age==a & nb>=2); end
    ib = ib(~ismember(kof(ib), used));
    if isempty(ib), continue; end
    [~,o] = sort(loss(ib),'descend');
    pick(end+1,1) = ib(o(1)); ag_of(end+1,1) = a;                        %#ok<AGROW>
    used(end+1) = kof(ib(o(1)));                                          %#ok<AGROW>
end

mk   = {'o','s','^','d','v'};
mcol = [0.85 0.33 0.10; 0.55 0.40 0.10; 0.60 0.25 0.65; 0.95 0.62 0.20; 0.15 0.45 0.75];
nc = 3; nr = ceil(numel(pick)/nc);
f=figure('Position',[10 10 1720 560*nr],'Color','w','Visible','off');
tl=tiledlayout(f,nr,nc,'Padding','compact','TileSpacing','compact');
hleg = gobjects(0); lleg = {};
for q=1:numel(pick)
    S=load([sd F(pick(q)).name]);
    CE=ceof(S.rhs); vref=max(CE(:));
    Z=100*(CE/vref-1); Z(~isfinite(Z))=-100;
    [~,ics]=min(abs(S.c-S.seed(1))); [~,ips]=min(abs(S.pi-S.seed(2)));
    [~,im]=max(Z(:)); [ig,jg]=ind2sub(size(Z),im);

    ax=nexttile(tl); hold(ax,'on');
    surf(ax,S.pi,S.c,Z,'EdgeColor','none','FaceColor','interp','FaceAlpha',.92);
    colormap(ax,parula); clim(ax,[min(Z(:)) 0]);
    zl = [min(Z(:)) 6];
    h0=plot3(ax,S.seed(2),S.seed(1),Z(ics,ips)+2,'o','MarkerSize',11, ...
        'MarkerFaceColor',[1 1 1],'MarkerEdgeColor','k','LineWidth',1.4);
    hs=plot3(ax,S.pi(jg),S.c(ig),Z(ig,jg)+2,'p','MarkerSize',18, ...
        'MarkerFaceColor',[.98 .80 .15],'MarkerEdgeColor','k','LineWidth',1);
    hm = gobjects(1,size(S.land,1));
    for m=1:size(S.land,1)
        if isfinite(S.land(m,1))
            zv = 100*(ceof(S.land(m,3))/vref-1);
            if ~isfinite(zv), zv = -100; end
            % stem down to the surface so the height is readable in 3D
            plot3(ax,[S.land(m,2) S.land(m,2)],[S.land(m,1) S.land(m,1)],[zl(1) zv], ...
                '-','Color',[mcol(m,:) .45],'LineWidth',1);
            hm(m)=plot3(ax,S.land(m,2),S.land(m,1),zv+2,mk{m},'MarkerSize',9, ...
                'MarkerFaceColor',mcol(m,:),'MarkerEdgeColor','k','LineWidth',.7);
        end
    end
    view(ax,-38,42); grid(ax,'on');
    xlabel(ax,'\pi'); ylabel(ax,'c'); zlabel(ax,'% CE below best');
    zlim(ax,zl); xlim(ax,[0 1]);
    title(ax,{sprintf('age %d  --  %d basins in \\pi', ag_of(q), nb(pick(q))), ...
              sprintf('%.0f%% of the square is >50%% below best', 100*mean(Z(:)<-50))}, ...
          'FontWeight','normal');
    if q==1
        hleg = [h0 hs hm(isgraphics(hm))];
        lleg = [{'warm start (seed)','global optimum'}, S.methods(isgraphics(hm))];
    end
end
lg = legend(hleg, lleg, 'Box','off','FontSize',9,'NumColumns',4);
lg.Layout.Tile = 'south';
sgtitle(f,['Unclipped surfaces across ages, and where each method stops. The usable region is the narrow shelf; the rest of the square is the ruin plain, ' ...
  'which is what swamped the colour scale in the first version of this figure. Markers sit at the value each method actually attains.'], ...
  'FontWeight','normal','FontSize',11,'Interpreter','tex');
exportgraphics(f,[outdir 'S7_surface_unclipped.png'],'Resolution',130); close(f);
fprintf('S7 written: %d ages\n', numel(pick));

% where the methods end up, in one table
fprintf('\n%-6s %-8s', 'age','basins');
S=load([sd F(pick(1)).name]);
fprintf('%-22s','seed'); for m=1:numel(S.methods), fprintf('%-22s',S.methods{m}); end
fprintf('\n');
for q=1:numel(pick)
    S=load([sd F(pick(q)).name]);
    CE=ceof(S.rhs); vref=max(CE(:));
    [~,ics]=min(abs(S.c-S.seed(1))); [~,ips]=min(abs(S.pi-S.seed(2)));
    fprintf('%-6d %-8d', ag_of(q), nb(pick(q)));
    fprintf('pi=%.2f %+6.1f%%   ', S.seed(2), 100*(CE(ics,ips)/vref-1));
    for m=1:size(S.land,1)
        zv = 100*(ceof(S.land(m,3))/vref-1);
        fprintf('pi=%.2f %+6.1f%%   ', S.land(m,2), zv);
    end
    fprintf('\n');
end
end

% ------------------------------------------------------------------------
function endi = local_basins(prv, ripple)
prv=prv(:).'; n=numel(prv); fin=prv(isfinite(prv));
tol=ripple*(max(fin)-min(fin)); endi=zeros(1,n);
for j=1:n
    k=j;
    for step=1:2*n
        kl=k; while kl>1 && abs(prv(kl-1)-prv(k))<=tol, kl=kl-1; end
        kr=k; while kr<n && abs(prv(kr+1)-prv(k))<=tol, kr=kr+1; end
        up_r = kr<n && prv(kr+1)>prv(k)+tol;
        up_l = kl>1 && prv(kl-1)>prv(k)+tol;
        if up_r && (~up_l || prv(kr+1)>=prv(kl-1)), k=kr+1;
        elseif up_l, k=kl-1;
        else, break; end
    end
    endi(j)=k;
end
end
