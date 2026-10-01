function compare_full_renter()
%COMPARE_FULL_RENTER  Full lifecycle solves, renter, for the four optimiser
%   configs {active-set, interior-point} x {refine on, off}. Overlays the
%   simulated pi(age) and c_frac(age) paths so the compounding over the 76-period
%   induction (which the single-step probe could not show) is visible.
repo = 'C:\Users\Quinn\Desktop\claudecodetest\OwnersrentersDSRI-rentproc';
addpath(repo); cd(repo);

% interior-point hits near-singular KKT systems on this flat objective; silence
% the (expected) spam but record that it fired.
warnid = 'MATLAB:nearlySingularMatrix';
combos = { 'active-set',    true,  'AS + refine',  [0.10 0.35 0.75], '-';
           'active-set',    false, 'AS, no refine',[0.10 0.35 0.75], '--';
           'interior-point',true,  'IP + refine',  [0.80 0.25 0.15], '-';
           'interior-point',false, 'IP, no refine',[0.80 0.25 0.15], '--' };
n = size(combos,1);
res = struct('label',{},'pi',{},'c',{},'time',{},'sing',{});

for i = 1:n
    p = config.params();
    p.is_owner = false; p.grid_type = 'lna';
    p.u1_grid = linspace(0,1,10).'; p.N_u1 = 10;
    p.u2_grid = linspace(0,1,8).';  p.N_u2 = 8;
    p.u3_grid = linspace(0,1,8).';  p.N_u3 = 8;
    p.gh_n = 5; p.gh_n_reit = 3; p.N_c = 15; p.N_pi = 15;
    p.skip_polish = false;
    p.polish_algo = combos{i,1};
    p.use_refine  = combos{i,2};
    p = config.insert_anchor_nodes(p);

    [~, mu_growth, sigma_l_log] = config.income_profile(p);
    profile.mu_growth = mu_growth; profile.sigma_l_log = sigma_l_log;
    profile.p_surv = config.survival(p);
    shocks = grids.shock_grid(p);
    ann = pension.annuity_price(p, profile, shocks);

    lastwarn(''); ws = warning('off', warnid);
    tic; evalc('sol = solver.solve_lifecycle_lna(p, profile, shocks, ann);'); tt = toc;
    [~, wid] = lastwarn; warning(ws);
    sim = simulate.forward(p, profile, sol, ann, 4000, 20260511);

    res(i).label = combos{i,3};
    res(i).pi = mean(sim.pi,1);
    res(i).c  = mean(sim.c_frac,1);
    res(i).time = tt;
    res(i).sing = strcmp(wid, warnid);
    fprintf('%-14s: %5.0fs  mean pi@40=%.3f  singularKKT=%d\n', ...
        combos{i,3}, tt, res(i).pi(16), res(i).sing);
end

ages = 25:100;
fig = figure('Position',[40 40 1500 620],'Color','w');
tl = tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');
title(tl,'Renter: full-solve optimiser comparison (active-set vs interior-point, refine on/off)', ...
      'FontSize',13,'FontWeight','bold');

nexttile; hold on; grid on; box on;
for i=1:n, plot(ages, res(i).pi, combos{i,5}, 'Color', combos{i,4}, 'LineWidth', 1.8, 'DisplayName', res(i).label); end
xline(67,'k--','HandleVisibility','off'); ylim([0 1.02]);
xlabel('Age'); ylabel('Mean liquid stock share \pi'); title('(a)  Private investment policy \pi(age)');
legend('Location','southwest','FontSize',9);

nexttile; hold on; grid on; box on;
for i=1:n, plot(ages, res(i).c, combos{i,5}, 'Color', combos{i,4}, 'LineWidth', 1.8, 'DisplayName', res(i).label); end
xline(67,'k--','HandleVisibility','off'); ylim([0 1.02]);
xlabel('Age'); ylabel('Mean consumption share c'); title('(b)  Consumption share c(age)');
legend('Location','northwest','FontSize',9);

out = fullfile('C:\Users\Quinn\AppData\Local\Temp\claude\C--Users-Quinn-Desktop-claudecodetest\09022b31-1999-4844-b935-dc5896ea19a1\scratchpad','fig_optimiser_compare_renter.png');
exportgraphics(fig, out, 'Resolution', 140);
fprintf('wrote %s\n', out);

% max per-age gap in mean pi between each combo and AS+refine
ref = res(1).pi;
fprintf('\nmax |mean-pi(age) - AS+refine| over ages 25-99:\n');
for i=2:n, fprintf('  %-14s : %.4f\n', res(i).label, max(abs(res(i).pi(1:end-1)-ref(1:end-1)))); end
end
