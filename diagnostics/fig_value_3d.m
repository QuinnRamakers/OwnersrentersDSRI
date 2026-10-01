function fig_value_3d(src, out_dir)
%FIG_VALUE_3D  The value function as a surface, the way S7 shows the objective.
%
%   Plots z = ((1-gamma) V)^(1/(1-gamma)), the certainty equivalent per unit of
%   wealth, over (u1, u2) at mid u3, as relief rather than colour. z is in
%   consumption units, so the height is readable directly: it is what the
%   household's remaining lifetime is worth per unit of wealth at that state.
%
%   src can be either
%     'levers'  a stored solve with a full V (owner, 18x14x10, gh_n = 5)
%     'grid'    value_by_grid.mat, once the resolution ladder has entries,
%               in which case one panel is drawn per cube size
%
%   Occupancy contours are overlaid where available, so the part of the surface
%   households actually reach is marked off from the part they never see.

if nargin<1||isempty(src), src='levers'; end
if nargin<2||isempty(out_dir), out_dir=fileparts(mfilename('fullpath')); end
fd=fullfile(out_dir,'factorial_figs');

switch src
    case 'levers'
        L=load(fullfile(out_dir,'case_owner_levers.mat'),'R');
        p=L.R(1).p; V=L.R(1).sol.V; g=p.gamma;
        u1=p.u1_grid(:); u2=p.u2_grid(:); i3=round(p.N_u3/2);
        ts=[1 10 30 50 70]; ttl='owner base, 18x14x10, gh\_n = 5';
        Z=cell(1,numel(ts));
        for a=1:numel(ts)
            Z{a}=((1-g)*squeeze(V(:,:,i3,ts(a)))).^(1/(1-g));
        end
        names=arrayfun(@(t) sprintf('age %d',24+t), ts, 'uni',0);
    case 'grid'
        L=load(fullfile(out_dir,'value_by_grid.mat')); R=L.R;
        [~,o]=sort([R.n]); R=R(o);
        ai=3;                                   % age 54
        ts=R(1).t; u1=[]; u2=[];
        Z=cell(1,numel(R)); names=cell(1,numel(R));
        for i=1:numel(R)
            Z{i}=R(i).z{ai}; names{i}=sprintf('%s = %d nodes',mat2str(R(i).dim),R(i).n);
        end
        u1=R(end).u1; u2=R(end).u2;
        ttl=sprintf('age %d, by cube size',24+ts(ai));
    otherwise
        error('src must be levers or grid');
end

% occupancy, for contours
occ=[];
osrc=fullfile(out_dir,'occupancy_src.mat');
if isfile(osrc)
    Q=load(osrc); s=Q.s;
    lam=s.lambda; sA=s.sA; sH=s.sH;
    x=lam(:); y=reshape((sA+sH)./max(1-lam,1e-12),[],1);
    ok=isfinite(x)&isfinite(y);
    E1=linspace(0,1,81); E2=linspace(0,1,81);
    occ.H=histcounts2(min(max(x(ok),0),1),min(max(y(ok),0),1),E1,E2);
    occ.c1=(E1(1:end-1)+E1(2:end))/2; occ.c2=(E2(1:end-1)+E2(2:end))/2;
    occ.H=occ.H/max(occ.H(:));
end

n=numel(Z); nc=min(n,3); nr=ceil(n/nc);
f=figure('Position',[10 10 560*nc 460*nr],'Color','w','Visible','off');
tl=tiledlayout(f,nr,nc,'Padding','compact','TileSpacing','compact');
lo=inf; hi=-inf;
for i=1:n
    v=Z{i}(isfinite(Z{i})); lo=min(lo,prctile(v,1)); hi=max(hi,max(v));
end
for i=1:n
    if strcmp(src,'grid'), g1=interp_to(Z{i},L.R,i,u1,u2); else, g1=Z{i}; end
    ax=nexttile(tl); hold(ax,'on');
    surf(ax,u2,u1,max(g1,lo),'EdgeColor','none','FaceColor','interp','FaceAlpha',.95);
    colormap(ax,parula); clim(ax,[lo hi]);
    if mod(i,nc)==0 || i==n, cb=colorbar(ax); cb.Label.String='z  (CE per unit wealth)'; end
    if ~isempty(occ)
        Hc=interp2(occ.c2,occ.c1,occ.H,u2(:).',u1(:),'linear',0);
        contour3(ax,u2,u1,max(hi,max(g1(:)))*ones(size(Hc)).*(Hc>0)+hi*0.999, ...
            [0.5 0.5],'LineColor','none');   % placeholder, real contour below
        contour3(ax,u2,u1,max(g1,lo)+0.01*(hi-lo),[0 0],'LineColor','none');
        [~,hC]=contour(ax,u2,u1,Hc,[0.02 0.10 0.35],'LineColor',[1 1 1],'LineWidth',1.3);
        hC.ContourZLevel=hi;
    end
    view(ax,-40,38); grid(ax,'on');
    xlabel(ax,'u2  (illiquid share)'); ylabel(ax,'u1  (income share)');
    zlabel(ax,'z'); zlim(ax,[lo hi*1.02]);
    title(ax,names{i},'FontWeight','normal');
end
sgtitle(f,sprintf(['Value function as relief: z = ((1-\\gamma)V)^{1/(1-\\gamma)}, the certainty equivalent per unit of wealth. %s. ' ...
    'White contours mark where households actually live.'], ttl), ...
    'FontWeight','normal','FontSize',11,'Interpreter','tex');
nm='S22_value_3d.png'; if strcmp(src,'grid'), nm='S23_value_3d_by_grid.png'; end
exportgraphics(f,fullfile(fd,nm),'Resolution',120); close(f);
fprintf('%s written\n', nm);
end

% ------------------------------------------------------------------------
function Zi = interp_to(Z, R, i, u1, u2)
[G1,G2]=ndgrid(u1,u2);
Zi=interpn(R(i).u1,R(i).u2,Z,G1,G2,'linear',NaN);
end
