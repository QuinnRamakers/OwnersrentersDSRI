function R = plot_case(cases, opts)
%PLOT_CASE  Solve a set of model variants and plot what actually matters.
%
%   R = plot_case(cases)
%   R = plot_case(cases, opts)
%
%   `cases` is a cell array of structs, each with a `name`, an optional `rung`
%   (default 2), and any p-fields to override after ablation_config has built
%   the rung:
%
%       c{1} = struct('name','base','rung',2);
%       c{2} = struct('name','no rent growth','rung',2,'mu_R_level',0);
%       plot_case(c)
%
%   Plots mean pi(age) and mean consumption(age) side by side, with every
%   VISIBLE direction reversal in pi marked. A reversal is a sign change in the
%   year-on-year move where the larger of the two legs exceeds opts.thresh
%   (default 0.005, about half a percentage point of pi): small enough to catch
%   what the eye sees on a plot, large enough to ignore numerical fuzz. Panel
%   (d) shows the equity policy against liquid wealth, so a move in the mean can
%   be attributed to the policy or to the population.
%
%   The reversal COUNT, not any single age, is the summary statistic. Anchoring
%   on one age hides a step that merely moved elsewhere when a parameter changed.

if nargin < 2 || isempty(opts), opts = struct(); end
if ~isfield(opts,'dims'),     opts.dims     = [16 12 10]; end
if ~isfield(opts,'gh_n'),     opts.gh_n     = 5; end
if ~isfield(opts,'N_sim'),    opts.N_sim    = 8000; end
if ~isfield(opts,'thresh'),   opts.thresh   = 0.005; end
if ~isfield(opts,'tag'),      opts.tag      = 'case'; end
if ~isfield(opts,'pol_ages'), opts.pol_ages = [60 70 80 90]; end

here = fileparts(mfilename('fullpath'));
addpath(fileparts(here), here); cd(fileparts(here));
if isempty(gcp('nocreate'))
    try, parpool('Threads'); catch, warning('plot_case:pool','no pool'); end
end

R = struct([]);
for k = 1:numel(cases)
    c = cases{k};
    rung  = 2;     if isfield(c,'rung'),     rung  = c.rung;     end
    owner = false; if isfield(c,'is_owner'), owner = c.is_owner; end
    gam   = 5;     if isfield(c,'gamma'),    gam   = c.gamma;    end
    [p,~] = ablation_config(rung, struct('dims',opts.dims,'gh_n',opts.gh_n, ...
                                         'gamma',gam,'is_owner',owner));
    f = setdiff(fieldnames(c), {'name','rung','is_owner','gamma'});
    for i = 1:numel(f), p.(f{i}) = c.(f{i}); end
    % Log moments for the stock, house and rent index are cached by params, so
    % overriding any level here has no effect until they are rebuilt.
    p.Rf      = 1 + p.r;
    p.sigma_S = sqrt(log(1 + (p.sigma_S_level/(1+p.r+p.mu_S_level))^2));
    p.mu_S    = log(1+p.r+p.mu_S_level) - 0.5*p.sigma_S^2;
    p.sigma_H = sqrt(log(1 + (p.sigma_H_level/(1+p.mu_H_level))^2));
    p.mu_H    = log(1+p.mu_H_level) - 0.5*p.sigma_H^2;
    p.sigma_R = sqrt(log(1 + (p.sigma_R_level/(1+p.mu_R_level))^2));
    p.mu_R    = log(1+p.mu_R_level) - 0.5*p.sigma_R^2;

    [~,mg,sl] = config.income_profile(p);
    profile = struct('mu_growth',mg,'sigma_l_log',sl,'p_surv',config.survival(p));
    sh  = grids.shock_grid(p);
    ap  = pension.annuity_price(p, profile, sh);
    sol = solver.solve(p, profile, sh, ap);
    ws  = warning('off','paths_lna:offgrid');
    sim = simulate.forward(p, profile, sol, ap, opts.N_sim, 12345, p.b0);
    warning(ws);

    n = min(size(sim.pi,2), p.T-1);
    e = struct();
    e.name = c.name; e.p = p; e.sol = sol;
    e.ages = sim.ages(1:n);
    e.pi   = mean(sim.pi(:,1:n),1);
    e.C    = mean(sim.C,1);
    e.Cage = sim.ages;
    e.XY   = median(sim.X(:,1:n) ./ max(sim.Y(:,1:n),eps), 1);
    e.diag = sim.diagnostics;
    [e.rev_ages, e.rev_size] = reversals(e.ages, e.pi, opts.thresh);
    % Consumption too, judged on a RELATIVE threshold: C is a level that varies
    % by orders of magnitude across the life cycle, so an absolute cut-off would
    % flag old-age noise and miss mid-life wobbles. 0.5% of the local level
    % matches what the eye picks out of a smooth hump.
    [e.revC_ages, e.revC_size] = reversals_rel(e.Cage, e.C, 0.005);
    if isempty(R), R = e; else, R(end+1) = e; end %#ok<AGROW>
end

nn = numel(R); cm = lines(max(nn,3));
fig = figure('Position',[40 40 1500 900],'Color','w');
tl  = tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');

ax = nexttile(tl,1); hold(ax,'on');
for k = 1:nn
    plot(ax,R(k).ages,R(k).pi,'-','Color',cm(k,:),'LineWidth',1.6, ...
        'DisplayName',R(k).name);
    if ~isempty(R(k).rev_ages)
        idx = ismember(R(k).ages, R(k).rev_ages);
        plot(ax,R(k).ages(idx),R(k).pi(idx),'v','Color',cm(k,:), ...
            'MarkerFaceColor',cm(k,:),'MarkerSize',6,'HandleVisibility','off');
    end
end
xline(ax,R(1).p.retirement_age,'--','Color',[.5 .5 .5],'HandleVisibility','off');
xlabel(ax,'age'); ylabel(ax,'mean share in stocks');
title(ax,'(a) Equity share  (markers = visible direction reversals)');
grid(ax,'on'); box(ax,'on');
legend(ax,'Location','best','FontSize',8,'Interpreter','none');

ax = nexttile(tl,2); hold(ax,'on');
for k = 1:nn
    plot(ax,R(k).Cage,R(k).C,'-','Color',cm(k,:),'LineWidth',1.6, ...
        'DisplayName',R(k).name);
end
xline(ax,R(1).p.retirement_age,'--','Color',[.5 .5 .5],'HandleVisibility','off');
xlabel(ax,'age'); ylabel(ax,'mean consumption');
title(ax,'(b) Consumption'); grid(ax,'on'); box(ax,'on');
legend(ax,'Location','best','FontSize',8,'Interpreter','none');

ax = nexttile(tl,3); hold(ax,'on');
for k = 1:nn
    d = [NaN diff(R(k).pi)];
    plot(ax,R(k).ages,d,'-','Color',cm(k,:),'LineWidth',1.3,'DisplayName',R(k).name);
end
yline(ax,0,'k-','HandleVisibility','off');
xline(ax,R(1).p.retirement_age,'--','Color',[.5 .5 .5],'HandleVisibility','off');
xlabel(ax,'age'); ylabel(ax,'year-on-year change in mean share');
title(ax,'(c) Year-on-year change  (a reversal crosses zero)');
grid(ax,'on'); box(ax,'on');

ax = nexttile(tl,4); hold(ax,'on');
e = R(1); pa = opts.pol_ages; cm2 = turbo(max(numel(pa),2));
lam = e.p.u1_grid(:); XY = (1-lam)./max(lam,eps); ok = XY <= 40;
for j = 1:numel(pa)
    t = pa(j) - e.p.age0 + 1;
    if t < 1 || t > e.p.T, continue; end
    plot(ax,XY(ok),squeeze(e.sol.pi_pol(ok,1,1,t)),'-','Color',cm2(j,:), ...
        'LineWidth',1.5,'DisplayName',sprintf('age %d',pa(j)));
end
xlabel(ax,'liquid wealth X/Y (years of income)'); ylabel(ax,'pi policy');
title(ax,sprintf('(d) Equity policy by age -- %s', e.name),'Interpreter','none');
ylim(ax,[-0.02 1.02]); grid(ax,'on'); box(ax,'on');
legend(ax,'Location','best','FontSize',8);

title(tl, opts.tag, 'FontWeight','bold','Interpreter','none');
out = fullfile(here, sprintf('fig_%s.png', opts.tag));
exportgraphics(fig,out,'Resolution',140);
fprintf('Wrote %s\n', out);

save(fullfile(here, sprintf('case_%s.mat', opts.tag)), 'R', 'opts', '-v7.3');

fprintf('\n%-20s %6s %6s   %s\n','case','pi_rev','C_rev','pi reversal ages (size)');
fprintf('%s\n', repmat('-',1,82));
for k = 1:nn
    e = R(k);
    fprintf('%-20s %6d %6d   ', e.name, numel(e.rev_ages), numel(e.revC_ages));
    for j = 1:numel(e.rev_ages)
        fprintf('%d(%+.3f) ', e.rev_ages(j), e.rev_size(j));
    end
    fprintf('\n');
end
fprintf('\npi reversal: sign change in the year-on-year move, larger leg > %.3f\n', opts.thresh);
fprintf('C reversal : same, on a 0.5%% relative threshold (C spans orders of magnitude)\n');
for k = 1:nn
    e = R(k);
    if ~isempty(e.revC_ages)
        fprintf('  %s consumption reverses at: ', e.name);
        fprintf('%d ', e.revC_ages); fprintf('\n');
    end
end
end

% =========================================================================
function [ages_out, sz] = reversals_rel(ages, v, rel)
%REVERSALS_REL  As reversals, but the threshold scales with the local level.
d = [NaN diff(v)];
ages_out = []; sz = [];
for i = 3:numel(v)
    a = d(i-1); b = d(i);
    lvl = max(abs(v(i)), eps);
    if isfinite(a) && isfinite(b) && sign(a) ~= sign(b) && a ~= 0 && b ~= 0 ...
       && max(abs(a),abs(b)) > rel * lvl
        ages_out(end+1) = ages(i);   %#ok<AGROW>
        sz(end+1)       = b;         %#ok<AGROW>
    end
end
end

function [ages_out, sz] = reversals(ages, v, thresh)
d = [NaN diff(v)];
ages_out = []; sz = [];
for i = 3:numel(v)
    a = d(i-1); b = d(i);
    if isfinite(a) && isfinite(b) && sign(a) ~= sign(b) && a ~= 0 && b ~= 0 ...
       && max(abs(a),abs(b)) > thresh
        ages_out(end+1) = ages(i);   %#ok<AGROW>
        sz(end+1)       = b;         %#ok<AGROW>
    end
end
end
