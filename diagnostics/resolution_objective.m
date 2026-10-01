function resolution_objective(out_dir)
%RESOLUTION_OBJECTIVE  Does the cube resolution create the structure, or reveal it?
%
%   The cliffs and basins in the per-node objective come through a continuation
%   value interpolated on the cube, so the obvious worry is that they are an
%   artefact of how coarse that cube is. This solves the same model at four
%   resolutions with everything else held fixed, scans the objective at the same
%   physical state (u1, u2, u3) in each, and overlays the profiles.
%
%   If the steps are interpolation, they should move and soften as the cube is
%   refined. If they are the model, they should stay put and sharpen.
%
%   gh_n is held at 3 throughout so the only thing changing is the grid.

if nargin<1||isempty(out_dir), out_dir = fileparts(mfilename('fullpath')); end
res = fullfile(out_dir,'resolution_objective.mat');
dims = {[8 8 6],[12 12 8],[16 16 10],[20 20 12]};
TGT  = [0.20 0.75 0.33];           % the state the solver logs at each step
TS   = [10 50];                    % ages 34 and 74

R = struct('dim',{},'n',{},'sec',{},'scan',{});
if isfile(res), L=load(res); R=L.R; end
for i=1:numel(dims)
    if any(cellfun(@(d) isequal(d,dims{i}), {R.dim})), continue; end
    fprintf('solving %s ...\n', mat2str(dims{i}));
    tic; sc = run_one(dims{i}, TGT, TS, out_dir); sec=toc;
    R(end+1).dim=dims{i}; R(end).n=prod(dims{i}); R(end).sec=sec; R(end).scan=sc; %#ok<AGROW>
    save(res,'R','-v7.3');
    fprintf('   %.0f s\n', sec);
end
make_fig(R, TGT, TS, out_dir);
end

% ------------------------------------------------------------------------
function sc = run_one(dim, tgt, ts, out_dir)
p = config.params(); p.is_owner=false;
p.grid_mode='none'; p.polish_ver=2; p.use_refine=0; p.polish_algo='active-set';
p.lambda_lo=0.0008; p.lambda_hi=0.44; p.grid_pow=1.6;
p.u2_lo=0.40; p.grid_pow_u2=1; p.u3_lo=0.02; p.u3_hi=0.98;
p = utility.build_state_grids(p, dim, 3);
N = [p.N_u1 p.N_u2 p.N_u3];
[~,i1]=min(abs(p.u1_grid-tgt(1)));
[~,i2]=min(abs(p.u2_grid-tgt(2)));
[~,i3]=min(abs(p.u3_grid-tgt(3)));
k = sub2ind(N, i1, i2, i3);
sd = fullfile(out_dir, sprintf('scan_res_%d', prod(dim)));
if isfolder(sd), rmdir(sd,'s'); end
mkdir(sd);
p.scan = struct('t', ts, 'nodes', k, 'c_n', 121, 'pi_n', 121, 'dir', sd);
[~,mg,sl]=config.income_profile(p);
pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(p);
shk=grids.shock_grid(p); an=pension.annuity_price(p,pf,shk);
solver.solve_lifecycle_lna(p,pf,shk,an);
sc = struct('t',{},'S',{},'u',{});
F = dir(fullfile(sd,'scan_*.mat'));
for j=1:numel(F)
    tok=regexp(F(j).name,'scan_t(\d+)','tokens');
    sc(end+1).t = str2double(tok{1}{1});                                  %#ok<AGROW>
    sc(end).S = load(fullfile(sd,F(j).name));
    sc(end).u = [p.u1_grid(i1) p.u2_grid(i2) p.u3_grid(i3)];
end
end

% ------------------------------------------------------------------------
function make_fig(R, tgt, ts, out_dir)
g=5; ceof=@(v)((1-g)*v).^(1/(1-g));
col = [0.85 0.45 0.15; 0.55 0.30 0.65; 0.20 0.55 0.75; 0.10 0.10 0.10];
f=figure('Position',[20 20 1560 820],'Color','w','Visible','off');
tl=tiledlayout(f,numel(ts),2,'Padding','compact','TileSpacing','compact');
for a=1:numel(ts)
    tt=ts(a);
    % --- pi profile
    ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12; h=gobjects(0); nm={};
    for i=1:numel(R)
        j=find([R(i).scan.t]==tt,1); if isempty(j), continue; end
        S=R(i).scan(j).S;
        pr=ceof(max(S.rhs,[],1)); y=100*(pr/max(pr)-1);
        h(end+1)=plot(ax,S.pi,y,'Color',col(min(i,end),:),'LineWidth',1.6+0.5*(i==numel(R))); %#ok<AGROW>
        nm{end+1}=sprintf('%s = %d nodes',mat2str(R(i).dim),R(i).n);      %#ok<AGROW>
    end
    xlim(ax,[0 1]); ylim(ax,[-15 1]);
    xlabel(ax,'equity share \pi'); ylabel(ax,'% CE below the best \pi');
    title(ax,sprintf('age %d -- objective along \\pi, consumption optimised out',24+tt), ...
        'FontWeight','normal');
    if a==1, legend(ax,h,nm,'Box','off','Location','southeast','FontSize',8); end

    % --- c profile
    ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    for i=1:numel(R)
        j=find([R(i).scan.t]==tt,1); if isempty(j), continue; end
        S=R(i).scan(j).S;
        cp=ceof(max(S.rhs,[],2)).'; y=100*(cp/max(cp)-1);
        plot(ax,S.c,y,'Color',col(min(i,end),:),'LineWidth',1.6+0.5*(i==numel(R)));
    end
    xlim(ax,[0 1]); ylim(ax,[-40 2]);
    xlabel(ax,'consumption share c'); ylabel(ax,'% CE below the best c');
    title(ax,sprintf('age %d -- objective along c, \\pi optimised out',24+tt), ...
        'FontWeight','normal');
end
sgtitle(f,sprintf(['Does refining the cube change the objective? Same state (u1,u2,u3) = (%.2f, %.2f, %.2f), gh_n = 3 throughout, ' ...
  'so only the number of grid points varies. Steps that are interpolation should move and soften with refinement; steps that are the model should stay.'], ...
  tgt(1),tgt(2),tgt(3)),'FontWeight','normal','FontSize',10.5,'Interpreter','tex');
exportgraphics(f,fullfile(out_dir,'factorial_figs','S9_resolution_objective.png'),'Resolution',140);
close(f);

fprintf('\n%-14s %7s %8s', 'cube','nodes','sec');
for tt=ts, fprintf('  age%d: %-22s', 24+tt, 'best pi / best c'); end
fprintf('\n');
for i=1:numel(R)
    fprintf('%-14s %7d %8.0f', mat2str(R(i).dim), R(i).n, R(i).sec);
    for tt=ts
        j=find([R(i).scan.t]==tt,1);
        if isempty(j), fprintf('  %-30s','-'); continue; end
        S=R(i).scan(j).S;
        [~,im]=max(S.rhs(:)); [ig,jg]=ind2sub(size(S.rhs),im);
        fprintf('  pi=%.3f c=%.3f            ', S.pi(jg), S.c(ig));
    end
    fprintf('\n');
end
end
