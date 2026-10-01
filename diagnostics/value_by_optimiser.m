function value_by_optimiser(out_dir)
%VALUE_BY_OPTIMISER  What each search routine and each fmincon algorithm does
%   to the value function, the policy and the simulated path.
%
%   Seven arms on one cube (16x16x10, gh_n = 5), everything else identical:
%
%     1  no sweep, active-set        what shipped
%     2  no sweep, sqp
%     3  no sweep, interior-point
%     4  no sweep, pi multistart     five fmincon starts spread over pi
%     5  sweep pi after              the shipped refinement
%     6  sweep pi and c first        the corrected setting
%     7  sweep c first               consumption only, swept first
%
%   Arms 2 to 4 vary the local method; arms 5 to 7 vary whether and when a
%   global sweep happens. Value functions are reported as the certainty
%   equivalent z, which is comparable across arms here because the cube is held
%   fixed -- unlike the cross-resolution comparison, where the grid is part of
%   the approximation.
%
%   Resumable: each solve saved as it finishes.

if nargin<1||isempty(out_dir), out_dir=fileparts(mfilename('fullpath')); end
res=fullfile(out_dir,'value_by_optimiser.mat');
DIM=[12 12 8];
TS =[1 10 30 50 70];
PTS=[0.139 0.655 0.33
     0.078 0.737 0.33
     0.020 0.912 0.33
     0.300 0.600 0.33];

%      name                       refine stage  piG cG  algo             multistart
ARMS={ 'no sweep, active-set',        0,'post',1,0,'active-set',    []
       'no sweep, sqp',               0,'post',1,0,'sqp',           []
       'no sweep, interior-point',    0,'post',1,0,'interior-point',[]
       'no sweep, pi multistart',     0,'post',1,0,'active-set',    [0;.25;.5;.75;1]
       'sweep pi after',              1,'post',1,0,'active-set',    []
       'sweep pi and c first',        1,'pre', 1,1,'active-set',    []
       'sweep c first',               1,'pre', 0,1,'active-set',    [] };

R=struct('arm',{},'sec',{},'u1',{},'u2',{},'u3_at',{},'t',{},'z',{},'zpt',{},'pi',{},'sim',{});
if isfile(res), L=load(res); R=L.R; end
for j=1:size(ARMS,1)
    if any(strcmp(ARMS{j,1},{R.arm})), continue; end
    fprintf('[%s] %s ...\n', datestr(now,'HH:MM:SS'), ARMS{j,1});
    try
        tic; o=run_one(DIM, ARMS(j,:), TS, PTS); sec=toc;
        R(end+1).arm=ARMS{j,1}; R(end).sec=sec;                           %#ok<AGROW>
        R(end).u1=o.u1; R(end).u2=o.u2; R(end).u3_at=o.u3_at; R(end).t=TS;
        R(end).z=o.z; R(end).zpt=o.zpt; R(end).pi=o.pi; R(end).sim=o.sim;
        save(res,'R','-v7.3');
        fprintf('   %.0f s | pi@80=%.3f\n', sec, o.sim.pi_liq(o.sim.ages==80));
    catch ME
        fprintf('   FAILED: %s\n', ME.message);
    end
end
make_figs(R, TS, PTS, DIM, out_dir);
end

% ------------------------------------------------------------------------
function o = run_one(dim, arm, ts, pts)
p=config.params(); p.is_owner=false;
p.grid_mode='none'; p.polish_ver=2;
p.use_refine=arm{2}; p.refine_stage=arm{3};
p.refine_pi_global=arm{4}; p.refine_c_global=arm{5};
p.polish_algo=arm{6};
if ~isempty(arm{7}), p.pi_starts=arm{7}; end
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
o.z=cell(1,numel(ts)); o.pi=cell(1,numel(ts));
for a=1:numel(ts)
    o.z{a} =ceof(squeeze(sol.V(:,:,i3,ts(a))));
    o.pi{a}=squeeze(sol.pi_pol(:,:,i3,ts(a)));
end
o.zpt=nan(size(pts,1),numel(ts));
for q=1:size(pts,1)
    [~,j3]=min(abs(p.u3_grid-pts(q,3)));
    for a=1:numel(ts)
        Z=ceof(squeeze(sol.V(:,:,j3,ts(a))));
        o.zpt(q,a)=interpn(p.u1_grid,p.u2_grid,Z,pts(q,1),pts(q,2),'linear');
    end
end
s=simulate.forward(p,pf,sol,an,6000,20260511,p.b0);
o.sim=h1_summary(p,s);
end

% ------------------------------------------------------------------------
function make_figs(R, ts, pts, dim, out_dir)
if isempty(R), return; end
fd=fullfile(out_dir,'factorial_figs'); n=numel(R);
u1c=linspace(R(1).u1(1),R(1).u1(end),80);
u2c=linspace(R(1).u2(1),R(1).u2(end),80);
[G1,G2]=ndgrid(u1c,u2c);
ages=[10 30 50];                                 % 34, 54, 74

% ---- 1: z surfaces, ages down, arms across
f=figure('Position',[10 10 300*n+140 320*numel(ages)],'Color','w','Visible','off');
tl=tiledlayout(f,numel(ages),n,'Padding','compact','TileSpacing','compact');
for a=1:numel(ages)
    ai=find(ts==ages(a),1); Z=cell(1,n); lo=inf; hi=-inf;
    for i=1:n
        Z{i}=interpn(R(i).u1,R(i).u2,R(i).z{ai},G1,G2,'linear',NaN);
        lo=min(lo,min(Z{i}(:))); hi=max(hi,max(Z{i}(:)));
    end
    for i=1:n
        ax=nexttile(tl); imagesc(ax,u2c,u1c,Z{i}); axis(ax,'xy');
        clim(ax,[lo hi]); colormap(ax,parula);
        if i==n, cb=colorbar(ax); cb.Label.String='z'; end
        xlabel(ax,'u2'); ylabel(ax,'u1');
        title(ax,sprintf('age %d\n%s',24+ages(a),R(i).arm),'FontWeight','normal','FontSize',8.5);
    end
end
sgtitle(f,sprintf(['Value function z by search routine, cube fixed at %s, gh\\_n = 5. Rows share a colour scale, ' ...
  'so a visible difference between columns is the routine, not the scaling.'],mat2str(dim)), ...
  'FontWeight','normal','FontSize',11,'Interpreter','tex');
exportgraphics(f,fullfile(fd,'S20_value_by_optimiser.png'),'Resolution',110); close(f);

% ---- 2: detail -- z slice, policy slice, simulated path, z at points
cols=lines(n);
f=figure('Position',[10 10 1640 900],'Color','w','Visible','off');
tl=tiledlayout(f,2,2,'Padding','compact','TileSpacing','compact');
ai=find(ts==30,1);                                % age 54
ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12; h=gobjects(0);
for i=1:n
    zz=interpn(R(i).u1,R(i).u2,R(i).z{ai},u1c,repmat(0.74,size(u1c)),'linear',NaN);
    h(i)=plot(ax,u1c,zz,'Color',cols(i,:),'LineWidth',1.8);
end
set(ax,'XScale','log'); xlabel(ax,'u1 (log)'); ylabel(ax,'z');
title(ax,'value function at age 54, u2 = 0.74','FontWeight','normal');

ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
for i=1:n
    pp=interpn(R(i).u1,R(i).u2,R(i).pi{ai},u1c,repmat(0.74,size(u1c)),'linear',NaN);
    plot(ax,u1c,100*pp,'Color',cols(i,:),'LineWidth',1.8);
end
set(ax,'XScale','log'); xlabel(ax,'u1 (log)'); ylabel(ax,'% in equity');
title(ax,'equity policy at the same slice','FontWeight','normal');

ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
for i=1:n
    plot(ax,R(i).sim.ages,100*R(i).sim.pi_liq,'Color',cols(i,:),'LineWidth',1.8);
end
xline(ax,67,'-','Color',[.4 .4 .4]); xlim(ax,[25 95]); ylim(ax,[0 100]);
xlabel(ax,'age'); ylabel(ax,'% in equity');
title(ax,'simulated equity share','FontWeight','normal');

ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
best=max(cell2mat(arrayfun(@(r) r.zpt(:,ai).', R,'uni',0).'),[],1);
Y=zeros(n,size(pts,1));
for i=1:n, Y(i,:)=100*(R(i).zpt(:,ai).'./best-1); end
b=bar(ax,Y.','grouped','EdgeColor',[.3 .3 .3]);
for i=1:n, b(i).FaceColor=cols(i,:); end
set(ax,'XTick',1:size(pts,1),'XTickLabel',compose('u1=%.3f',pts(:,1)));
ylabel(ax,'% below the best arm at that state');
title(ax,'value at tracked states, age 54','FontWeight','normal');
lg=legend(h,{R.arm},'Box','off','FontSize',8.5,'NumColumns',4); lg.Layout.Tile='south';
sgtitle(f,sprintf('Search routine: value, policy and simulated outcome. Cube %s, gh\\_n = 5, identical households.',mat2str(dim)), ...
  'FontWeight','normal','FontSize',11,'Interpreter','tex');
exportgraphics(f,fullfile(fd,'S21_optimiser_detail.png'),'Resolution',130); close(f);

fprintf('\n=== by search routine (cube %s, gh_n=5) ===\n', mat2str(dim));
fprintf('%-28s %7s %8s %8s %8s', 'routine','sec','pi@34','pi@54','pi@80');
fprintf('   z at tracked states, age 54 (%% below best)\n');
for i=1:n
    fprintf('%-28s %7.0f %8.3f %8.3f %8.3f', R(i).arm, R(i).sec, ...
        R(i).sim.pi_liq(R(i).sim.ages==34), R(i).sim.pi_liq(R(i).sim.ages==54), ...
        R(i).sim.pi_liq(R(i).sim.ages==80));
    fprintf('   %+7.3f', 100*(R(i).zpt(:,ai).'./best-1)); fprintf('\n');
end
fprintf('\nfigures in %s\n', fd);
end
