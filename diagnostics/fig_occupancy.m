function fig_occupancy(out_dir)
%FIG_OCCUPANCY  Where households actually are, against where the grid is.
%
%   A resolution problem only matters where households live. This lays the
%   simulated occupancy of the cube over the grid nodes and over the policy
%   surface, and asks how much of the policy movement between resolutions
%   happens in the occupied region rather than in empty corners.
%
%   Reads grid_convergence.mat.

if nargin<1||isempty(out_dir), out_dir=fileparts(mfilename('fullpath')); end
res=fullfile(out_dir,'grid_convergence.mat');
if ~isfile(res), fprintf('grid_convergence.mat not there yet\n'); return; end
L=load(res); R=L.R;
m5=find([R.gh]==5); [~,o5]=sort([R(m5).n]); m5=m5(o5);
if isempty(m5), fprintf('no gh_n=5 solves\n'); return; end
fd=fullfile(out_dir,'factorial_figs');
ref=R(m5(end)); ts=ref.pol.t;

% The first overnight run computed occupancy but did not store it. Rebuild it
% from a saved full simulation when the field is missing, so the figure does
% not need the whole ladder re-solved.
if ~isfield(ref,'occ') || isempty(ref.occ)
    src = fullfile(out_dir,'occupancy_src.mat');
    if ~isfile(src)
        fprintf('no occupancy stored and no %s to rebuild from\n', src); return;
    end
    Q = load(src);
    ref.occ = build_occ(Q.s, Q.p, ts);
    fprintf('occupancy rebuilt from %s (%s)\n', src, Q.note);
end

% common grid for policy comparison
u1c=linspace(ref.pol.u1(1),ref.pol.u1(end),60);
u2c=linspace(ref.pol.u2(1),ref.pol.u2(end),60);
[G1,G2]=ndgrid(u1c,u2c);

f=figure('Position',[10 10 1620 420*numel(ts)],'Color','w','Visible','off');
tl=tiledlayout(f,numel(ts),3,'Padding','compact','TileSpacing','compact');
for a=1:numel(ts)
    O=ref.occ; H=O.H{a}; H=H/max(sum(H(:)),1);
    c1=(O.e1(1:end-1)+O.e1(2:end))/2; c2=(O.e2(1:end-1)+O.e2(2:end))/2;

    % 1: occupancy with the grid nodes on top
    ax=nexttile(tl); hold(ax,'on');
    imagesc(ax,c2,c1,H); axis(ax,'xy'); colormap(ax,flipud(gray));
    clim(ax,[0 max(H(:))*0.6]);
    [N1,N2]=ndgrid(ref.pol.u1,ref.pol.u2);
    plot(ax,N2(:),N1(:),'.','Color',[0.85 0.33 0.10],'MarkerSize',7);
    xlim(ax,[0 1]); ylim(ax,[0 min(1,max(ref.pol.u1)*1.2)]);
    xlabel(ax,'u2  (illiquid share)'); ylabel(ax,'u1  (income share)');
    title(ax,sprintf('age %d: households (dark) and grid nodes (orange)',24+ts(a)), ...
        'FontWeight','normal');

    % 2: the policy there
    P=interpn(ref.pol.u1,ref.pol.u2,ref.pol.pi{a},G1,G2,'linear',NaN);
    ax=nexttile(tl); hold(ax,'on');
    imagesc(ax,u2c,u1c,P); axis(ax,'xy'); colormap(ax,parula); clim(ax,[0 1]);
    cb=colorbar(ax); cb.Label.String='\pi';
    Hc=interpn(c1,c2,H,G1,G2,'linear',0);
    contour(ax,u2c,u1c,Hc,[max(Hc(:))*0.05 max(Hc(:))*0.25 max(Hc(:))*0.6], ...
        'LineColor',[1 1 1],'LineWidth',1.2);
    xlabel(ax,'u2'); ylabel(ax,'u1');
    title(ax,'equity share, with occupancy contours','FontWeight','normal');

    % 3: how much the policy moves between resolutions, weighted by occupancy
    ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    nn=zeros(1,numel(m5)); raw=nn; wtd=nn;
    for i=1:numel(m5)
        A=interpn(R(m5(i)).pol.u1,R(m5(i)).pol.u2,R(m5(i)).pol.pi{a},G1,G2,'linear',NaN);
        B=interpn(ref.pol.u1,ref.pol.u2,ref.pol.pi{a},G1,G2,'linear',NaN);
        d=abs(A-B); ok=isfinite(d);
        w=Hc; w(~ok)=0; if sum(w(:))==0, w(ok)=1; end
        nn(i)=R(m5(i)).n; raw(i)=sqrt(mean(d(ok).^2));
        wtd(i)=sqrt(sum(w(ok).*d(ok).^2)/max(sum(w(ok)),eps));
    end
    plot(ax,nn,raw,'-o','Color',[.55 .55 .55],'LineWidth',1.6,'MarkerFaceColor',[.55 .55 .55]);
    plot(ax,nn,wtd,'-o','Color',[.85 .33 .10],'LineWidth',2.2,'MarkerFaceColor',[.85 .33 .10]);
    set(ax,'XScale','log'); xlabel(ax,'cube nodes'); ylabel(ax,'RMS |\Delta\pi| vs finest');
    title(ax,'policy movement: whole cube vs where people are','FontWeight','normal');
    if a==1, legend(ax,{'over the whole cube','weighted by occupancy'},'Box','off', ...
            'Location','northeast','FontSize',8); end
end
sgtitle(f,['Where households live on the cube, and whether the resolution problem is there or in empty corners. ' ...
  'Occupancy from the finest solve; the right column recomputes the policy deviation weighting every node by how often it is visited.'], ...
  'FontWeight','normal','FontSize',11,'Interpreter','tex');
exportgraphics(f,fullfile(fd,'S15_occupancy.png'),'Resolution',120); close(f);

fprintf('\n=== occupancy of the cube (finest solve) ===\n');
fprintf('%-6s %28s %28s %10s\n','age','u1  p1/p25/p50/p75/p99','u2  p1/p25/p50/p75/p99','off-grid');
for a=1:numel(ts)
    O=ref.occ;
    fprintf('%-6d  %5.3f %5.3f %5.3f %5.3f %5.3f   %5.3f %5.3f %5.3f %5.3f %5.3f  %8.2f%%\n', ...
        24+ts(a), O.u1_q(a,:), O.u2_q(a,:), 100*O.off(a));
end
fprintf('\n=== policy movement vs finest: whole cube against occupied region ===\n');
fprintf('%-6s %-14s %14s %14s\n','age','cube','RMS dpi all','RMS dpi occupied');
for a=1:numel(ts)
    O=ref.occ; H=O.H{a}; H=H/max(sum(H(:)),1);
    c1=(O.e1(1:end-1)+O.e1(2:end))/2; c2=(O.e2(1:end-1)+O.e2(2:end))/2;
    Hc=interpn(c1,c2,H,G1,G2,'linear',0);
    for i=1:numel(m5)
        A=interpn(R(m5(i)).pol.u1,R(m5(i)).pol.u2,R(m5(i)).pol.pi{a},G1,G2,'linear',NaN);
        B=interpn(ref.pol.u1,ref.pol.u2,ref.pol.pi{a},G1,G2,'linear',NaN);
        d=abs(A-B); ok=isfinite(d); w=Hc; w(~ok)=0;
        fprintf('%-6d %-14s %14.4f %14.4f\n', 24+ts(a), mat2str(R(m5(i)).dim), ...
            sqrt(mean(d(ok).^2)), sqrt(sum(w(ok).*d(ok).^2)/max(sum(w(ok)),eps)));
    end
end
fprintf('figure in %s\n', fd);
end

% ------------------------------------------------------------------------
function occ = build_occ(s, p, ts)
%BUILD_OCC  Occupancy histogram from a stored simulation.
E1=linspace(0,1,61); E2=linspace(0,1,61);
occ.e1=E1; occ.e2=E2; occ.t=ts;
lam=s.lambda; sA=s.sA; sH=s.sH;
u1=lam; u2=(sA+sH)./max(1-lam,1e-12); u3=sA./max(sA+sH,1e-12);
occ.u1_q=nan(numel(ts),5); occ.u2_q=nan(numel(ts),5); occ.u3_q=nan(numel(ts),5);
occ.H=cell(1,numel(ts)); occ.off=nan(1,numel(ts));
for a=1:numel(ts)
    tt=min(ts(a), size(u1,2));
    x=u1(:,tt); y=u2(:,tt); z=u3(:,tt);
    ok=isfinite(x)&isfinite(y);
    occ.H{a}=histcounts2(min(max(x(ok),0),1), min(max(y(ok),0),1), E1, E2);
    occ.u1_q(a,:)=prctile(x(ok),[1 25 50 75 99]);
    occ.u2_q(a,:)=prctile(y(ok),[1 25 50 75 99]);
    occ.u3_q(a,:)=prctile(z(isfinite(z)),[1 25 50 75 99]);
    occ.off(a)=mean(x(ok)<p.u1_grid(1) | x(ok)>p.u1_grid(end) | ...
                    y(ok)<p.u2_grid(1) | y(ok)>p.u2_grid(end));
end
end
