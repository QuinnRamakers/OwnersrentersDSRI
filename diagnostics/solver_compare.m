function solver_compare(out_dir)
%SOLVER_COMPARE  Does the per-node solver shortcut cost us anything?
%
%   One renter case, calibrated housing, at the same resolution the H1 sheets
%   use (20x20x12 = 4800 nodes, gh_n = 5, 6000 paths). Three solver settings,
%   nothing else changed:
%
%     A  warm  : grid_mode='none', use_refine=0   -- the production path. One
%                fmincon polish from the warm-start seed, no grid search, no
%                derivative-free refinement. This is what every H1 sheet used.
%     B  refine: grid_mode='none', use_refine=1   -- add the derivative-free
%                compass search around the fmincon point.
%     C  full  : grid_mode='full', use_refine=1   -- brute-force 41x41 (c,pi)
%                grid search for the seed, then fmincon, then refine.
%
%   If A, B, C agree the shortcut is free; where they part company is where the
%   single warm-started fmincon was getting stuck -- the accumulation phase is
%   the suspect.

if nargin < 1 || isempty(out_dir)
    out_dir = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad';
end
res = fullfile(out_dir, 'solver_compare.mat');

variants = {
    'A warm (production)',  'none', 0;
    'B refine',             'none', 1;
    'C full grid + refine', 'full', 1 };

S = struct('name',{},'grid_mode',{},'use_refine',{},'sec',{},'out',{});
if isfile(res), L = load(res); S = L.S; end
for i = 1:size(variants,1)
    if any(strcmp(variants{i,1}, {S.name})), continue; end
    fprintf('solving %-22s ...\n', variants{i,1});
    tic;
    o = run_variant(variants{i,2}, variants{i,3});
    sec = toc;
    S(end+1).name = variants{i,1};                                        %#ok<AGROW>
    S(end).grid_mode = variants{i,2}; S(end).use_refine = variants{i,3};
    S(end).sec = sec; S(end).out = o;
    save(res, 'S', '-v7.3');
    fprintf('   done in %.0f s\n', sec);
end
report(S);
make_fig(S, out_dir);
fprintf('\nresults saved to  %s\n', res);
end

% ------------------------------------------------------------------------
function o = run_variant(gm, ref)
p = config.params(); p.is_owner = false;      % renter, calibrated housing
p.grid_mode = gm; p.polish_ver = 2; p.use_refine = ref;
p.lambda_lo=0.0008; p.lambda_hi=0.44; p.grid_pow=1.6;
p.u2_lo=0.40; p.grid_pow_u2=1; p.u3_lo=0.02; p.u3_hi=0.98;
p = utility.build_state_grids(p, [20 20 12], 5);
[~,mg,sl]=config.income_profile(p);
pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(p);
sk=grids.shock_grid(p); an=pension.annuity_price(p,pf,sk);
sol=solver.solve_lifecycle_lna(p,pf,sk,an);
s=simulate.forward(p,pf,sol,an,6000,20260511,p.b0);
K = 1:size(s.tau_A,2); med=@(M) median(M,1,'omitnan');
o.ages = s.ages(K);
o.C    = med(s.C(:,K));
o.pi   = mean(s.pi(:,K),1,'omitnan');
o.X    = med(s.X(:,K));
o.fin  = med(s.X(:,K)+s.A(:,K));
o.Vsum = sol.V;                       % value function, for a direct welfare gap
end

% ------------------------------------------------------------------------
function report(S)
base = find(strcmp('A warm (production)', {S.name}), 1);
fprintf('\n%-22s %6s | median |dpi| vs A (accum 25-55 / ret 67-90) | max |dC/C|\n','variant','sec');
for i = 1:numel(S)
    o = S(i).out; a = o.ages; ao = S(base).out;
    acc = a>=25 & a<=55; ret = a>=67 & a<=90;
    dpi = abs(o.pi - ao.pi); dC = abs(o.C - ao.C)./max(ao.C,eps);
    fprintf('%-22s %6.0f |            %.4f  /  %.4f            |  %.4f\n', ...
        S(i).name, S(i).sec, median(dpi(acc)), median(dpi(ret)), max(dC));
    if i==base
        vg = 0;
    else
        vg = max(abs(o.Vsum(:) - ao.Vsum(:)) ./ max(abs(ao.Vsum(:)), 1e-9));
    end
    fprintf('%-22s        | max relative value-function gap vs A: %.3g\n', '', vg);
end
end

% ------------------------------------------------------------------------
function make_fig(S, out_dir)
col = [.20 .35 .75; .85 .33 .10; .30 .60 .35];
f = figure('Position',[40 40 1500 460],'Color','w','Visible','off');
tl = tiledlayout(f,1,3,'Padding','compact','TileSpacing','compact');

ax = nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
for i=1:numel(S), plot(ax,S(i).out.ages,100*S(i).out.pi,'Color',col(i,:),'LineWidth',1.8); end
xline(ax,67,'-','Color',[.4 .4 .4]); xlim(ax,[25 95]); ylim(ax,[0 100]);
xlabel(ax,'age'); ylabel(ax,'% in equity'); title(ax,'liquid equity share','FontWeight','normal');
legend(ax,{S.name},'Box','off','Location','south','FontSize',8);

ax = nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
for i=1:numel(S), plot(ax,S(i).out.ages,S(i).out.C/1000,'Color',col(i,:),'LineWidth',1.8); end
xline(ax,67,'-','Color',[.4 .4 .4]); xlim(ax,[25 95]);
xlabel(ax,'age'); ylabel(ax,'EUR000 / yr'); title(ax,'consumption','FontWeight','normal');

ax = nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
base = find(strcmp('A warm (production)', {S.name}),1);
for i=1:numel(S)
    plot(ax,S(i).out.ages,100*(S(i).out.pi - S(base).out.pi),'Color',col(i,:),'LineWidth',1.8);
end
yline(ax,0,'-','Color',[.6 .6 .6]); xline(ax,67,'-','Color',[.4 .4 .4]); xlim(ax,[25 95]);
xlabel(ax,'age'); ylabel(ax,'equity share, pp vs A'); title(ax,'difference from production path','FontWeight','normal');

sgtitle(f,['renter, calibrated housing -- does the single warm-started fmincon cost anything? ' ...
           '4800 nodes, gh_n=5, 6000 paths'],'FontWeight','normal','FontSize',12,'Interpreter','none');
fp = fullfile(out_dir,'solver_compare.png');
exportgraphics(f, fp, 'Resolution',140); close(f);
fprintf('figure saved to  %s\n', fp);
end
