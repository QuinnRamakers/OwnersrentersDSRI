function render_diag()
%RENDER_DIAG  (1) Grid-resolution test of the jagged pi (renter, AS+refine at
%   three grids). (2) Re-solve the four optimiser configs saving full sims and
%   render a make_plots dashboard for each.
repo    = 'C:\Users\Quinn\Desktop\claudecodetest\OwnersrentersDSRI-rentproc';
scratch = 'C:\Users\Quinn\AppData\Local\Temp\claude\C--Users-Quinn-Desktop-claudecodetest\09022b31-1999-4844-b935-dc5896ea19a1\scratchpad';
addpath(repo); cd(repo);
warning('off','MATLAB:nearlySingularMatrix');

%% (1) grid-resolution sweep: AS + refine, three grids
sweep = {[10 8 8],'10x8x8',[0.80 0.30 0.20];
         [14 12 12],'14x12x12',[0.30 0.55 0.30];
         [18 15 15],'18x15x15',[0.15 0.35 0.75]};
ages = 25:100; pis = cell(size(sweep,1),1);
for i=1:size(sweep,1)
    p = build_p(false, sweep{i,1}, 'active-set', true);
    tic; sim = solve_sim(p); tt=toc;
    pis{i} = mean(sim.pi,1);
    d2 = abs(diff(pis{i},2));
    fprintf('grid %-9s: %5.0fs  roughness(mean|2nd diff|)=%.4f\n', sweep{i,2}, tt, mean(d2));
end
fig = figure('Position',[40 40 1200 620],'Color','w'); hold on; grid on; box on;
for i=1:size(sweep,1), plot(ages, pis{i}, '-', 'Color', sweep{i,3}, 'LineWidth', 1.8, 'DisplayName', sweep{i,2}); end
xline(67,'k--','HandleVisibility','off'); ylim([0 1.02]);
xlabel('Age'); ylabel('mean liquid stock share \pi'); legend('Location','southwest');
title('Renter \pi(age): does refining the (u1,u2,u3) grid smooth the sawtooth? (AS + refine)');
exportgraphics(fig, fullfile(scratch,'fig_pi_grid_sweep.png'), 'Resolution', 140);
fprintf('wrote fig_pi_grid_sweep.png\n');

%% (2) four optimiser configs at 10x8x8, save sims, render dashboards
cfgs = {'AS_refine','active-set',true; 'AS_noref','active-set',false;
        'IP_refine','interior-point',true; 'IP_noref','interior-point',false};
for i=1:size(cfgs,1)
    p = build_p(false, [10 8 8], cfgs{i,2}, cfgs{i,3});
    [sim,sol,profile,shocks,ann_price] = solve_sim(p); %#ok<ASGLU>
    save(fullfile(repo,'combined_renter_lna.mat'),'p','profile','shocks','ann_price','sol','sim');
    close all; run(fullfile(repo,'make_plots.m'));
    copyfile(fullfile(repo,'fig_dashboard_full_renter_glide.png'), ...
             fullfile(scratch, sprintf('fig_dash_renter_%s.png', cfgs{i,1})));
    fprintf('rendered dashboard for %s\n', cfgs{i,1});
end
fprintf('=== render_diag DONE ===\n');
end

function p = build_p(is_owner, Nu, algo, use_ref)
    p = config.params();
    p.is_owner = is_owner; p.grid_type = 'lna';
    p.u1_grid = linspace(0,1,Nu(1)).'; p.N_u1 = Nu(1);
    p.u2_grid = linspace(0,1,Nu(2)).'; p.N_u2 = Nu(2);
    p.u3_grid = linspace(0,1,Nu(3)).'; p.N_u3 = Nu(3);
    p.gh_n = 5; p.gh_n_reit = 3; p.N_c = 15; p.N_pi = 15;
    p.skip_polish = false; p.polish_algo = algo; p.use_refine = use_ref;
    p = config.insert_anchor_nodes(p);
end

function [sim,sol,profile,shocks,ann_price] = solve_sim(p)
    [~, mu_growth, sigma_l_log] = config.income_profile(p);
    profile.mu_growth = mu_growth; profile.sigma_l_log = sigma_l_log;
    profile.p_surv = config.survival(p);
    shocks = grids.shock_grid(p);
    ann_price = pension.annuity_price(p, profile, shocks);
    evalc('sol = solver.solve_lifecycle_lna(p, profile, shocks, ann_price);');
    sim = simulate.forward(p, profile, sol, ann_price, 4000, 20260511);
end
