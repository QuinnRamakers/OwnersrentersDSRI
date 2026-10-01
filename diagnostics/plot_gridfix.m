function plot_gridfix(opts)
%PLOT_GRIDFIX  Before and after the lambda-grid ceiling fix, on the CGM core.
%
%   Three solves of ablation rung 0:
%     before   lambda capped at 0.98, the behaviour that shipped
%     after    lambda spans the full axis (utility.build_state_grids)
%     after10  the same fix at CGM's own risk aversion of 10
%
%   The cap put households that had run their wealth down off the top of the
%   grid, where the policy was extrapolated from the edge with no warning. The
%   panels show what that did to the equity share and what the fix restores.
%   CGM (2005) Figure 3C is marked as reference points, read off the printed
%   figure rather than digitised, so treat them as approximate.

if nargin < 1 || isempty(opts), opts = struct(); end
if ~isfield(opts,'dims'),  opts.dims  = [30 10 8]; end
if ~isfield(opts,'gh_n'),  opts.gh_n  = 5; end
if ~isfield(opts,'N_sim'), opts.N_sim = 6000; end

here = fileparts(mfilename('fullpath'));
addpath(fileparts(here), here); cd(fileparts(here));
if isempty(gcp('nocreate')), try, parpool('Threads'); catch, end, end

specs = { 'before', 5, 0.98
          'after',  5, []
          'after10',10, [] };
R = struct([]);
for k = 1:size(specs,1)
    [p,~] = ablation_config(0, struct('dims',opts.dims,'gh_n',opts.gh_n, ...
                                      'gamma',specs{k,2}));
    if ~isempty(specs{k,3})
        p.lambda_hi = specs{k,3};
        p = utility.build_state_grids(p, opts.dims, opts.gh_n);
    end
    [~,mg,sl] = config.income_profile(p);
    profile = struct('mu_growth',mg,'sigma_l_log',sl,'p_surv',config.survival(p));
    sh = grids.shock_grid(p); ap = pension.annuity_price(p, profile, sh);
    sol = solver.solve(p, profile, sh, ap);
    ws = warning('off','paths_lna:offgrid');
    sim = simulate.forward(p, profile, sol, ap, opts.N_sim, 12345, p.b0);
    warning(ws);

    n = min(size(sim.pi,2), p.T-1);
    e = struct();
    e.name = specs{k,1}; e.gamma = p.gamma;
    e.u1hi = max(p.u1_grid);
    e.ages = sim.ages(1:n);
    e.pi   = mean(sim.pi(:,1:n),1);
    e.frac_lo = mean(sim.pi(:,1:n) < 0.5, 1);
    e.offgrid = mean(sim.lambda(:,1:n) > max(p.u1_grid) + 1e-12, 1);
    % policy at the poorest node the grid carries
    e.pol_ages = p.age0 : p.age0+p.T-1;
    e.pol_edge = squeeze(sol.pi_pol(end,1,1,:)).';
    e.XY_edge  = (1-max(p.u1_grid))/max(p.u1_grid);
    e.diag = sim.diagnostics;
    if isempty(R), R = e; else, R(end+1) = e; end %#ok<AGROW>
end

C_BEF = [0.85 0.33 0.10]; C_AFT = [0.00 0.45 0.74]; C_G10 = [0.20 0.60 0.25];
col = {C_BEF, C_AFT, C_G10};
fig = figure('Position',[40 40 1500 830],'Color','w');
tl = tiledlayout(fig,2,3,'TileSpacing','compact','Padding','compact');

ax = nexttile(tl,1); hold(ax,'on');
for k=1:2
    plot(ax,R(k).ages,R(k).pi,'-','Color',col{k},'LineWidth',1.8, ...
        'DisplayName',sprintf('%s (lambda_hi=%.2f)',R(k).name,R(k).u1hi));
end
xline(ax,67,'--','Color',[.5 .5 .5],'HandleVisibility','off');
xlabel(ax,'age'); ylabel(ax,'mean \pi'); ylim(ax,[0.6 1.02]); xlim(ax,[60 100]);
title(ax,'(a) Equity share, retirement onward'); grid(ax,'on'); box(ax,'on');
legend(ax,'Location','southwest','FontSize',8);

ax = nexttile(tl,2); hold(ax,'on');
for k=1:2
    plot(ax,R(k).pol_ages,R(k).pol_edge,'-','Color',col{k},'LineWidth',1.8);
end
xlabel(ax,'age'); ylabel(ax,'\pi at the poorest grid node');
title(ax,sprintf('(b) Policy at X/Y = %.3f',R(1).XY_edge));
ylim(ax,[-0.02 1.05]); xlim(ax,[70 100]); grid(ax,'on'); box(ax,'on');
text(ax,72,0.30,'collapse to 0.168','Color',C_BEF,'FontSize',8);

ax = nexttile(tl,3); hold(ax,'on');
for k=1:2
    plot(ax,R(k).ages,100*R(k).offgrid,'-','Color',col{k},'LineWidth',1.8);
end
xlabel(ax,'age'); ylabel(ax,'% households off the grid');
title(ax,'(c) Households beyond \lambda_{hi}'); xlim(ax,[80 100]);
grid(ax,'on'); box(ax,'on');

ax = nexttile(tl,4); hold(ax,'on');
for k=1:2
    plot(ax,R(k).ages,100*R(k).frac_lo,'-','Color',col{k},'LineWidth',1.8);
end
xlabel(ax,'age'); ylabel(ax,'% with \pi < 0.5');
title(ax,'(d) Share of households at a low \pi'); xlim(ax,[80 100]);
grid(ax,'on'); box(ax,'on');

ax = nexttile(tl,5); hold(ax,'on');
plot(ax,R(2).ages,R(2).pi,'-','Color',C_AFT,'LineWidth',1.8,'DisplayName','\gamma = 5');
plot(ax,R(3).ages,R(3).pi,'-','Color',C_G10,'LineWidth',1.8,'DisplayName','\gamma = 10 (CGM)');
plot(ax,[65 97],[0.49 0.65],'k^','MarkerFaceColor','k','MarkerSize',6, ...
    'DisplayName','CGM Fig 3C (approx)');
xline(ax,67,'--','Color',[.5 .5 .5],'HandleVisibility','off');
xlabel(ax,'age'); ylabel(ax,'mean \pi'); ylim(ax,[0.3 1.02]);
title(ax,'(e) After the fix, vs CGM benchmark'); grid(ax,'on'); box(ax,'on');
legend(ax,'Location','southwest','FontSize',8);

ax = nexttile(tl,6); axis(ax,'off');
d1 = R(1).diag; d2 = R(2).diag;
txt = {
 'What changed'
 ''
 sprintf('lambda_hi:  %.2f  ->  %.2f', R(1).u1hi, R(2).u1hi)
 sprintf('off-grid lookups:  %d  ->  %d', ...
     d1.n_offgrid_u1, d2.n_offgrid_u1)
 sprintf('mean pi at 94:  %.3f  ->  %.3f', ...
     R(1).pi(R(1).ages==94), R(2).pi(R(2).ages==94))
 sprintf('pct with pi<0.5 at 94:  %.1f  ->  %.1f', ...
     100*R(1).frac_lo(R(1).ages==94), 100*R(2).frac_lo(R(2).ages==94))
 ''
 sprintf('monotone 86-98:  %s  ->  %s', ...
     mono(R(1)), mono(R(2)))
 ''
 'Production (h_mult=4) is unaffected:'
 'housing bounds lambda near 0.35, well'
 'inside the grid: 0 off-grid lookups.'
 };
text(ax,0.02,0.95,txt,'VerticalAlignment','top','FontSize',10,'Interpreter','none','FontName','Consolas');

title(tl,'CGM core (rung 0): the lambda-grid ceiling and its fix','FontWeight','bold');
out = fullfile(here,'fig_gridfix.png');
exportgraphics(fig,out,'Resolution',140);
fprintf('Wrote %s\n', out);
save(fullfile(here,'gridfix.mat'),'R','opts','-v7.3');

for k=1:numel(R)
    fprintf('\n%-8s gamma=%2g lambda_hi=%.3f offgrid=%d\n', ...
        R(k).name, R(k).gamma, R(k).u1hi, R(k).diag.n_offgrid_u1);
    fprintf('  pi: ');
    for a=[67 75 85 90 92 94 96 99]
        fprintf('%d:%.3f ', a, R(k).pi(R(k).ages==a));
    end
    fprintf('\n  monotone 86-98: %s\n', mono(R(k)));
end
end

function s = mono(e)
d = e.pi(e.ages>=86 & e.ages<=98);
if all(diff(d) > -0.005), s = 'yes'; else, s = 'no'; end
end
