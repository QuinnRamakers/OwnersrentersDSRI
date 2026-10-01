% A/B with the derivative-free refinement ON (the solver default).
%
% Every A/B so far ran use_refine = false, which I set for speed. That
% refinement exists to clear interpolation-kink ridges that fmincon's finite
% differences step over, and the kappa scheme changes the objective's shape --
% it is now an interpolant times an exact affine function -- so switching it off
% may penalise kappa specifically. This is the confound, tested rather than
% argued. Produces real MATLAB figures.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
o = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
objs = {'z','kappa'}; refs = [false true];
S = cell(2,2);
for ir = 1:2
  for io = 1:2
    p = config.params(); p.is_owner = false;
    p.grid_mode = 'none'; p.polish_ver = 2; p.use_refine = refs(ir);
    p.interp_object = objs{io};
    p = utility.build_state_grids(p, [14 14 10], 3);
    [~, mg, sl] = config.income_profile(p);
    prof.mu_growth = mg; prof.sigma_l_log = sl; prof.p_surv = config.survival(p);
    shk = grids.shock_grid(p); ann = pension.annuity_price(p, prof, shk);
    tic; sol = solver.solve_lifecycle_lna(p, prof, shk, ann); el = toc;
    sim = simulate.forward(p, prof, sol, ann, 4000, 20260511, p.b0);
    r.obj = objs{io}; r.refine = refs(ir); r.sec = el; r.ages = sim.ages;
    r.C = median(sim.C,1,'omitnan'); r.pi = mean(sim.pi,1,'omitnan');
    r.LW = median(sim.LW,1,'omitnan'); r.X = median(sim.X,1,'omitnan');
    F = p.phi_floor*sim.Y(:,1:size(sim.C,2));
    r.fl = 100*mean(sim.LW(:,1:size(F,2))<=F,1);
    % roughness of the simulated profile: mean |second difference| / mean level
    d2 = @(v) mean(abs(diff(v,2)))/mean(abs(v));
    r.rough_C = 100*d2(r.C(1:75)); r.rough_pi = 100*d2(r.pi(1:75));
    S{ir,io} = r;
    fprintf('%-6s refine=%d %5.0fs | C25=%6.0f C65=%6.0f | pi25=%.2f | rough C %.2f%% pi %.2f%%\n', ...
        objs{io}, refs(ir), el, r.C(1), r.C(41), r.pi(1), r.rough_C, r.rough_pi);
  end
end
save([o 'ab_refine.mat'],'S');

lab = {'linear-z, no refine','kappa, no refine','linear-z, refine ON','kappa, refine ON'};
col = [0.92 0.41 0.20; 0.16 0.47 0.84; 0.92 0.41 0.20; 0.16 0.47 0.84];
sty = {'--','--','-','-'};
ord = [1 2; 3 4];
f = figure('Position',[100 100 1180 820],'Color','w');
tl = tiledlayout(f,2,2,'Padding','compact','TileSpacing','compact');
flds = {'C','pi','LW','fl'};
ttl  = {'Median consumption (EUR/yr)','Mean equity share of liquid wealth', ...
        'Median liquid resources LW (EUR)','% of households at the floor'};
for k = 1:4
    ax = nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha = 0.12;
    n = 0;
    for ir = 1:2, for io = 1:2
        n = n+1; r = S{ir,io}; v = r.(flds{k});
        plot(ax, r.ages(1:numel(v)), v, sty{ord(ir,io)}, 'Color', col(ord(ir,io),:), ...
             'LineWidth', 1.0 + 1.0*(ir==2));
    end, end
    xline(ax, 67, ':', 'Color', [.5 .5 .5]);
    title(ax, ttl{k}, 'FontWeight','normal'); xlabel(ax,'age'); xlim(ax,[25 99]);
end
lg = legend(nexttile(tl,1), lab, 'Location','southeast','Box','off');
sgtitle(f, 'Interpolated object x derivative-free refinement, renter, 2560 nodes, gh\_n=3, 4000 paths', ...
        'FontWeight','normal','FontSize',12);
exportgraphics(f, [o 'fig_ab_refine.png'], 'Resolution', 150);
fprintf('\nRoughness of the simulated profiles (mean |2nd difference| / mean level)\n');
fprintf('%-22s %10s %10s\n','arm','C','pi');
for ir=1:2, for io=1:2
    r = S{ir,io};
    fprintf('%-22s %9.2f%% %9.2f%%\n', lab{ord(ir,io)}, r.rough_C, r.rough_pi);
end, end
