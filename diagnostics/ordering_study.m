function ordering_study(out_dir)
%ORDERING_STUDY  Search for the seed first, or patch the answer afterwards?
%
%   The shipped solver runs fmincon from the warm start and only then sweeps,
%   which is backwards: the sweep is what locates the basin, so it belongs
%   before the local solve, not after it. These six arms separate the two
%   questions -- what is swept, and when.
%
%     A  no sweep                 fmincon from the warm start, nothing else
%     B  sweep pi after           the shipped refinement
%     C  sweep pi and c after     the shipped refinement, c widened
%     D  sweep pi before          same sweep, used to pick fmincon's seed
%     E  sweep pi and c before    both widened, used to pick the seed
%     F  sweep c before           only consumption swept, to separate the two
%
%   Reported: solve time, the retirement equity share, and how much certainty
%   equivalent each arm leaves against the best arm at each node.

if nargin<1||isempty(out_dir)
    out_dir='C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad';
end
res=fullfile(out_dir,'ordering_study.mat');

%  name                        refine stage   pi_glob c_glob
V = { 'A no sweep',                 0, 'post', 1, 0
      'B sweep pi after (shipped)', 1, 'post', 1, 0
      'C sweep pi and c after',     1, 'post', 1, 1
      'D sweep pi before',          1, 'pre',  1, 0
      'E sweep pi and c before',    1, 'pre',  1, 1
      'F sweep c before',           1, 'pre',  0, 1 };

S=struct('name',{},'sec',{},'out',{});
if isfile(res), L=load(res); S=L.S; end
for i=1:size(V,1)
    if any(strcmp(V{i,1},{S.name})), continue; end
    fprintf('solving %-28s ...\n', V{i,1});
    tic; o=run_one(V{i,2},V{i,3},V{i,4},V{i,5}); sec=toc;
    S(end+1).name=V{i,1}; S(end).sec=sec; S(end).out=o;                   %#ok<AGROW>
    save(res,'S','-v7.3'); fprintf('   %.0f s\n', sec);
end
report(S); make_fig(S,out_dir);
end

% ------------------------------------------------------------------------
function o = run_one(ref, stage, piglob, cglob)
p=config.params(); p.is_owner=false;
p.grid_mode='none'; p.polish_ver=2; p.polish_algo='active-set';
p.use_refine=ref; p.refine_stage=stage;
p.refine_pi_global=piglob; p.refine_c_global=cglob;
p.lambda_lo=0.0008; p.lambda_hi=0.44; p.grid_pow=1.6;
p.u2_lo=0.40; p.grid_pow_u2=1; p.u3_lo=0.02; p.u3_hi=0.98;
p=utility.build_state_grids(p,[12 12 8],3);
[~,mg,sl]=config.income_profile(p);
pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(p);
sk=grids.shock_grid(p); an=pension.annuity_price(p,pf,sk);
sol=solver.solve_lifecycle_lna(p,pf,sk,an);
s=simulate.forward(p,pf,sol,an,2000,20260511,p.b0);
K=1:size(s.tau_A,2);
o.ages=s.ages(K); o.pi=mean(s.pi(:,K),1,'omitnan');
o.C=median(s.C(:,K),1,'omitnan'); o.X=median(s.X(:,K),1,'omitnan');
o.V=sol.V;
end

% ------------------------------------------------------------------------
function report(S)
g=5; ceof=@(V)((1-g)*V).^(1/(1-g));
n=numel(S); a=S(1).out.ages; ret=a>=67;
% best arm at each node, so no arm is privileged as the reference
C=arrayfun(@(k) ceof(S(k).out.V), 1:n, 'uni', 0);
B=C{1}; for k=2:n, B=max(B,C{k}); end
fprintf('\n%-28s %7s %8s %11s %11s %9s %9s\n', ...
    'arm','sec','vs A','med CE gap','p90 CE gap','pi@80','pi@90');
for k=1:n
    d=(C{k}-B)./max(B,eps); d=d(isfinite(d));
    fprintf('%-28s %7.0f %7.2fx %+10.2e %+10.2e %9.3f %9.3f\n', ...
        S(k).name, S(k).sec, S(k).sec/S(1).sec, median(d), prctile(d,10), ...
        S(k).out.pi(a==80), S(k).out.pi(a==90));
end
fprintf('\nretirement equity share by age\n%-28s','arm');
sh=[67 70 75 80 85 90]; fprintf('%8d',sh); fprintf('\n');
for k=1:n
    fprintf('%-28s',S(k).name);
    for ag=sh, fprintf('%8.3f',S(k).out.pi(a==ag)); end
    fprintf('\n');
end
fprintf('\nmax |pi| spread across arms in retirement: %.3f\n', ...
    max(max(cell2mat(arrayfun(@(k) S(k).out.pi(ret), 1:n,'uni',0).')) - ...
        min(cell2mat(arrayfun(@(k) S(k).out.pi(ret), 1:n,'uni',0).'))));
end

% ------------------------------------------------------------------------
function make_fig(S,out_dir)
n=numel(S); a=S(1).out.ages;
col=[0.85 0.33 0.10; 0.10 0.10 0.10; 0.45 0.30 0.70; 0.15 0.45 0.75; 0.30 0.65 0.45; 0.90 0.60 0.15];
ls ={'--','-','-','-','-','-'};
f=figure('Position',[20 20 1560 700],'Color','w','Visible','off');
tl=tiledlayout(f,1,3,'Padding','compact','TileSpacing','compact');

ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12; h=gobjects(0);
for k=1:n, h(k)=plot(ax,a,100*S(k).out.pi,'Color',col(k,:),'LineWidth',2,'LineStyle',ls{k}); end
xline(ax,67,'-','Color',[.4 .4 .4],'LineWidth',1.2); xlim(ax,[60 95]); ylim(ax,[30 100]);
xlabel(ax,'age'); ylabel(ax,'% of liquid savings in equity');
title(ax,'retirement equity share','FontWeight','normal');
lg=legend(ax,h,{S.name},'Box','off','FontSize',8.5,'NumColumns',3); lg.Layout.Tile='south';

ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
b=bar(ax,1:n,[S.sec],0.6,'FaceColor','flat','EdgeColor',[.3 .3 .3]);
for k=1:n, b.CData(k,:)=col(k,:); end
set(ax,'XTick',1:n,'XTickLabel',compose('%c',char(64+(1:n))));
ylabel(ax,'solve time (s)'); xlabel(ax,'arm');
title(ax,'runtime','FontWeight','normal');
for k=1:n
    text(ax,k,S(k).sec,sprintf(' %.1fx',S(k).sec/S(1).sec),'HorizontalAlignment','center', ...
        'VerticalAlignment','bottom','FontSize',8);
end

g=5; ceof=@(V)((1-g)*V).^(1/(1-g));
C=arrayfun(@(k) ceof(S(k).out.V),1:n,'uni',0); B=C{1};
for k=2:n, B=max(B,C{k}); end
ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
val=zeros(1,n);
for k=1:n
    d=(C{k}-B)./max(B,eps); d=d(isfinite(d)); val(k)=100*mean(d<-1e-3);
end
b=bar(ax,1:n,val,0.6,'FaceColor','flat','EdgeColor',[.3 .3 .3]);
for k=1:n, b.CData(k,:)=col(k,:); end
set(ax,'XTick',1:n,'XTickLabel',compose('%c',char(64+(1:n))));
ylabel(ax,'% of nodes more than 0.1% CE below the best arm');
xlabel(ax,'arm'); title(ax,'how often each arm is beaten','FontWeight','normal');

sgtitle(f,['Sweeping before the local solve versus patching afterwards. Renter, 12x12x8 cube, gh_n=3, 2000 paths. ' ...
  'A is the no-sweep baseline; B is what ships today.'],'FontWeight','normal','FontSize',11,'Interpreter','tex');
exportgraphics(f,fullfile(out_dir,'ordering_study.png'),'Resolution',140); close(f);
fprintf('figure written\n');
end
