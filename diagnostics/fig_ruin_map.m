function fig_ruin_map(sp, out_dir)
%FIG_RUIN_MAP  Where ruin sits on the cube, and how close households get to it.
%
%   A node counts as ruined when the best it can do over all (c, pi) is a tiny
%   fraction of what the best node of that age achieves: whatever the household
%   chooses there, it cannot recover. Those nodes carry z near zero, and they
%   are the reason the continuation value has cliffs -- any interpolation
%   stencil spanning the boundary mixes a near-zero value into a healthy one.
%
%   The question this answers is whether households are near that boundary. If
%   they are, the value they are assigned depends on exactly where the boundary
%   falls between nodes, which moves with every refinement, and that is a
%   mechanism for resolution dependence that adding nodes anywhere else cannot
%   fix.
%
%   Reads scans_full (all nodes, 8 ages) and occupancy_src.

if nargin<1||isempty(sp)
    sp='C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
end
if nargin<2||isempty(out_dir)
    out_dir='C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc/diagnostics';
end
fd=fullfile(out_dir,'factorial_figs');
sd=[sp 'scans_full/']; F=dir([sd 'scan_*.mat']);
if isempty(F), fprintf('no scans_full\n'); return; end
M=load([sp 'landscape_meta.mat'],'N','p'); N=M.N; pg=M.p;
g=5; ceof=@(v) ((1-g)*v).^(1/(1-g));

fprintf('reading %d scans ...\n', numel(F));
age=zeros(numel(F),1); kk=zeros(numel(F),1); zbest=zeros(numel(F),1); fr0=zeros(numel(F),1);
for i=1:numel(F)
    S=load([sd F(i).name]);
    Z=ceof(S.rhs); Z(~isfinite(Z))=0; Z=max(Z,0);
    zbest(i)=max(Z(:));
    fr0(i)=mean(Z(:)<=0.02*max(zbest(i),eps));
    tok=regexp(F(i).name,'scan_t(\d+)_k(\d+)','tokens'); tok=tok{1};
    age(i)=24+str2double(tok{1}); kk(i)=str2double(tok{2});
end

% occupancy
Q=load(fullfile(out_dir,'occupancy_src.mat')); s=Q.s;
lam=s.lambda; sA=s.sA; sH=s.sH;

ages=sort(unique(age)).'; na=numel(ages);
nc=4; nr=ceil(na/nc);
f=figure('Position',[10 10 430*nc 380*nr],'Color','w','Visible','off');
tl=tiledlayout(f,nr,nc,'Padding','compact','TileSpacing','compact');
stat=nan(na,5);
for a=1:na
    m=age==ages(a);
    zb=nan(N); zb(kk(m))=zbest(m);
    zmaxa=max(zb(:),[],'omitnan');
    ruin=zb < 0.05*zmaxa;                       % node-level ruin flag
    % collapse over u3 to an (u1,u2) picture: share of u3 slices ruined
    Rm=mean(ruin,3,'omitnan');

    ax=nexttile(tl); hold(ax,'on');
    imagesc(ax,pg.u2_grid,pg.u1_grid,Rm); axis(ax,'xy'); clim(ax,[0 1]);
    colormap(ax,flipud(bone));
    if mod(a,nc)==0||a==na, cb=colorbar(ax); cb.Label.String='share of u3 slices ruined'; end

    % occupancy contour at this age
    t=ages(a)-24; tt=min(t,size(lam,2));
    x=lam(:,tt); y=(sA(:,tt)+sH(:,tt))./max(1-lam(:,tt),1e-12);
    ok=isfinite(x)&isfinite(y);
    E1=linspace(0,max(pg.u1_grid),41); E2=linspace(min(pg.u2_grid),1,41);
    H=histcounts2(x(ok),y(ok),E1,E2); H=H/max(H(:));
    c1=(E1(1:end-1)+E1(2:end))/2; c2=(E2(1:end-1)+E2(2:end))/2;
    contour(ax,c2,c1,H,[0.05 0.25 0.6],'LineColor',[0.85 0.33 0.10],'LineWidth',1.4);

    % how close is the occupied mass to a ruined node?
    [GU2,GU1]=meshgrid(pg.u2_grid,pg.u1_grid);
    ru1=GU1(Rm>0.5); ru2=GU2(Rm>0.5);
    if isempty(ru1)
        dmin=nan; nearfrac=0;
    else
        xs=x(ok); ys=y(ok);
        sub=1:max(1,round(numel(xs)/4000)):numel(xs);
        dd=hypot((xs(sub)-ru1.')/max(pg.u1_grid), (ys(sub)-ru2.')/1);
        dmin=median(min(dd,[],2));
        nearfrac=mean(min(dd,[],2) < 0.10);      % within a tenth of the axis
    end
    stat(a,:)=[ages(a), 100*mean(ruin(:),'omitnan'), 100*mean(fr0(m)), 100*nearfrac, dmin];
    xlim(ax,[min(pg.u2_grid) 1]); ylim(ax,[0 max(pg.u1_grid)]);
    xlabel(ax,'u2'); ylabel(ax,'u1');
    title(ax,{sprintf('age %d: %.0f%% of nodes ruined',ages(a),100*mean(ruin(:),'omitnan')), ...
              sprintf('%.0f%% of households within 0.1 of one',100*nearfrac)}, ...
              'FontWeight','normal','FontSize',9);
end
sgtitle(f,['Ruined nodes (dark) against where households live (orange contours). A node is ruined when the best attainable value there is under 5% of the best at that age. ' ...
  'Cliffs in the continuation value sit on this boundary.'],'FontWeight','normal','FontSize',11,'Interpreter','tex');
exportgraphics(f,fullfile(fd,'S25_ruin_map.png'),'Resolution',115); close(f);

fprintf('\n%-6s %12s %16s %20s %12s\n','age','nodes ruined','mean ruin in (c,pi)','households within 0.1','median dist');
for a=1:na
    fprintf('%-6d %11.1f%% %15.1f%% %19.1f%% %12.3f\n', stat(a,1), stat(a,2), stat(a,3), stat(a,4), stat(a,5));
end
fprintf('\nS25 written\n');
end
