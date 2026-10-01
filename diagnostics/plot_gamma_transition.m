function plot_gamma_transition(opts)
%PLOT_GAMMA_TRANSITION  Is the retirement kink visible at CGM's risk aversion?
%
%   The claim under test: the retirement-transition kink in rung 0 is a
%   gamma = 5 amplification of a mechanism CGM share, and at their gamma = 10 it
%   is too small to see. Panel (a) reproduces their Figure 3C format (mean with
%   5th and 95th percentiles) so it can be held against the paper directly.
%   Panels (b) and (c) zoom on the transition using the SAME y-axis SPAN for
%   both risk aversions, so the visual comparison is fair despite the levels
%   differing. Panel (d) plots the year-on-year change, which is scale-free and
%   makes any sign reversal explicit.

if nargin < 1 || isempty(opts), opts = struct(); end
if ~isfield(opts,'dims'),  opts.dims  = [30 10 8]; end
if ~isfield(opts,'gh_n'),  opts.gh_n  = 5; end
if ~isfield(opts,'N_sim'), opts.N_sim = 8000; end

here = fileparts(mfilename('fullpath'));
addpath(fileparts(here), here); cd(fileparts(here));
if isempty(gcp('nocreate')), try, parpool('Threads'); catch, end, end

G = [5 10]; R = struct([]);
for k = 1:2
    [p,~] = ablation_config(0, struct('dims',opts.dims,'gh_n',opts.gh_n,'gamma',G(k)));
    [~,mg,sl] = config.income_profile(p);
    profile = struct('mu_growth',mg,'sigma_l_log',sl,'p_surv',config.survival(p));
    sh = grids.shock_grid(p); ap = pension.annuity_price(p, profile, sh);
    sol = solver.solve(p, profile, sh, ap);
    sim = simulate.forward(p, profile, sol, ap, opts.N_sim, 12345, p.b0);
    n = min(size(sim.pi,2), p.T-1);
    e = struct('gamma',G(k),'ages',sim.ages(1:n), ...
               'pi',mean(sim.pi(:,1:n),1), ...
               'p5',prctile(sim.pi(:,1:n),5,1), ...
               'p95',prctile(sim.pi(:,1:n),95,1), ...
               'ret',p.retirement_age);
    if isempty(R), R = e; else, R(end+1) = e; end %#ok<AGROW>
end

fig = figure('Position',[40 40 1480 780],'Color','w');
tl = tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');

% (a) CGM Figure 3C format, gamma = 10
ax = nexttile(tl,1); hold(ax,'on'); e = R(2);
plot(ax,e.ages,e.pi ,'k-' ,'LineWidth',1.6,'DisplayName','Mean');
plot(ax,e.ages,e.p5 ,'k-.','LineWidth',1.0,'DisplayName','5th percentile');
plot(ax,e.ages,e.p95,'k:' ,'LineWidth',1.0,'DisplayName','95th percentile');
xlim(ax,[20 100]); ylim(ax,[0 1]); xticks(ax,20:5:100);
xlabel(ax,'Age'); ylabel(ax,'share in stocks');
title(ax,'(a) Ours, gamma = 10 -- same format as CGM Figure 3C');
grid(ax,'on'); box(ax,'on'); legend(ax,'Location','southwest','FontSize',8);

SPAN = 0.12;   % identical y-span in (b) and (c) so the eye compares fairly
for k = 1:2
    ax = nexttile(tl,1+k); hold(ax,'on'); e = R(k);
    m = e.ages>=58 & e.ages<=78;
    ctr = mean(e.pi(m));
    plot(ax,e.ages(m),e.pi(m),'-o','Color',[0.00 0.45 0.74], ...
        'MarkerSize',3,'LineWidth',1.6);
    xline(ax,e.ret,'--','Color',[.5 .5 .5]);
    xline(ax,e.ret-1,':','Color',[.85 .33 .10]);
    ylim(ax,[ctr-SPAN/2 ctr+SPAN/2]); xlim(ax,[58 78]);
    xlabel(ax,'age'); ylabel(ax,'mean share in stocks');
    title(ax,sprintf('(%c) transition zoom, gamma = %g   [y-span %.2f both]', ...
        'b'+k-1, e.gamma, SPAN));
    grid(ax,'on'); box(ax,'on');
    d = diff(e.pi(m));
    text(ax,59,ctr+SPAN/2-0.012, ...
        sprintf('largest reversal %+.4f', min(d)),'FontSize',9);
end

% (d) year-on-year change: scale-free, reversal is a sign flip
ax = nexttile(tl,4); hold(ax,'on');
cols = {[0.00 0.45 0.74],[0.20 0.60 0.25]};
for k = 1:2
    e = R(k); m = e.ages>=58 & e.ages<=78;
    a = e.ages(m); d = [NaN diff(e.pi(m))];
    plot(ax,a,d,'-o','Color',cols{k},'MarkerSize',3,'LineWidth',1.5, ...
        'DisplayName',sprintf('gamma = %g',e.gamma));
end
yline(ax,0,'k-'); xline(ax,R(1).ret,'--','Color',[.5 .5 .5],'HandleVisibility','off');
xline(ax,R(1).ret-1,':','Color',[.85 .33 .10],'HandleVisibility','off');
xlabel(ax,'age'); ylabel(ax,'change in mean share vs previous age');
title(ax,'(d) Year-on-year change (a kink is a sign flip)');
grid(ax,'on'); box(ax,'on'); legend(ax,'Location','southwest','FontSize',8);

title(tl,'Retirement transition at gamma = 5 vs CGM gamma = 10 (ablation rung 0)', ...
    'FontWeight','bold');
out = fullfile(here,'fig_gamma_transition.png');
exportgraphics(fig,out,'Resolution',140);
fprintf('Wrote %s\n', out);

for k = 1:2
    e = R(k); m = e.ages>=62 & e.ages<=72; d = diff(e.pi(m));
    fprintf('\ngamma = %g\n  pi 62..72: ', e.gamma);
    fprintf('%.4f ', e.pi(m));
    fprintf('\n  largest reversal %+.5f | reversal as %% of level %.2f%%\n', ...
        min(d), 100*abs(min(d))/mean(e.pi(m)));
end
end
