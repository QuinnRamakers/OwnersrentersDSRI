function inspect_pi_policy()
%INSPECT_PI_POLICY  Diagnose the jagged pi(age), especially the retirement
%   sawtooth. Is it (i) a genuinely rough policy array pi_pol across grid nodes,
%   (ii) the simulated population marching across coarse u-grid nodes, or both?
repo = 'C:\Users\Quinn\Desktop\claudecodetest\OwnersrentersDSRI-rentproc';
addpath(repo); cd(repo);
d = load('combined_renter_lna.mat');       % AS+refine renter, 10x8x8
p = d.p; sim = d.sim; sol = d.sol;
ages = sim.ages; tr = p.t_ret;
fprintf('grid %dx%dx%d  gh_n=%d  refine on, active-set\n', p.N_u1,p.N_u2,p.N_u3,p.gh_n);

% (1) mean pi(age): quantify jaggedness = mean |second difference| (curvature)
pim = mean(sim.pi,1);
d2 = abs(diff(pim,2));
fprintf('mean pi(age): work-age |2nd diff| mean=%.4f ; retirement mean=%.4f\n', ...
    mean(d2(1:tr-3)), mean(d2(tr-1:end)));

% (2) roughness of the POLICY ARRAY itself at a retirement age (t=45, age 69):
%     how much do neighbouring nodes disagree in pi_pol?
t = 45;
PP = sol.pi_pol(:,:,:,t);          % N1 x N2 x N3
du1 = abs(diff(PP,1,1)); du2 = abs(diff(PP,1,2)); du3 = abs(diff(PP,1,3));
fprintf('pi_pol at age %d: node-to-node jump mean/max  along u1=%.3f/%.3f  u2=%.3f/%.3f  u3=%.3f/%.3f\n', ...
    ages(t), mean(du1(:)),max(du1(:)), mean(du2(:)),max(du2(:)), mean(du3(:)),max(du3(:)));

% (3) where do retirees live in the cube? convert sim state to (u1,u2,u3)
tt = 55;                              % age 79, deep retirement
lam = sim.lambda(:,tt); sA = sim.sA(:,tt); sH = sim.sH(:,tt);
u1 = lam; sAH = sA+sH; u2 = sAH./max(1-lam,1e-12); u3 = sA./max(sAH,1e-12);
fprintf('age %d retirees: u2 in [%.2f,%.2f] median %.2f ; u3 in [%.2f,%.2f] median %.2f\n', ...
    ages(tt), prctile(u2,5),prctile(u2,95),median(u2), prctile(u3,5),prctile(u3,95),median(u3));

fig = figure('Position',[40 40 1600 900],'Color','w');
tl = tiledlayout(fig,2,3,'Padding','compact','TileSpacing','compact');
title(tl, sprintf('Renter pi diagnosis (grid %dx%dx%d, AS+refine)', p.N_u1,p.N_u2,p.N_u3), ...
    'FontWeight','bold');

nexttile; plot(ages, pim,'-o','MarkerSize',3); grid on; xline(ages(tr),'k--');
xlabel('age'); ylabel('mean \pi'); title('(a) mean \pi(age) — the sawtooth');

% pi_pol vs u2 at a few (u1,u3), retirement age t
nexttile; hold on; grid on;
i1 = round(p.N_u1*0.3);
for k3 = round(linspace(1,p.N_u3,4))
    plot(p.u2_grid, squeeze(PP(i1,:,k3)),'-o','MarkerSize',3,'DisplayName',sprintf('u3=%.2f',p.u3_grid(k3)));
end
xlabel('u2 (illiquid share)'); ylabel('\pi_{pol}'); title(sprintf('(b) \\pi_{pol} vs u2, age %d',ages(t)));
legend('Location','best','FontSize',7);

% pi_pol vs u3
nexttile; hold on; grid on;
for k2 = round(linspace(1,p.N_u2,4))
    plot(p.u3_grid, squeeze(PP(i1,k2,:)),'-o','MarkerSize',3,'DisplayName',sprintf('u2=%.2f',p.u2_grid(k2)));
end
xlabel('u3 (pension share of illiquid)'); ylabel('\pi_{pol}'); title(sprintf('(c) \\pi_{pol} vs u3, age %d',ages(t)));
legend('Location','best','FontSize',7);

% pi_pol vs u1
nexttile; hold on; grid on;
k2 = round(p.N_u2*0.5); k3 = round(p.N_u3*0.5);
plot(p.u1_grid, squeeze(PP(:,k2,k3)),'-o','MarkerSize',3);
xlabel('u1 (income share)'); ylabel('\pi_{pol}'); title(sprintf('(d) \\pi_{pol} vs u1, age %d',ages(t)));

% retiree state cloud
nexttile; scatter(u2,u3,4,'filled','MarkerFaceAlpha',0.2); grid on;
xlabel('u2'); ylabel('u3'); title(sprintf('(e) retiree states, age %d',ages(tt))); xlim([0 1]); ylim([0 1]);

% mean u2, u3 by age (does the population MARCH across nodes?)
nexttile; hold on; grid on;
u2a = zeros(1,numel(ages)); u3a = u2a;
for a=1:numel(ages)
    la=sim.lambda(:,a); sAa=sim.sA(:,a); sHa=sim.sH(:,a); sAHa=sAa+sHa;
    u2a(a)=mean(sAHa./max(1-la,1e-12)); u3a(a)=mean(sAa./max(sAHa,1e-12));
end
plot(ages,u2a,'-','DisplayName','mean u2'); plot(ages,u3a,'-','DisplayName','mean u3');
for gv=p.u3_grid.', yline(gv,':','Color',[.7 .7 .7],'HandleVisibility','off'); end
xline(ages(tr),'k--','HandleVisibility','off');
xlabel('age'); ylabel('coord'); title('(f) mean u2,u3(age) vs u3 grid lines'); legend('Location','best','FontSize',8);

out = fullfile('C:\Users\Quinn\AppData\Local\Temp\claude\C--Users-Quinn-Desktop-claudecodetest\09022b31-1999-4844-b935-dc5896ea19a1\scratchpad','fig_pi_diagnosis.png');
exportgraphics(fig,out,'Resolution',130); fprintf('wrote %s\n', out);
end
