% Verification of the coord1 plumbing, before any number from it is quoted.
%
%  A  fwd and inv are exact inverses, all three charts, every age.
%  B  'yw' reproduces the stored pre-refactor value function bit for bit.
%  C  the alternative charts build a grid, solve, and simulate without error.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear; clc
o = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';

% ---- A: round trip -------------------------------------------------------
p0 = config.params(); p0.is_owner = false;
[~,mg,sl] = config.income_profile(p0);
prof.mu_growth=mg; prof.sigma_l_log=sl; prof.p_surv=config.survival(p0);
ann = pension.annuity_price(p0, prof, grids.shock_grid(p0));
phi = config.hk_factor(p0);
fprintf('A. inverse round trip, max |lam - inv(fwd(lam))| over all ages\n');
lam = linspace(0.002, 0.9, 60).'; uu = linspace(0,1,9);
for mode = {'yw','yann','hk'}
    q = p0; q.coord1 = mode{1}; q.hk_phi = phi; e = 0; vmin=inf; vmax=-inf;
    for t = 1:q.T
        c = config.coord1(q, t, ann);
        for a = uu, for b = uu
            v = c.fwd(lam, a, b);
            e = max(e, max(abs(c.inv(v, a, b) - lam)));
            vmin = min(vmin, min(v)); vmax = max(vmax, max(v));
        end, end
    end
    fprintf('   %-5s  max err %.3g   axis range actually used [%.4f, %.4f]\n', mode{1}, e, vmin, vmax);
end
fprintf('   phi at 25/45/66/67/80: %.1f %.1f %.2f %.2f %.2f\n', phi(1),phi(21),phi(42),phi(43),phi(56));

% ---- B: 'yw' must be bit-identical to the stored pre-refactor solve -------
L = load([o 'ab_profiles.mat']);            % solved before coord1 existed
pr = L.S(1).p; Vref = L.S(1).V; cref = L.S(1).sol_c; piref = L.S(1).sol_pi;
q = config.params(); q.is_owner = false;
q.grid_mode='none'; q.polish_ver=2; q.use_refine=false; q.interp_object='z';
q = utility.build_state_grids(q, [14 14 10], 3);
fprintf('\nB. grid identical to the stored one: u1 %d, u2 %d, u3 %d\n', ...
    isequal(q.u1_grid,pr.u1_grid), isequal(q.u2_grid,pr.u2_grid), isequal(q.u3_grid,pr.u3_grid));
[~,mg,sl]=config.income_profile(q);
pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(q);
sk=grids.shock_grid(q); an=pension.annuity_price(q,pf,sk);
s = solver.solve_lifecycle_lna(q, pf, sk, an);
fprintf('   isequal(V) = %d   max|dV| = %g   max|dc| = %g   max|dpi| = %g\n', ...
    isequal(s.V,Vref), max(abs(s.V(:)-Vref(:))), max(abs(s.c_pol(:)-cref(:))), ...
    max(abs(s.pi_pol(:)-piref(:))));

% ---- C: the alternative charts run end to end ----------------------------
fprintf('\nC. alternative charts, smoke\n');
for mode = {'yann','hk'}
    r = config.params(); r.is_owner = false; r.coord1 = mode{1};
    r.grid_mode='none'; r.polish_ver=2; r.use_refine=false;
    r = utility.build_state_grids(r, [14 14 10], 3);
    [~,mg,sl]=config.income_profile(r);
    pf2.mu_growth=mg; pf2.sigma_l_log=sl; pf2.p_surv=config.survival(r);
    sk2=grids.shock_grid(r); an2=pension.annuity_price(r,pf2,sk2);
    tic; sr = solver.solve_lifecycle_lna(r, pf2, sk2, an2); el=toc;
    sm = simulate.forward(r, pf2, sr, an2, 2000, 20260511, r.b0);
    fprintf('   %-5s axis [%.4f, %.4f] %d nodes | solved %.0fs | finite V %d/%d | C25 %.0f C65 %.0f pi25 %.2f\n', ...
        mode{1}, r.u1_grid(1), r.u1_grid(end), numel(r.u1_grid), el, ...
        sum(isfinite(sr.V(:))), numel(sr.V), ...
        median(sm.C(:,1),'omitnan'), median(sm.C(:,41),'omitnan'), mean(sm.pi(:,1),'omitnan'));
end
