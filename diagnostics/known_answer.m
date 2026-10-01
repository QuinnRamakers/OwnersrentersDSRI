% Known-answer test for the kappa scheme.
%
% alpha and h_mult enter the renter's budget only as a product, so scaling alpha
% scales the committed rent outflow and nothing else. At a quarter of the
% production burden the ruin surface leaves the grid entirely: income alone
% covers the rent at every liquid balance, so there is no cliff for the kappa
% factorisation to fix.
%
% The two schemes MUST then agree, and both must give the textbook shape --
% equity share near 1 for the young. If kappa still returns a low, rising pi
% where there is no cliff, kappa is broken and the convergence result does not
% save it. If the two coincide there, the disagreement at full rent is about the
% cliff, which is what kappa claims to be about.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
o = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
scales = [1.0 0.5 0.25];  objs = {'z','kappa'};
S = cell(3,2);
for is = 1:3
  for io = 1:2
    p = config.params(); p.is_owner = false;
    p.alpha = p.alpha * scales(is);
    p.grid_mode = 'none'; p.polish_ver = 2; p.use_refine = false;   % shown not to matter: refine on/off moves levels <1%
    p.interp_object = objs{io};
    p = utility.build_state_grids(p, [14 14 10], 3);
    [~, mg, sl] = config.income_profile(p);
    prof.mu_growth = mg; prof.sigma_l_log = sl; prof.p_surv = config.survival(p);
    shk = grids.shock_grid(p); ann = pension.annuity_price(p, prof, shk);

    % where does the ruin surface sit on this grid? (working-age coefficients)
    cf = (1-p.delta)*(1-p.kappa(20))*(1-p.tau_inc);
    u2star = @(u1) (1 + cf*u1./(1-u1)) / (1+p.alpha);
    on_axis = 100*mean(u2star(p.u1_grid) <= 1);

    sol = solver.solve_lifecycle_lna(p, prof, shk, ann);
    sim = simulate.forward(p, prof, sol, ann, 4000, 20260511, p.b0);
    r.obj = objs{io}; r.scale = scales(is); r.on_axis = on_axis; r.ages = sim.ages;
    r.C = median(sim.C,1,'omitnan'); r.pi = mean(sim.pi,1,'omitnan');
    r.rent_share = median(sim.H(:,1)*p.alpha ./ sim.disp_inc(:,1));
    S{is,io} = r;
    fprintf('alpha x%.2f (rent %.0f%% of disposable at 25, ruin on axis for %.0f%% of u1) %-6s: pi25=%.2f pi30=%.2f pi40=%.2f C25=%6.0f\n', ...
        scales(is), 100*r.rent_share, on_axis, objs{io}, r.pi(1), r.pi(6), r.pi(16), r.C(1));
  end
end
save([o 'known_answer.mat'],'S');

fprintf('\nDo the two schemes agree once the cliff is gone?\n');
fprintf('%-10s %10s %12s %12s %12s\n','alpha','rent%','mean|dC|/C','|dpi| 25-39','pi25 z / kappa');
for is = 1:3
    a = S{is,1}; b = S{is,2}; i = 1:15;
    fprintf('x%-9.2f %9.0f%% %11.1f%% %12.3f %6.2f / %-6.2f\n', a.scale, 100*a.rent_share, ...
        100*mean(abs(b.C(i)-a.C(i))./a.C(i)), mean(abs(b.pi(i)-a.pi(i))), a.pi(1), b.pi(1));
end

f = figure('Position',[100 100 1180 420],'Color','w');
tl = tiledlayout(f,1,3,'Padding','compact','TileSpacing','compact');
for is = 1:3
    ax = nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha = .12;
    plot(ax, S{is,1}.ages(1:75), S{is,1}.pi(1:75), '-', 'Color',[.92 .41 .20],'LineWidth',1.8);
    plot(ax, S{is,2}.ages(1:75), S{is,2}.pi(1:75), '-', 'Color',[.16 .47 .84],'LineWidth',1.8);
    xline(ax,67,':','Color',[.5 .5 .5]); ylim(ax,[0 1.05]); xlim(ax,[25 99]);
    title(ax, sprintf('rent = %.0f%% of disposable', 100*S{is,1}.rent_share),'FontWeight','normal');
    xlabel(ax,'age');
    if is==1, ylabel(ax,'mean equity share'); legend(ax,{'linear-z','kappa'},'Location','south','Box','off'); end
end
sgtitle(f,'Known-answer test: shrink the rent until the ruin surface leaves the grid','FontWeight','normal','FontSize',12);
exportgraphics(f,[o 'fig_known_answer.png'],'Resolution',150);
