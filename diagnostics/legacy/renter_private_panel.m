function renter_private_panel()
%RENTER_PRIVATE_PANEL  Standalone, enlarged view of the private (liquid) account
%   for a RENTER: its size, and its equity position set against the pension's
%   equity and REIT, so "does the private portfolio make a difference" is
%   directly visible. Uses the clean AS+refine renter snapshot.
repo = 'C:\Users\Quinn\Desktop\claudecodetest\OwnersrentersDSRI-rentproc';
scratch = 'C:\Users\Quinn\AppData\Local\Temp\claude\C--Users-Quinn-Desktop-claudecodetest\09022b31-1999-4844-b935-dc5896ea19a1\scratchpad';
addpath(repo);
d = load(fullfile(scratch,'renter_snapshot.mat'));   % AS+refine renter
p = d.p; sim = d.sim; ages = sim.ages;

a50 = 50 - p.age0 + 1; unit = mean(sim.Y(:,a50)); dscale = 50000/(unit*1000);
T = numel(ages);
padT = @(M) [M, zeros(size(M,1), T-size(M,2))];
tau_mat  = padT(sim.tau_A);
reit_mat = padT(sim.reit_A);
Xm    = mean(sim.X,1)*dscale;
eqP   = mean(sim.pi .* sim.X,1)*dscale;
bnd   = max(Xm - eqP, 0);
eqPen = mean(tau_mat .* sim.A,1)*dscale;
reitP = mean(reit_mat .* sim.A,1)*dscale;
risky = eqP + eqPen + reitP;
shr   = eqP ./ max(risky, eps);
tr    = p.t_ret;

fig = figure('Position',[40 40 1500 640],'Color','w');
tl = tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');
title(tl,'Renter: the private (liquid) account — size, and whether it moves total risk','FontWeight','bold','FontSize',13);

nexttile; hold on; grid on; box on;
ak = area(ages, [eqP; bnd].');
ak(1).FaceColor=[0.30 0.55 0.80]; ak(1).FaceAlpha=0.9; ak(1).EdgeColor='none'; ak(1).DisplayName='Held in stocks (\pi\cdotX)';
ak(2).FaceColor=[0.72 0.78 0.85]; ak(2).FaceAlpha=0.9; ak(2).EdgeColor='none'; ak(2).DisplayName='Held in bonds ((1-\pi)\cdotX)';
xline(ages(tr),'k--','HandleVisibility','off');
xlabel('Age'); ylabel('USD (k)'); legend('Location','northwest');
title(sprintf('(a) Private account size  (peaks at %.0fk, private stocks \\leq %.0f%% of risky holdings)', ...
    max(Xm), 100*max(shr(isfinite(shr)))));

nexttile; hold on; grid on; box on;
plot(ages, eqP,   '-','Color',[0.20 0.45 0.75],'LineWidth',2.2,'DisplayName','Private stocks (\pi\cdotX)');
plot(ages, eqPen, '-','Color',[0.85 0.60 0.20],'LineWidth',2.2,'DisplayName','Pension stocks (\tau_S\cdotA)');
plot(ages, reitP, '-','Color',[0.15 0.60 0.55],'LineWidth',2.2,'DisplayName','Pension REIT (\tau_{REIT}\cdotA)');
xline(ages(tr),'k--','HandleVisibility','off');
xlabel('Age'); ylabel('USD (k)  (equity euros held)'); legend('Location','northwest');
title('(b) Risky euros held, by account — private vs pension');

exportgraphics(fig, fullfile(scratch,'fig_renter_private_portfolio.png'),'Resolution',140);
fprintf('renter: private account peak %.1fk; private stocks peak %.0f%% of risky holdings\n', max(Xm), 100*max(shr(isfinite(shr))));
fprintf('wrote fig_renter_private_portfolio.png\n');
end
