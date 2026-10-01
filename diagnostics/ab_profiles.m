% Side-by-side life cycle under the two interpolated objects.
% Same grid, same quadrature, same floor, same calibration, same simulation
% seed. The ONLY difference between the two arms is p.interp_object.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
objs = {'z','kappa'};
S = struct([]);
for io = 1:2
    p = config.params(); p.is_owner = false;
    p.grid_mode = 'none'; p.polish_ver = 2; p.use_refine = false;
    p.interp_object = objs{io};
    p = utility.build_state_grids(p, [14 14 10], 3);
    [~, mg, sl] = config.income_profile(p);
    prof.mu_growth = mg; prof.sigma_l_log = sl; prof.p_surv = config.survival(p);
    shk = grids.shock_grid(p); ann = pension.annuity_price(p, prof, shk);
    tic; sol = solver.solve_lifecycle_lna(p, prof, shk, ann); el = toc;
    sim = simulate.forward(p, prof, sol, ann, 4000, 20260511, p.b0);
    S(io).obj = objs{io}; S(io).sec = el; S(io).ages = sim.ages;
    S(io).C    = median(sim.C, 1, 'omitnan');
    S(io).Cm   = mean(sim.C, 1, 'omitnan');
    S(io).pi   = mean(sim.pi, 1, 'omitnan');
    S(io).cfr  = mean(sim.c_frac, 1, 'omitnan');
    S(io).LW   = median(sim.LW, 1, 'omitnan');
    S(io).X    = median(sim.X, 1, 'omitnan');
    S(io).disp = median(sim.disp_inc, 1, 'omitnan');
    F = p.phi_floor * sim.Y(:, 1:size(sim.C,2));
    S(io).floor_pct = 100*mean(sim.LW(:,1:size(F,2)) <= F, 1);
    S(io).p = p; S(io).sol_c = sol.c_pol; S(io).sol_pi = sol.pi_pol; S(io).V = sol.V;
    fprintf('%-6s solved %.0fs | C25=%.0f C45=%.0f C70=%.0f | pi25=%.2f pi45=%.2f pi70=%.2f | floored %.2f%%\n', ...
        objs{io}, el, S(io).C(1), S(io).C(21), S(io).C(46), ...
        S(io).pi(1), S(io).pi(21), S(io).pi(46), mean(S(io).floor_pct));
end
o = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
T = [S(1).ages(1:end-1).', S(1).C(1:75).', S(2).C(1:75).', ...
     S(1).pi(1:75).', S(2).pi(1:75).', ...
     S(1).cfr(1:75).', S(2).cfr(1:75).', ...
     S(1).floor_pct(1:75).', S(2).floor_pct(1:75).', ...
     S(1).disp(1:75).', S(2).disp(1:75).'];
writematrix(T, [o 'ab_profiles.csv']);
save([o 'ab_profiles.mat'], 'S', '-v7.3');
fprintf('\nage  C(z)     C(kappa)  d%%    pi(z)  pi(k)  floor(z) floor(k)\n');
for a = [25 30 35 40 50 60 66 67 70 80 90]
    i = a - 24;
    fprintf('%3d %8.0f %8.0f %+6.1f  %5.2f  %5.2f  %6.2f%% %6.2f%%\n', a, ...
        S(1).C(i), S(2).C(i), 100*(S(2).C(i)/S(1).C(i)-1), ...
        S(1).pi(i), S(2).pi(i), S(1).floor_pct(i), S(2).floor_pct(i));
end
