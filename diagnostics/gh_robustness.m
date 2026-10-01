function gh_robustness(out_dir)
%GH_ROBUSTNESS  Does the quadrature, rather than the grid, make the steps?
%
%   The resolution study holds gh_n at 3 and varies the cube. This does the
%   complement on two cube sizes: the same state scanned with gh_n = 5, against
%   the gh_n = 3 result already stored by resolution_objective. Integration
%   error and interpolation error are separate sources, and a step that is an
%   artefact of one need not be an artefact of the other.
%
%   Two cube sizes only -- a spot check, not a sweep.

if nargin<1||isempty(out_dir), out_dir = fileparts(mfilename('fullpath')); end
res  = fullfile(out_dir,'gh_robustness.mat');
base = fullfile(out_dir,'resolution_objective.mat');
if ~isfile(base), fprintf('resolution_objective.mat not there yet\n'); return; end
B = load(base); R3 = B.R;

dims = {[12 12 8],[20 20 12]};
TGT  = [0.20 0.75 0.33];
TS   = [10 50];

R5 = struct('dim',{},'n',{},'sec',{},'scan',{});
if isfile(res), L=load(res); R5=L.R5; end
for i=1:numel(dims)
    if any(cellfun(@(d) isequal(d,dims{i}), {R5.dim})), continue; end
    fprintf('solving %s at gh_n=5 ...\n', mat2str(dims{i}));
    tic; sc = run_one(dims{i}, TGT, TS, out_dir, 5); sec=toc;
    R5(end+1).dim=dims{i}; R5(end).n=prod(dims{i}); R5(end).sec=sec; R5(end).scan=sc; %#ok<AGROW>
    save(res,'R5','-v7.3'); fprintf('   %.0f s\n', sec);
end
make_fig(R3, R5, TGT, TS, out_dir);
end

% ------------------------------------------------------------------------
function sc = run_one(dim, tgt, ts, out_dir, ghn)
p = config.params(); p.is_owner=false;
p.grid_mode='none'; p.polish_ver=2; p.use_refine=0; p.polish_algo='active-set';
p.lambda_lo=0.0008; p.lambda_hi=0.44; p.grid_pow=1.6;
p.u2_lo=0.40; p.grid_pow_u2=1; p.u3_lo=0.02; p.u3_hi=0.98;
p = utility.build_state_grids(p, dim, ghn);
N = [p.N_u1 p.N_u2 p.N_u3];
[~,i1]=min(abs(p.u1_grid-tgt(1)));
[~,i2]=min(abs(p.u2_grid-tgt(2)));
[~,i3]=min(abs(p.u3_grid-tgt(3)));
k = sub2ind(N,i1,i2,i3);
sd = fullfile(out_dir, sprintf('scan_gh%d_%d', ghn, prod(dim)));
if isfolder(sd), rmdir(sd,'s'); end
mkdir(sd);
p.scan = struct('t', ts, 'nodes', k, 'c_n', 121, 'pi_n', 121, 'dir', sd);
[~,mg,sl]=config.income_profile(p);
pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(p);
shk=grids.shock_grid(p); an=pension.annuity_price(p,pf,shk);
solver.solve_lifecycle_lna(p,pf,shk,an);
sc = struct('t',{},'S',{});
F = dir(fullfile(sd,'scan_*.mat'));
for j=1:numel(F)
    tok=regexp(F(j).name,'scan_t(\d+)','tokens');
    sc(end+1).t = str2double(tok{1}{1});                                  %#ok<AGROW>
    sc(end).S   = load(fullfile(sd,F(j).name));
end
end

% ------------------------------------------------------------------------
function make_fig(R3, R5, tgt, ts, out_dir)
g=5; ceof=@(v)((1-g)*v).^(1/(1-g));
f=figure('Position',[20 20 1520 800],'Color','w','Visible','off');
tl=tiledlayout(f,numel(ts),numel(R5),'Padding','compact','TileSpacing','compact');
for a=1:numel(ts)
    tt=ts(a);
    for i=1:numel(R5)
        ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12; h=gobjects(0); nm={};
        i3 = find(cellfun(@(d) isequal(d,R5(i).dim), {R3.dim}),1);
        if ~isempty(i3)
            j=find([R3(i3).scan.t]==tt,1);
            if ~isempty(j)
                S=R3(i3).scan(j).S; pr=ceof(max(S.rhs,[],1));
                h(end+1)=plot(ax,S.pi,100*(pr/max(pr)-1),'Color',[0.85 0.45 0.15],'LineWidth',2.4); %#ok<AGROW>
                nm{end+1}='gh\_n = 3';                                     %#ok<AGROW>
            end
        end
        j=find([R5(i).scan.t]==tt,1);
        if ~isempty(j)
            S=R5(i).scan(j).S; pr=ceof(max(S.rhs,[],1));
            h(end+1)=plot(ax,S.pi,100*(pr/max(pr)-1),'Color',[0.10 0.25 0.60],'LineWidth',1.7,'LineStyle','--'); %#ok<AGROW>
            nm{end+1}='gh\_n = 5';                                         %#ok<AGROW>
        end
        xlim(ax,[0 1]); ylim(ax,[-15 1]);
        xlabel(ax,'equity share \pi'); ylabel(ax,'% CE below the best \pi');
        title(ax,sprintf('age %d, %s = %d nodes',24+tt,mat2str(R5(i).dim),R5(i).n), ...
            'FontWeight','normal');
        if a==1 && i==1, legend(ax,h,nm,'Box','off','Location','southeast','FontSize',8.5); end
    end
end
sgtitle(f,sprintf(['Quadrature spot check. Same state (%.2f, %.2f, %.2f) and the same cube, solved with 3 and with 5 Gauss-Hermite points. ' ...
  'If the steps are integration error they should shift; if they are the model they should not.'], tgt(1),tgt(2),tgt(3)), ...
  'FontWeight','normal','FontSize',11,'Interpreter','tex');
exportgraphics(f,fullfile(out_dir,'factorial_figs','S10_gh_robustness.png'),'Resolution',140);
close(f);

fprintf('\n%-14s %6s %10s %10s %12s\n','cube','gh_n','best pi','best c','sec');
for i=1:numel(R5)
    i3=find(cellfun(@(d) isequal(d,R5(i).dim), {R3.dim}),1);
    for src=1:2
        if src==1
            if isempty(i3), continue; end
            Rx=R3(i3); gh=3;
        else
            Rx=R5(i); gh=5;
        end
        j=find([Rx.scan.t]==ts(end),1); if isempty(j), continue; end
        S=Rx.scan(j).S; [~,im]=max(S.rhs(:)); [ig,jg]=ind2sub(size(S.rhs),im);
        fprintf('%-14s %6d %10.3f %10.3f %12.0f\n', mat2str(Rx.dim), gh, S.pi(jg), S.c(ig), Rx.sec);
    end
end
end
