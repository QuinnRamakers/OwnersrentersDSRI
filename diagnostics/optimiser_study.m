function optimiser_study(out_dir)
%OPTIMISER_STUDY  Why does the derivative-free refinement change the answer,
%   and can optimiser settings reconcile it without paying for the refinement?
%
%   Diagnosis being tested: in skip_tensor mode the per-node problem gets ONE
%   fmincon call seeded from the warm start. The continuation value is linear
%   in z on the cube, so the objective in pi is piecewise linear with kinks at
%   cell faces. Central finite differences with the default step (~1.5e-8)
%   sample inside one linear piece, so fmincon sees a slope that says nothing
%   about the next piece and stops at its seed. refine_cpi_u looks better only
%   because its first round scans pi over the whole [0,1] on 21 points -- a
%   global sweep, not a local search.
%
%   If that is right, then anything that makes the search see across cells --
%   a finite-difference step of the order of the grid spacing, or extra pi
%   seeds -- should close most of the gap at a fraction of the refinement cost.
%   If it is wrong, none of them will move and the gap is something else.
%
%   Reduced cube (12x12x8, gh_n=3, 2000 paths) so the whole sweep is minutes.
%   Everything is measured against the refinement arm, which is the reference.

if nargin < 1 || isempty(out_dir)
    out_dir = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad';
end
res = fullfile(out_dir,'optimiser_study.mat');

% name                    refine  algo             fd_step   pi_starts
V = { 'A baseline',            0, 'active-set',    [],       []
      'B refine (reference)',  1, 'active-set',    [],       []
      'FD step 1e-3',          0, 'active-set',    1e-3,     []
      'FD step 1e-2',          0, 'active-set',    1e-2,     []
      'pi multistart x5',      0, 'active-set',    [],       [0;.25;.5;.75;1]
      'sqp',                   0, 'sqp',           [],       []
      'interior-point',        0, 'interior-point',[],       []
      'FD 1e-2 + multistart',  0, 'active-set',    1e-2,     [0;.25;.5;.75;1] };

S = struct('name',{},'sec',{},'out',{});
if isfile(res), L = load(res); S = L.S; end
for i = 1:size(V,1)
    if any(strcmp(V{i,1}, {S.name})), continue; end
    fprintf('solving %-24s ...\n', V{i,1});
    tic; o = run_one(V{i,2}, V{i,3}, V{i,4}, V{i,5}); sec = toc;
    S(end+1).name = V{i,1}; S(end).sec = sec; S(end).out = o;            %#ok<AGROW>
    save(res,'S','-v7.3');
    fprintf('   %.0f s\n', sec);
end
report(S);
make_fig(S, out_dir);
end

% ------------------------------------------------------------------------
function o = run_one(ref, algo, fd, pis)
p = config.params(); p.is_owner = false;
p.grid_mode='none'; p.polish_ver=2; p.use_refine=ref;
p.polish_algo = algo;
if ~isempty(fd),  p.fd_step   = fd;  end
if ~isempty(pis), p.pi_starts = pis; end
p.lambda_lo=0.0008; p.lambda_hi=0.44; p.grid_pow=1.6;
p.u2_lo=0.40; p.grid_pow_u2=1; p.u3_lo=0.02; p.u3_hi=0.98;
p = utility.build_state_grids(p, [12 12 8], 3);
[~,mg,sl]=config.income_profile(p);
pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(p);
sk=grids.shock_grid(p); an=pension.annuity_price(p,pf,sk);
sol=solver.solve_lifecycle_lna(p,pf,sk,an);
s=simulate.forward(p,pf,sol,an,2000,20260511,p.b0);
K = 1:size(s.tau_A,2);
o.ages = s.ages(K);
o.pi   = mean(s.pi(:,K),1,'omitnan');
o.C    = median(s.C(:,K),1,'omitnan');
o.X    = median(s.X(:,K),1,'omitnan');
o.V    = sol.V;
o.pipol= sol.pi_pol;
end

% ------------------------------------------------------------------------
function report(S)
g = 5; ref = find(strcmp('B refine (reference)', {S.name}),1);
ce = @(V) ((1-g)*V).^(1/(1-g));
cr = ce(S(ref).out.V); a = S(ref).out.ages;
fprintf('\nCE shortfall vs the refinement arm (negative = worse than reference)\n');
fprintf('%-24s %7s %11s %11s %11s %9s\n','variant','sec','median','p10','frac<-1%','pi RMSE');
for i = 1:numel(S)
    c = ce(S(i).out.V);
    d = (c - cr)./max(cr,eps); d = d(isfinite(d));
    dpi = sqrt(mean((S(i).out.pi - S(ref).out.pi).^2));
    fprintf('%-24s %7.0f %+10.2e %+10.2e %9.1f%% %9.4f\n', ...
        S(i).name, S(i).sec, median(d), prctile(d,10), 100*mean(d<-0.01), dpi);
end
fprintf('\nsimulated equity share by age\n%-24s', 'variant');
sh = [25 30 40 55 67 80 90];
fprintf('%7d', sh); fprintf('\n');
for i = 1:numel(S)
    fprintf('%-24s', S(i).name);
    for ag = sh, fprintf('%7.3f', S(i).out.pi(a==ag)); end
    fprintf('\n');
end
end

% ------------------------------------------------------------------------
function make_fig(S, out_dir)
ref = find(strcmp('B refine (reference)', {S.name}),1);
a = S(ref).out.ages; n = numel(S);
cols = lines(n);
f = figure('Position',[40 40 1500 520],'Color','w','Visible','off');
tl = tiledlayout(f,1,2,'Padding','compact','TileSpacing','compact');

ax = nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
for i=1:n
    lw = 2.4*(i==ref) + 1.4*(i~=ref);
    ls = '-'; if i==1, ls='--'; end
    plot(ax,a,100*S(i).out.pi,'Color',cols(i,:),'LineWidth',lw,'LineStyle',ls);
end
xline(ax,67,'-','Color',[.4 .4 .4]); xlim(ax,[25 95]); ylim(ax,[0 100]);
xlabel(ax,'age'); ylabel(ax,'% of liquid savings in equity');
title(ax,'equity share by optimiser setting','FontWeight','normal');
legend(ax,{S.name},'Box','off','Location','southoutside','NumColumns',2,'FontSize',8);

ax = nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
for i=1:n
    plot(ax,a,100*(S(i).out.pi - S(ref).out.pi),'Color',cols(i,:),'LineWidth',1.6);
end
yline(ax,0,'-','Color',[.5 .5 .5]); xline(ax,67,'-','Color',[.4 .4 .4]); xlim(ax,[25 95]);
xlabel(ax,'age'); ylabel(ax,'equity share minus reference (pp)');
title(ax,'gap to the refinement arm','FontWeight','normal');

sgtitle(f,['Can optimiser settings reproduce what the derivative-free refinement finds? ' ...
           'renter, 12x12x8 cube, gh_n=3, 2000 paths'],'FontWeight','normal','FontSize',12,'Interpreter','none');
fp = fullfile(out_dir,'optimiser_study.png');
exportgraphics(f, fp,'Resolution',140); close(f);
fprintf('\nfigure: %s\n', fp);
end
