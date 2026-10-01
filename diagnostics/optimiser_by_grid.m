function optimiser_by_grid(out_dir)
%OPTIMISER_BY_GRID  Does refining the cube make the optimiser choice matter less?
%
%   The optimiser study was run at one cube size. If the basins are an artefact
%   of a coarse interpolant they should thin out as the cube is refined, and the
%   arms should converge on each other. If they are the model, the spread
%   between arms should survive refinement.
%
%   Four search routines at three cube sizes, gh_n = 5, same seed and the same
%   6000 households everywhere, compared on simulated paths and policy surfaces
%   rather than on value levels, which are not comparable across grids.
%
%   Resumable: each solve saved as it finishes.

if nargin<1||isempty(out_dir), out_dir=fileparts(mfilename('fullpath')); end
res=fullfile(out_dir,'optimiser_by_grid.mat');

ARMS = { 'A no sweep',            0,'post',1,0
         'B sweep pi after',      1,'post',1,0
         'E sweep pi and c first',1,'pre', 1,1
         'F sweep c first',       1,'pre', 0,1 };
DIMS = { [12 12 8], [16 16 10], [20 20 12] };
TS   = [10 30 50];
NSIM = 6000; SEED = 20260511;

R=struct('arm',{},'dim',{},'n',{},'sec',{},'sim',{},'pol',{});
if isfile(res), L=load(res); R=L.R; end
for i=1:numel(DIMS)
    for j=1:size(ARMS,1)
        if any(arrayfun(@(r) isequal(r.dim,DIMS{i}) && strcmp(r.arm,ARMS{j,1}), R)), continue; end
        fprintf('[%s] %s at %s ...\n', datestr(now,'HH:MM:SS'), ARMS{j,1}, mat2str(DIMS{i}));
        try
            tic; o=run_one(DIMS{i}, ARMS{j,2}, ARMS{j,3}, ARMS{j,4}, ARMS{j,5}, TS, NSIM, SEED); sec=toc;
            R(end+1).arm=ARMS{j,1}; R(end).dim=DIMS{i}; R(end).n=prod(DIMS{i});  %#ok<AGROW>
            R(end).sec=sec; R(end).sim=o.sim; R(end).pol=o.pol;
            save(res,'R','-v7.3');
            fprintf('   %.0f s | pi@80=%.3f pi@34=%.3f\n', sec, ...
                o.sim.pi_liq(o.sim.ages==80), o.sim.pi_liq(o.sim.ages==34));
        catch ME
            fprintf('   FAILED: %s\n', ME.message);
        end
    end
end
make_fig(R, out_dir);
end

% ------------------------------------------------------------------------
function o = run_one(dim, ref, stage, piglob, cglob, ts, nsim, seed)
p=config.params(); p.is_owner=false;
p.grid_mode='none'; p.polish_ver=2; p.polish_algo='active-set';
p.use_refine=ref; p.refine_stage=stage;
p.refine_pi_global=piglob; p.refine_c_global=cglob;
p.lambda_lo=0.0008; p.lambda_hi=0.44; p.grid_pow=1.6;
p.u2_lo=0.40; p.grid_pow_u2=1; p.u3_lo=0.02; p.u3_hi=0.98;
p=utility.build_state_grids(p,dim,5);
[~,mg,sl]=config.income_profile(p);
pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(p);
shk=grids.shock_grid(p); an=pension.annuity_price(p,pf,shk);
sol=solver.solve_lifecycle_lna(p,pf,shk,an);
s=simulate.forward(p,pf,sol,an,nsim,seed,p.b0);
o.sim=h1_summary(p,s);
i3=round(p.N_u3/2);
o.pol.u1=p.u1_grid(:); o.pol.u2=p.u2_grid(:); o.pol.t=ts;
for a=1:numel(ts), o.pol.pi{a}=squeeze(sol.pi_pol(:,:,i3,ts(a))); end
end

% ------------------------------------------------------------------------
function make_fig(R, out_dir)
if isempty(R), return; end
fd=fullfile(out_dir,'factorial_figs');
arms=unique({R.arm},'stable'); ns=unique([R.n]);
col=[0.85 0.33 0.10; 0.20 0.45 0.75; 0.10 0.10 0.10; 0.30 0.65 0.45];
f=figure('Position',[10 10 520*numel(ns) 760],'Color','w','Visible','off');
tl=tiledlayout(f,2,numel(ns),'Padding','compact','TileSpacing','compact');
h=gobjects(0); nm={};
for i=1:numel(ns)
    ax=nexttile(tl,i); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    for j=1:numel(arms)
        k=find([R.n]==ns(i) & strcmp({R.arm},arms{j}),1); if isempty(k), continue; end
        hh=plot(ax,R(k).sim.ages,100*R(k).sim.pi_liq,'Color',col(j,:),'LineWidth',2, ...
            'LineStyle',ternary(j==1,'--','-'));
        if i==1, h(end+1)=hh; nm{end+1}=arms{j}; end                      %#ok<AGROW>
    end
    xline(ax,67,'-','Color',[.4 .4 .4]); xlim(ax,[25 95]); ylim(ax,[0 100]);
    xlabel(ax,'age'); ylabel(ax,'% in equity');
    k=find([R.n]==ns(i),1);
    title(ax,sprintf('%s = %d nodes',mat2str(R(k).dim),ns(i)),'FontWeight','normal');
end
for i=1:numel(ns)
    ax=nexttile(tl,numel(ns)+i); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    kE=find([R.n]==ns(i) & contains({R.arm},'E '),1);
    if isempty(kE), continue; end
    for j=1:numel(arms)
        k=find([R.n]==ns(i) & strcmp({R.arm},arms{j}),1); if isempty(k), continue; end
        plot(ax,R(k).sim.ages,100*(R(k).sim.pi_liq-R(kE).sim.pi_liq),'Color',col(j,:),'LineWidth',1.7);
    end
    yline(ax,0,'-','Color',[.5 .5 .5]); xline(ax,67,'-','Color',[.4 .4 .4]); xlim(ax,[25 95]);
    xlabel(ax,'age'); ylabel(ax,'pp vs arm E');
    title(ax,'spread between search routines','FontWeight','normal');
end
lg=legend(h,nm,'Box','off','FontSize',9,'NumColumns',4); lg.Layout.Tile='south';
sgtitle(f,['Does a finer cube make the search routine matter less? Same four routines at three resolutions, gh\_n = 5, identical households. ' ...
  'If the basins were a coarse-grid artefact the arms would converge to the left.'], ...
  'FontWeight','normal','FontSize',11,'Interpreter','tex');
exportgraphics(f,fullfile(fd,'S16_optimiser_by_grid.png'),'Resolution',130); close(f);

fprintf('\n=== simulated equity share by routine and cube ===\n');
fprintf('%-24s %-14s %7s %8s %8s %8s %8s\n','routine','cube','sec','pi@34','pi@54','pi@80','pi@90');
for i=1:numel(ns)
    for j=1:numel(arms)
        k=find([R.n]==ns(i) & strcmp({R.arm},arms{j}),1); if isempty(k), continue; end
        s=R(k).sim;
        fprintf('%-24s %-14s %7.0f %8.3f %8.3f %8.3f %8.3f\n', arms{j}, mat2str(R(k).dim), ...
            R(k).sec, s.pi_liq(s.ages==34), s.pi_liq(s.ages==54), ...
            s.pi_liq(s.ages==80), s.pi_liq(s.ages==90));
    end
end
fprintf('\n=== spread across routines at each cube (max-min of pi) ===\n');
fprintf('%-14s %14s %14s\n','cube','accum (<=55)','retirement (>=67)');
for i=1:numel(ns)
    P=[];
    for j=1:numel(arms)
        k=find([R.n]==ns(i) & strcmp({R.arm},arms{j}),1); if isempty(k), continue; end
        P=[P; R(k).sim.pi_liq];                                            %#ok<AGROW>
    end
    if isempty(P), continue; end
    a=R(find([R.n]==ns(i),1)).sim.ages; acc=a<=55; ret=a>=67;
    fprintf('%-14s %14.3f %14.3f\n', mat2str(R(find([R.n]==ns(i),1)).dim), ...
        max(max(P(:,acc))-min(P(:,acc))), max(max(P(:,ret))-min(P(:,ret))));
end
fprintf('figure in %s\n', fd);
end

function v=ternary(c,a,b), if c, v=a; else, v=b; end, end
