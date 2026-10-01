% 2x2: grid density x interpolated object. The only question is whether the
% kappa factorisation reduces the grid sensitivity that every earlier session
% measured. Same quadrature, same floor, same calibration throughout.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
dims = {[8 8 6], [14 14 10]};
objs = {'z', 'kappa'};
R = struct([]);
for io = 1:2
  for ig = 1:2
    p = config.params(); p.is_owner = false;
    p.grid_mode = 'none'; p.polish_ver = 2; p.use_refine = false;
    p.interp_object = objs{io};
    p = utility.build_state_grids(p, dims{ig}, 3);
    [~, mg, sl] = config.income_profile(p);
    prof.mu_growth = mg; prof.sigma_l_log = sl; prof.p_surv = config.survival(p);
    shk = grids.shock_grid(p); ann = pension.annuity_price(p, prof, shk);
    ia = find(abs(p.u1_grid - 1/(1+p.h_mult+p.b0)) < 1e-12, 1);
    ib = find(abs(p.u2_grid - p.h_mult/(p.h_mult+p.b0)) < 1e-12, 1);
    tic; sol = solver.solve_lifecycle_lna(p, prof, shk, ann); el = toc;
    k = numel(R)+1;
    R(k).obj = objs{io}; R(k).n = numel(p.u1_grid)*numel(p.u2_grid)*numel(p.u3_grid);
    R(k).sec = el;
    R(k).Ventry = sol.V(ia, ib, 1, 1);
    R(k).c25    = sol.c_pol(ia, ib, 1, 1);
    R(k).pi25   = sol.pi_pol(ia, ib, 1, 1);
    R(k).pi30   = sol.pi_pol(ia, ib, 1, 6);
    R(k).c60    = sol.c_pol(ia, ib, 1, 36);
    R(k).poison = mean(reshape(sol.V(:,:,:,1),[],1) < -1e12);
    fprintf('%-6s n=%5d  %6.0fs  V=%11.4g  c25=%.4f pi25=%.3f pi30=%.3f\n', ...
            R(k).obj, R(k).n, el, R(k).Ventry, R(k).c25, R(k).pi25, R(k).pi30);
  end
end
fprintf('\n%-8s %12s %12s %10s %10s %10s\n','object','|V| ratio','dc25','dpi25','dpi30','poison lo/hi');
for io = 1:2
  a = R(2*io-1); b = R(2*io);
  fprintf('%-8s %12.3g %12.4f %10.4f %10.4f %5.1f%%/%.1f%%\n', a.obj, ...
      abs(b.Ventry/a.Ventry), b.c25-a.c25, b.pi25-a.pi25, b.pi30-a.pi30, ...
      100*a.poison, 100*b.poison);
end
save('C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/grid_x_object.mat','R');
