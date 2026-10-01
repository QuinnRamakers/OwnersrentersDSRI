% Quick test: labour income over non-labour wealth, x = Y/F, F = X + A + H.
%
% x = lam/(1-lam), so this is the same coordinate as the current Y/W under a
% monotone map. That makes a strong prediction worth checking rather than
% asserting: place the nodes at the exact IMAGES of the current nodes and the
% solve must be bit-identical. If it is not, either the identity or my plumbing
% is wrong. Only after that does the interesting run mean anything -- a grid laid
% out evenly in x, where the only thing that has changed is where the nodes fall.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear; clc
o = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
dims = [14 14 10];

    function [s, sm, q] = run_one(q, dims)
        [~,mg,sl] = config.income_profile(q);
        pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(q);
        sk = grids.shock_grid(q); an = pension.annuity_price(q, pf, sk);
        s  = solver.solve_lifecycle_lna(q, pf, sk, an);
        sm = simulate.forward(q, pf, s, an, 4000, 20260511, q.b0);
    end

base = @() setfield(setfield(setfield(setfield(config.params(), ...
        'is_owner', false), 'grid_mode','none'), 'polish_ver',2), 'use_refine', false);

% ---- reference: the current chart -----------------------------------------
a = base(); a = utility.build_state_grids(a, dims, 3);
[sa, sma] = run_one(a, dims);

% ---- 1. same physical nodes, expressed as Y/F: must be bit-identical ------
b = base(); b.coord1 = 'yf'; b = utility.build_state_grids(b, dims, 3);
b.u1_grid = a.u1_grid ./ (1 - a.u1_grid);      % exact images of the u1 nodes
b.u2_grid = a.u2_grid; b.u3_grid = a.u3_grid;
b.N_u1 = numel(b.u1_grid); b.N_u2 = numel(b.u2_grid); b.N_u3 = numel(b.u3_grid);
[sb, smb] = run_one(b, dims);
fprintf('1. Y/F on the IMAGES of the current nodes -- prediction: bit-identical\n');
fprintf('   isequal(V) = %d   max|dV| = %g   max|dc| = %g   max|dpi| = %g\n\n', ...
    isequal(sa.V, sb.V), max(abs(sa.V(:)-sb.V(:))), ...
    max(abs(sa.c_pol(:)-sb.c_pol(:))), max(abs(sa.pi_pol(:)-sb.pi_pol(:))));

% ---- 2. a grid laid out evenly in Y/F, same node count --------------------
c = base(); c.coord1 = 'yf'; c = utility.build_state_grids(c, dims, 3);
[sc, smc] = run_one(c, dims);
fprintf('2. Y/F with its own uniform grid, %d nodes, axis [%.4f, %.4f]\n', ...
    numel(c.u1_grid), c.u1_grid(1), c.u1_grid(end));
fprintf('   in Y/W terms that is [%.4f, %.4f] against the current [%.4f, %.4f]\n\n', ...
    c.u1_grid(1)/(1+c.u1_grid(1)), c.u1_grid(end)/(1+c.u1_grid(end)), ...
    a.u1_grid(1), a.u1_grid(end));

gap=@(x,y,i) 100*mean(abs(y(i)-x(i))./max(abs(x(i)),eps));
Ca=median(sma.C,1,'omitnan'); Cc=median(smc.C,1,'omitnan');
Pa=mean(sma.pi,1,'omitnan');  Pc=mean(smc.pi,1,'omitnan');
d2=@(v) 100*mean(abs(diff(v,2)))/mean(abs(v));
fprintf('%-22s %10s %10s\n','', 'Y/W', 'Y/F uniform');
fprintf('%-22s %10.0f %10.0f\n','C at 25', Ca(1), Cc(1));
fprintf('%-22s %10.0f %10.0f\n','C at 45', Ca(21), Cc(21));
fprintf('%-22s %10.0f %10.0f\n','C at 70', Ca(46), Cc(46));
fprintf('%-22s %10.2f %10.2f\n','pi at 25', Pa(1), Pc(1));
fprintf('%-22s %10.2f %10.2f\n','pi at 45', Pa(21), Pc(21));
fprintf('%-22s %9.2f%% %9.2f%%\n','|d2 pi| ages 65-84', d2(Pa(41:60)), d2(Pc(41:60)));
fprintf('%-22s %10d %10d\n','off-grid lookups', sma.diagnostics.n_offgrid_u1, smc.diagnostics.n_offgrid_u1);
fprintf('\ndifference, ages 25-39 / 40-69 / 70+:  %.1f%% / %.1f%% / %.1f%%\n', ...
    gap(Ca,Cc,1:15), gap(Ca,Cc,16:45), gap(Ca,Cc,46:75));

% nodes under the population, both layouts
L = load([o 'occ_sim.mat']); sim = L.sim; pp = L.p;
u1p = sim.Y ./ sim.W; tt = 3:pp.T-1;
lo = prctile(u1p(:,tt),1,1); hi = prctile(u1p(:,tt),99,1);
cnt = @(g) arrayfun(@(t) sum(g>=lo(t) & g<=hi(t)), 1:numel(tt));
ga = a.u1_grid; gc = c.u1_grid./(1+c.u1_grid);     % both in Y/W terms
fprintf('\nnodes under the population on the first axis (mean / worst / starved ages)\n');
fprintf('%-22s %6.1f %6d %6d\n','Y/W uniform',   mean(cnt(ga)), min(cnt(ga)), sum(cnt(ga)<2));
fprintf('%-22s %6.1f %6d %6d\n','Y/F uniform',   mean(cnt(gc)), min(cnt(gc)), sum(cnt(gc)<2));

save([o 'test_yf.mat'],'Ca','Cc','Pa','Pc','ga','gc');
f=figure('Position',[100 100 1180 400],'Color','w');
tl=tiledlayout(f,1,3,'Padding','compact','TileSpacing','compact');
ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
plot(ax,sma.ages(1:75),Ca(1:75),'Color',[.92 .41 .20],'LineWidth',1.6);
plot(ax,smc.ages(1:75),Cc(1:75),'Color',[.16 .47 .84],'LineWidth',1.6);
xline(ax,67,':','Color',[.5 .5 .5]); xlim(ax,[25 99]); xlabel(ax,'age');
ylabel(ax,'median consumption'); title(ax,'consumption','FontWeight','normal');
legend(ax,{'Y/W uniform','Y/F uniform'},'Location','southeast','Box','off');
ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
plot(ax,sma.ages(1:75),Pa(1:75),'Color',[.92 .41 .20],'LineWidth',1.6);
plot(ax,smc.ages(1:75),Pc(1:75),'Color',[.16 .47 .84],'LineWidth',1.6);
xline(ax,67,':','Color',[.5 .5 .5]); xlim(ax,[25 99]); ylim(ax,[0 1.05]);
xlabel(ax,'age'); title(ax,'equity share','FontWeight','normal');
ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
fill(ax,[sim.ages(tt) fliplr(sim.ages(tt))],[lo fliplr(hi)],[.5 .5 .5],'FaceAlpha',.18,'EdgeColor','none');
for i=1:numel(ga), yline(ax,ga(i),'-','Color',[.92 .41 .20 .6]); end
for i=1:numel(gc), yline(ax,gc(i),'-','Color',[.16 .47 .84 .6]); end
xlim(ax,[27 99]); ylim(ax,[0 0.62]); xlabel(ax,'age'); ylabel(ax,'u1 = Y/W');
title(ax,'where the nodes land (grey = population)','FontWeight','normal');
sgtitle(f,'Y/F is the same coordinate as Y/W. Only the node placement differs.','FontWeight','normal','FontSize',12);
exportgraphics(f,[o 'fig_test_yf.png'],'Resolution',150);
disp('done');
