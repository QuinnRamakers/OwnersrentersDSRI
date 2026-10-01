% Does either scheme converge, and do the two converge ON EACH OTHER?
%
% The manufactured-solution test said kappa is the more accurate interpolant of
% a function with the model's boundary behaviour. It did NOT say kappa's answer
% to THIS model is right. The test that can say so is the interaction: two
% consistent schemes must approach each other as the grid refines, and the more
% accurate one must move less between refinements. If the gap between them does
% not shrink, neither is established and the manufactured test did not transfer.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
dims = {[10 10 8], [14 14 10], [18 18 12]};
objs = {'z','kappa'};
R = cell(3,2);
for ig = 1:3
  for io = 1:2
    p = config.params(); p.is_owner = false;
    p.grid_mode = 'none'; p.polish_ver = 2; p.use_refine = false;
    p.interp_object = objs{io};
    p = utility.build_state_grids(p, dims{ig}, 3);
    [~, mg, sl] = config.income_profile(p);
    prof.mu_growth = mg; prof.sigma_l_log = sl; prof.p_surv = config.survival(p);
    shk = grids.shock_grid(p); ann = pension.annuity_price(p, prof, shk);
    tic; sol = solver.solve_lifecycle_lna(p, prof, shk, ann); el = toc;
    sim = simulate.forward(p, prof, sol, ann, 4000, 20260511, p.b0);
    r.n = numel(p.u1_grid)*numel(p.u2_grid)*numel(p.u3_grid);
    r.C = median(sim.C,1,'omitnan'); r.pi = mean(sim.pi,1,'omitnan');
    r.obj = objs{io}; r.sec = el; r.ages = sim.ages;
    R{ig,io} = r;
    fprintf('%-6s n=%5d %5.0fs  C25=%6.0f C50=%6.0f pi25=%.2f pi50=%.2f\n', ...
        objs{io}, r.n, el, r.C(1), r.C(26), r.pi(1), r.pi(26));
  end
end

    function v = gap(a, b, idx)
        v = 100*mean(abs(b(idx)-a(idx))./max(abs(a(idx)),eps));
    end
young = 1:15; mid = 16:45; old = 46:75;

fprintf('\nBETWEEN schemes at each grid (mean |dC|/C, %%)\n');
fprintf('%8s %8s %8s %8s %8s\n','nodes','25-39','40-69','70+','pi 25-39');
for ig = 1:3
    a = R{ig,1}; b = R{ig,2};
    fprintf('%8d %7.1f%% %7.1f%% %7.1f%% %7.3f\n', a.n, ...
        gap(a.C,b.C,young), gap(a.C,b.C,mid), gap(a.C,b.C,old), ...
        mean(abs(b.pi(young)-a.pi(young))));
end

fprintf('\nWITHIN each scheme, successive refinements (mean |dC|/C, %%)\n');
fprintf('%-6s %14s %8s %8s %8s %10s\n','scheme','refinement','25-39','40-69','70+','pi 25-39');
for io = 1:2
    for ig = 1:2
        a = R{ig,io}; b = R{ig+1,io};
        fprintf('%-6s %6d->%-7d %7.1f%% %7.1f%% %7.1f%% %9.3f\n', objs{io}, a.n, b.n, ...
            gap(a.C,b.C,young), gap(a.C,b.C,mid), gap(a.C,b.C,old), ...
            mean(abs(b.pi(young)-a.pi(young))));
    end
end
o = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
save([o 'converge_test.mat'], 'R');
M = [R{1,1}.ages(1:75).'];
for ig=1:3, for io=1:2, M = [M, R{ig,io}.C(1:75).', R{ig,io}.pi(1:75).']; end, end
writematrix(M, [o 'converge_test.csv']);
