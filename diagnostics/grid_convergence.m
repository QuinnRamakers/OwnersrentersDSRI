function grid_convergence(out_dir)
%GRID_CONVERGENCE  Does anything settle as the cube is refined?
%
%   The single-state test showed the optimal equity share at age 34 still moving
%   from 0.458 to 0.025 between 384 and 4800 nodes. That is one state, so this
%   asks the question properly, on three objects that ARE comparable across
%   grids:
%
%     the policy surfaces   pi and c over the cube, interpolated onto one common
%                           grid so different cubes can be differenced
%     the objective shape   the profile in pi at fixed states, normalised at each
%                           resolution so only its shape is compared
%     the simulated paths   same seed, same number of households, same shocks, so
%                           the lifecycle profiles are directly comparable
%
%   Value-function levels are deliberately NOT compared. V is built on a
%   different grid in each solve, so its level carries the grid with it and a
%   welfare gap between two resolutions is not a welfare statement.
%
%   The search is held at the corrected setting throughout (sweep both
%   variables, before fmincon), so what moves is the model's answer rather than
%   the solver's ability to find it.
%
%   Resumable: each solve is saved as it finishes.

if nargin<1||isempty(out_dir), out_dir = fileparts(mfilename('fullpath')); end
res = fullfile(out_dir,'grid_convergence.mat');

% cube, gh_n. The gh_n=3 rows repeat three cubes to separate quadrature from grid.
CASES = { [8 8 6],5;  [10 10 8],5; [12 12 8],5;  [14 14 10],5
          [16 16 10],5; [18 18 12],5; [20 20 12],5; [24 24 14],5
          [12 12 8],3;  [16 16 10],3; [20 20 12],3 };
TS   = [10 30 50];                      % ages 34, 54, 74
TGT  = [0.10 0.60 0.33; 0.20 0.75 0.33; 0.35 0.90 0.50];
NSIM = 6000; SEED = 20260511;

R = struct('dim',{},'gh',{},'n',{},'sec',{},'pol',{},'sim',{},'scan',{});
if isfile(res), L=load(res); R=L.R; end
for i=1:size(CASES,1)
    d=CASES{i,1}; gh=CASES{i,2};
    if any(arrayfun(@(r) isequal(r.dim,d) && r.gh==gh, R)), continue; end
    fprintf('[%s] solving %s gh_n=%d ...\n', datestr(now,'HH:MM:SS'), mat2str(d), gh);
    try
        tic; o = run_one(d, gh, TS, TGT, NSIM, SEED, out_dir); sec=toc;
        R(end+1).dim=d; R(end).gh=gh; R(end).n=prod(d); R(end).sec=sec;  %#ok<AGROW>
        R(end).pol=o.pol; R(end).sim=o.sim; R(end).scan=o.scan; R(end).occ=o.occ;
        save(res,'R','-v7.3');
        fprintf('   %.0f s | pi@80=%.3f pi@34=%.3f C@34=%.0f\n', sec, ...
            o.sim.pi_liq(o.sim.ages==80), o.sim.pi_liq(o.sim.ages==34), o.sim.C(o.sim.ages==34));
    catch ME
        fprintf('   FAILED: %s\n', ME.message);
    end
end
make_figs(R, TS, out_dir);
end

% ------------------------------------------------------------------------
function o = run_one(dim, ghn, ts, tgt, nsim, seed, out_dir)
p = config.params(); p.is_owner=false;
p.grid_mode='none'; p.polish_ver=2; p.polish_algo='active-set';
p.use_refine=true; p.refine_stage='pre';
p.refine_pi_global=true; p.refine_c_global=true;
p.lambda_lo=0.0008; p.lambda_hi=0.44; p.grid_pow=1.6;
p.u2_lo=0.40; p.grid_pow_u2=1; p.u3_lo=0.02; p.u3_hi=0.98;
p = utility.build_state_grids(p, dim, ghn);
N=[p.N_u1 p.N_u2 p.N_u3];

% objective scans at fixed physical states
ks=zeros(size(tgt,1),1);
for q=1:size(tgt,1)
    [~,a1]=min(abs(p.u1_grid-tgt(q,1)));
    [~,a2]=min(abs(p.u2_grid-tgt(q,2)));
    [~,a3]=min(abs(p.u3_grid-tgt(q,3)));
    ks(q)=sub2ind(N,a1,a2,a3);
end
sd=fullfile(out_dir,sprintf('scan_gc_%d_%d',prod(dim),ghn));
if isfolder(sd), rmdir(sd,'s'); end
mkdir(sd);
p.scan=struct('t',ts,'nodes',unique(ks),'c_n',81,'pi_n',81,'dir',sd);

[~,mg,sl]=config.income_profile(p);
pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(p);
shk=grids.shock_grid(p); an=pension.annuity_price(p,pf,shk);
sol=solver.solve_lifecycle_lna(p,pf,shk,an);

% policy slices at mid u3
i3=round(p.N_u3/2);
o.pol.u1=p.u1_grid(:); o.pol.u2=p.u2_grid(:); o.pol.u3_at=p.u3_grid(i3); o.pol.t=ts;
for a=1:numel(ts)
    o.pol.pi{a}=squeeze(sol.pi_pol(:,:,i3,ts(a)));
    o.pol.c{a} =squeeze(sol.c_pol (:,:,i3,ts(a)));
end

% simulation, identical seed and count across resolutions
s=simulate.forward(p,pf,sol,an,nsim,seed,p.b0);
o.sim=h1_summary(p,s);

% Where households actually sit on the cube. The wealth shares come straight
% out of the simulation, so the occupied region can be compared with where the
% grid puts its nodes and with where the objective misbehaves.
o.occ = occupancy(s, p, ts);

% scans back off disk
o.scan=struct('t',{},'k',{},'S',{});
F=dir(fullfile(sd,'scan_*.mat'));
for j=1:numel(F)
    tok=regexp(F(j).name,'scan_t(\d+)_k(\d+)','tokens'); tok=tok{1};
    o.scan(end+1).t=str2double(tok{1}); o.scan(end).k=str2double(tok{2});  %#ok<AGROW>
    o.scan(end).S=load(fullfile(sd,F(j).name));
end
rmdir(sd,'s');
end

% ------------------------------------------------------------------------
function occ = occupancy(s, p, ts)
%OCCUPANCY  Where the simulated households sit in cube coordinates.
%   u1 = lambda, u2 = (sA+sH)/(1-lambda), u3 = sA/(sA+sH), read off the
%   simulated wealth shares. Stored as a 2-D histogram on a fixed grid plus the
%   quantiles, so occupancy from different cubes can be laid on one picture.
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
    % share of households outside the cube's own bounds at this age
    occ.off(a)=mean(x(ok)<p.u1_grid(1) | x(ok)>p.u1_grid(end) | ...
                    y(ok)<p.u2_grid(1) | y(ok)>p.u2_grid(end));
end
end

% ------------------------------------------------------------------------
function make_figs(R, ts, out_dir)
if isempty(R), fprintf('nothing solved\n'); return; end
fd=fullfile(out_dir,'factorial_figs');
m5=find([R.gh]==5); [~,o5]=sort([R(m5).n]); m5=m5(o5);
cols=parula(max(numel(m5),2));

% ---------- 1: simulated lifecycle paths, the comparable object
a=R(m5(1)).sim.ages;
F1={'pi_liq','% of liquid savings in equity',100;
    'C','consumption, EUR000',1e-3;
    'X','liquid savings, EUR000',1e-3;
    'A','pension pot, EUR000',1e-3;
    'tot_eq_sh','total equity exposure, %',100};
f=figure('Position',[10 10 1600 880],'Color','w','Visible','off');
tl=tiledlayout(f,2,3,'Padding','compact','TileSpacing','compact'); h=gobjects(0); nm={};
for q=1:size(F1,1)
    ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    for i=1:numel(m5)
        y=R(m5(i)).sim.(F1{q,1})*F1{q,3};
        hh=plot(ax,R(m5(i)).sim.ages,y,'Color',cols(i,:),'LineWidth',1.4+0.9*(i==numel(m5)));
        if q==1, h(end+1)=hh; nm{end+1}=sprintf('%s = %d',mat2str(R(m5(i)).dim),R(m5(i)).n); end %#ok<AGROW>
    end
    xline(ax,67,'-','Color',[.4 .4 .4]); xlim(ax,[25 95]);
    xlabel(ax,'age'); ylabel(ax,F1{q,2});
    title(ax,F1{q,2},'FontWeight','normal');
end
ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
ref=R(m5(end));
for i=1:numel(m5)
    d=100*(R(m5(i)).sim.pi_liq-ref.sim.pi_liq);
    plot(ax,ref.sim.ages,d,'Color',cols(i,:),'LineWidth',1.5);
end
yline(ax,0,'-','Color',[.5 .5 .5]); xline(ax,67,'-','Color',[.4 .4 .4]); xlim(ax,[25 95]);
xlabel(ax,'age'); ylabel(ax,'equity share minus finest cube (pp)');
title(ax,'deviation from the finest cube','FontWeight','normal');
lg=legend(h,nm,'Box','off','FontSize',8.5,'NumColumns',4); lg.Layout.Tile='south';
sgtitle(f,['Simulated lifecycles across cube resolutions. gh\_n = 5, corrected search, same 6000 households and the same seed in every solve, ' ...
  'so these paths are directly comparable where value-function levels would not be.'], ...
  'FontWeight','normal','FontSize',11,'Interpreter','tex');
exportgraphics(f,fullfile(fd,'S12_simulated_by_grid.png'),'Resolution',130); close(f);

% ---------- 2: policy surfaces
u1c=linspace(R(m5(end)).pol.u1(1),R(m5(end)).pol.u1(end),60);
u2c=linspace(R(m5(end)).pol.u2(1),R(m5(end)).pol.u2(end),60);
[G1,G2]=ndgrid(u1c,u2c);
for ai=1:numel(ts)
    for what={'pi','c'}
        nsel=min(numel(m5),8); sel=m5(round(linspace(1,numel(m5),nsel)));
        nc=4; nr=ceil(nsel/nc);
        f=figure('Position',[10 10 400*nc 330*nr],'Color','w','Visible','off');
        tl=tiledlayout(f,nr,nc,'Padding','compact','TileSpacing','compact');
        lo=inf; hi=-inf; Z=cell(1,nsel);
        for i=1:nsel
            P=R(sel(i)).pol.(what{1}){ai};
            Z{i}=interpn(R(sel(i)).pol.u1,R(sel(i)).pol.u2,P,G1,G2,'linear',NaN);
            lo=min(lo,min(Z{i}(:))); hi=max(hi,max(Z{i}(:)));
        end
        for i=1:nsel
            ax=nexttile(tl); imagesc(ax,u2c,u1c,Z{i}); axis(ax,'xy'); clim(ax,[lo hi]);
            colormap(ax,parula);
            if mod(i,nc)==0 || i==nsel, cb=colorbar(ax); cb.Label.String=what{1}; end
            xlabel(ax,'u2'); ylabel(ax,'u1');
            title(ax,sprintf('%s = %d nodes',mat2str(R(sel(i)).dim),R(sel(i)).n),'FontWeight','normal');
        end
        nmw='equity share \pi'; if strcmp(what{1},'c'), nmw='consumption share c'; end
        sgtitle(f,sprintf('%s at age %d over (u1,u2) at u3 = %.2f, one shared colour scale', ...
            nmw,24+ts(ai),R(m5(end)).pol.u3_at),'FontWeight','normal','FontSize',11,'Interpreter','tex');
        exportgraphics(f,fullfile(fd,sprintf('S13_policy_%s_age%d.png',what{1},24+ts(ai))),'Resolution',120);
        close(f);
    end
end

% ---------- 3: objective shape at fixed states
g=5; ceof=@(v)((1-g)*v).^(1/(1-g));
ks=unique([R(m5(end)).scan.k]);
f=figure('Position',[10 10 1560 400*numel(ts)],'Color','w','Visible','off');
tl=tiledlayout(f,numel(ts),numel(ks),'Padding','compact','TileSpacing','compact');
for ai=1:numel(ts)
    for kq=1:numel(ks)
        ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
        for i=1:numel(m5)
            sc=R(m5(i)).scan;
            j=find([sc.t]==ts(ai),1,'first');
            jj=find([sc.t]==ts(ai) & [sc.k]==ks(kq),1);
            if isempty(jj), if isempty(j), continue; end, jj=j; end
            S=sc(jj).S; pr=ceof(max(S.rhs,[],1));
            plot(ax,S.pi,100*(pr/max(pr)-1),'Color',cols(i,:),'LineWidth',1.3+0.9*(i==numel(m5)));
        end
        xlim(ax,[0 1]); ylim(ax,[-15 1]);
        xlabel(ax,'\pi'); ylabel(ax,'% below best \pi');
        title(ax,sprintf('age %d, state %d',24+ts(ai),kq),'FontWeight','normal');
    end
end
sgtitle(f,['Shape of the objective in \pi at fixed states, normalised at each resolution. ' ...
  'Only the shape is compared: levels are not comparable across grids.'], ...
  'FontWeight','normal','FontSize',11,'Interpreter','tex');
exportgraphics(f,fullfile(fd,'S14_objective_shape_by_grid.png'),'Resolution',120); close(f);

% ---------- numbers
fprintf('\n=== simulated equity share by cube (gh_n=5) ===\n');
fprintf('%-14s %7s %8s', 'cube','nodes','sec');
shA=[30 40 50 60 70 80 90]; fprintf('%8d',shA); fprintf('\n');
for i=1:numel(m5)
    s=R(m5(i)).sim; fprintf('%-14s %7d %8.0f', mat2str(R(m5(i)).dim), R(m5(i)).n, R(m5(i)).sec);
    for ag=shA, fprintf('%8.3f', s.pi_liq(s.ages==ag)); end
    fprintf('\n');
end
fprintf('\n=== change vs the finest cube ===\n');
fprintf('%-14s %12s %12s %12s %12s\n','cube','RMS dpi acc','RMS dpi ret','RMS dC/C','max dpi');
for i=1:numel(m5)
    s=R(m5(i)).sim; r=ref.sim; acc=s.ages<=55; ret=s.ages>=67;
    dpi=s.pi_liq-r.pi_liq; dC=(s.C-r.C)./max(r.C,eps);
    fprintf('%-14s %12.4f %12.4f %12.4f %12.4f\n', mat2str(R(m5(i)).dim), ...
        sqrt(mean(dpi(acc).^2)), sqrt(mean(dpi(ret).^2)), sqrt(mean(dC.^2)), max(abs(dpi)));
end
m3=find([R.gh]==3);
if ~isempty(m3)
    fprintf('\n=== quadrature cross-check: gh_n 3 vs 5 at the same cube ===\n');
    fprintf('%-14s %12s %12s %12s\n','cube','RMS dpi','max dpi','RMS dC/C');
    for i=1:numel(m3)
        k5=find([R.gh]==5 & arrayfun(@(r) isequal(r.dim,R(m3(i)).dim), R),1);
        if isempty(k5), continue; end
        s3=R(m3(i)).sim; s5=R(k5).sim;
        dpi=s3.pi_liq-s5.pi_liq; dC=(s3.C-s5.C)./max(s5.C,eps);
        fprintf('%-14s %12.4f %12.4f %12.4f\n', mat2str(R(m3(i)).dim), ...
            sqrt(mean(dpi.^2)), max(abs(dpi)), sqrt(mean(dC.^2)));
    end
end
fprintf('\nfigures in %s\n', fd);
end
