function value_by_grid(out_dir)
%VALUE_BY_GRID  The value function across cube resolutions, ages and states.
%
%   V is reported as its certainty-equivalent transform
%
%       z = ((1-gamma) V)^(1/(1-gamma))
%
%   which is the value per unit of wealth in consumption units, so it is on a
%   sane scale and the surfaces from different cubes can be laid on one axis.
%
%   A caution that belongs with every number here: z at a given state is the
%   same object across resolutions, so comparing it is meaningful as a
%   NUMERICAL statement about the solve. It is not a welfare comparison between
%   models -- the grid is part of the approximation, not part of the economy, so
%   a gap between two resolutions measures solution error, not a preference.
%
%   Five cube sizes, five ages, and a handful of named states tracked
%   individually so convergence can be read point by point.
%
%   Resumable: each solve saved as it finishes.

if nargin<1||isempty(out_dir), out_dir=fileparts(mfilename('fullpath')); end
res=fullfile(out_dir,'value_by_grid.mat');
DIMS={[8 8 6],[12 12 8],[16 16 10],[20 20 12]};
TS  =[1 10 30 50 70];                    % ages 25, 34, 54, 74, 94
% states to track individually: (u1,u2,u3). The first three sit where
% households actually are at 34/54/74; the last two are deliberately outside.
PTS =[0.139 0.655 0.33
      0.078 0.737 0.33
      0.020 0.912 0.33
      0.300 0.600 0.33
      0.050 0.980 0.33];

R=struct('dim',{},'n',{},'sec',{},'u1',{},'u2',{},'u3_at',{},'t',{},'z',{},'zpt',{});
if isfile(res), L=load(res); R=L.R; end
for i=1:numel(DIMS)
    if any(arrayfun(@(r) isequal(r.dim,DIMS{i}), R)), continue; end
    fprintf('[%s] solving %s ...\n', datestr(now,'HH:MM:SS'), mat2str(DIMS{i}));
    try
        tic; o=run_one(DIMS{i}, TS, PTS); sec=toc;
        R(end+1).dim=DIMS{i}; R(end).n=prod(DIMS{i}); R(end).sec=sec;     %#ok<AGROW>
        R(end).u1=o.u1; R(end).u2=o.u2; R(end).u3_at=o.u3_at;
        R(end).t=TS; R(end).z=o.z; R(end).zpt=o.zpt;
        save(res,'R','-v7.3'); fprintf('   %.0f s\n', sec);
    catch ME
        fprintf('   FAILED: %s\n', ME.message);
    end
end
make_figs(R, TS, PTS, out_dir);
end

% ------------------------------------------------------------------------
function o = run_one(dim, ts, pts)
p=config.params(); p.is_owner=false;
p.grid_mode='none'; p.polish_ver=2; p.polish_algo='active-set';
p.use_refine=true; p.refine_stage='pre';
p.refine_pi_global=true; p.refine_c_global=true;
p.lambda_lo=0.0008; p.lambda_hi=0.44; p.grid_pow=1.6;
p.u2_lo=0.40; p.grid_pow_u2=1; p.u3_lo=0.02; p.u3_hi=0.98;
p=utility.build_state_grids(p,dim,5);
[~,mg,sl]=config.income_profile(p);
pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(p);
shk=grids.shock_grid(p); an=pension.annuity_price(p,pf,shk);
sol=solver.solve_lifecycle_lna(p,pf,shk,an);

g=p.gamma; ceof=@(v) ((1-g)*v).^(1/(1-g));
i3=round(p.N_u3/2);
o.u1=p.u1_grid(:); o.u2=p.u2_grid(:); o.u3_at=p.u3_grid(i3);
o.z=cell(1,numel(ts));
for a=1:numel(ts)
    o.z{a}=ceof(squeeze(sol.V(:,:,i3,ts(a))));
end
% named states, interpolated off the cube so the grid's own node placement
% does not decide which point is reported
o.zpt=nan(size(pts,1),numel(ts));
for q=1:size(pts,1)
    [~,j3]=min(abs(p.u3_grid-pts(q,3)));
    for a=1:numel(ts)
        Z=ceof(squeeze(sol.V(:,:,j3,ts(a))));
        o.zpt(q,a)=interpn(p.u1_grid,p.u2_grid,Z,pts(q,1),pts(q,2),'linear');
    end
end
end

% ------------------------------------------------------------------------
function make_figs(R, ts, pts, out_dir)
if isempty(R), fprintf('nothing solved\n'); return; end
[~,ord]=sort([R.n]); R=R(ord);
fd=fullfile(out_dir,'factorial_figs');
ref=R(end);
u1c=linspace(ref.u1(1),ref.u1(end),80);
u2c=linspace(ref.u2(1),ref.u2(end),80);
[G1,G2]=ndgrid(u1c,u2c);
cols=parula(max(numel(R),2));

% ---- 1: surfaces, ages down, cubes across
f=figure('Position',[10 10 360*numel(R)+140 320*numel(ts)],'Color','w','Visible','off');
tl=tiledlayout(f,numel(ts),numel(R),'Padding','compact','TileSpacing','compact');
for a=1:numel(ts)
    Z=cell(1,numel(R)); lo=inf; hi=-inf;
    for i=1:numel(R)
        Z{i}=interpn(R(i).u1,R(i).u2,R(i).z{a},G1,G2,'linear',NaN);
        lo=min(lo,min(Z{i}(:))); hi=max(hi,max(Z{i}(:)));
    end
    for i=1:numel(R)
        ax=nexttile(tl); imagesc(ax,u2c,u1c,Z{i}); axis(ax,'xy');
        clim(ax,[lo hi]); colormap(ax,parula);
        if i==numel(R), cb=colorbar(ax); cb.Label.String='z'; end
        xlabel(ax,'u2'); ylabel(ax,'u1');
        title(ax,sprintf('age %d, %s',24+ts(a),mat2str(R(i).dim)),'FontWeight','normal');
    end
end
sgtitle(f,['Value function as its certainty equivalent z, over (u1,u2) at mid u3. Rows are ages, columns refine the cube; ' ...
  'each row shares one colour scale. Differences between columns are solution error, not welfare.'], ...
  'FontWeight','normal','FontSize',11,'Interpreter','tex');
exportgraphics(f,fullfile(fd,'S17_value_surfaces.png'),'Resolution',110); close(f);

% ---- 2: slices along u1 at three u2 levels, overlaying cubes
u2sel=[0.65 0.80 0.95];
f=figure('Position',[10 10 520*numel(u2sel) 300*numel(ts)],'Color','w','Visible','off');
tl=tiledlayout(f,numel(ts),numel(u2sel),'Padding','compact','TileSpacing','compact');
h=gobjects(0); nm={};
for a=1:numel(ts)
    for q=1:numel(u2sel)
        ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
        for i=1:numel(R)
            zz=interpn(R(i).u1,R(i).u2,R(i).z{a},u1c,repmat(u2sel(q),size(u1c)),'linear',NaN);
            hh=plot(ax,u1c,zz,'Color',cols(i,:),'LineWidth',1.3+0.9*(i==numel(R)));
            if a==1 && q==1, h(end+1)=hh; nm{end+1}=sprintf('%s = %d',mat2str(R(i).dim),R(i).n); end %#ok<AGROW>
        end
        set(ax,'XScale','log'); xlim(ax,[max(u1c(1),1e-3) u1c(end)]);
        xlabel(ax,'u1  (income share, log)'); ylabel(ax,'z');
        title(ax,sprintf('age %d, u2 = %.2f',24+ts(a),u2sel(q)),'FontWeight','normal');
    end
end
lg=legend(h,nm,'Box','off','FontSize',9,'NumColumns',5); lg.Layout.Tile='south';
sgtitle(f,'Value function sliced along the income share, at three levels of the illiquid share', ...
    'FontWeight','normal','FontSize',11,'Interpreter','tex');
exportgraphics(f,fullfile(fd,'S18_value_slices.png'),'Resolution',110); close(f);

% ---- 3: named points, z against node count
lab={'occupied @34','occupied @54','occupied @74','sparse corner','high-illiquid edge'};
f=figure('Position',[10 10 1540 760],'Color','w','Visible','off');
tl=tiledlayout(f,2,3,'Padding','compact','TileSpacing','compact');
for q=1:size(pts,1)
    ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    for a=1:numel(ts)
        y=arrayfun(@(r) r.zpt(q,a), R);
        plot(ax,[R.n],y,'-o','LineWidth',1.6,'MarkerFaceColor','auto', ...
            'DisplayName',sprintf('age %d',24+ts(a)));
    end
    set(ax,'XScale','log'); xlabel(ax,'cube nodes'); ylabel(ax,'z');
    title(ax,sprintf('%s  (u1=%.3f, u2=%.2f)',lab{q},pts(q,1),pts(q,2)),'FontWeight','normal');
    if q==1, legend(ax,'Box','off','Location','best','FontSize',8); end
end
ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
for q=1:size(pts,1)
    y=arrayfun(@(r) r.zpt(q,3), R);              % age 54
    plot(ax,[R.n],100*(y/y(end)-1),'-o','LineWidth',1.8,'DisplayName',lab{q});
end
yline(ax,0,'-','Color',[.5 .5 .5]); set(ax,'XScale','log');
xlabel(ax,'cube nodes'); ylabel(ax,'% from the finest cube');
title(ax,'convergence at age 54, by state','FontWeight','normal');
legend(ax,'Box','off','Location','best','FontSize',8);
sgtitle(f,['Value function at fixed states as the cube is refined. The first three states are where households actually sit at 34, 54 and 74; ' ...
  'the last two are chosen in sparsely visited regions.'],'FontWeight','normal','FontSize',11,'Interpreter','tex');
exportgraphics(f,fullfile(fd,'S19_value_points.png'),'Resolution',130); close(f);

% ---- numbers
fprintf('\n=== z at tracked states, by cube ===\n');
for q=1:size(pts,1)
    fprintf('\n%s  (u1=%.3f u2=%.2f)\n', lab{q}, pts(q,1), pts(q,2));
    fprintf('%-14s %7s', 'cube','nodes'); fprintf('%12s', "age"+string(24+ts)); fprintf('\n');
    for i=1:numel(R)
        fprintf('%-14s %7d', mat2str(R(i).dim), R(i).n);
        fprintf('%12.4f', R(i).zpt(q,:)); fprintf('\n');
    end
    fprintf('%-14s %7s', 'vs finest %','');
    fprintf('%11.2f%%', 100*(R(1).zpt(q,:)./R(end).zpt(q,:)-1)); fprintf('   (coarsest)\n');
end
fprintf('\nfigures in %s\n', fd);
end
