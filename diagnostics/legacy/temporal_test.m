function temporal_test()
%TEMPORAL_TEST  Is the pi sawtooth TEMPORAL (pi_pol varies age-to-age at a
%   FIXED state) rather than a state/interpolation artifact? Hold the state
%   fixed and read pi_pol across ages.
scratch = 'C:\Users\Quinn\AppData\Local\Temp\claude\C--Users-Quinn-Desktop-claudecodetest\09022b31-1999-4844-b935-dc5896ea19a1\scratchpad';
addpath('C:\Users\Quinn\Desktop\claudecodetest\OwnersrentersDSRI-rentproc');
d = load(fullfile(scratch,'renter_snapshot.mat'));
p = d.p; sol = d.sol; sim = d.sim; ages = sim.ages;
gr = {p.u1_grid, p.u2_grid, p.u3_grid};

% Fixed states spanning where households actually live.
states = [0.15 0.90 0.30;    % mid-life accumulator
          0.20 0.98 0.60;    % typical retiree (u2 on the cliff)
          0.10 0.70 0.50];   % liquid-rich
names = {'accum u=(.15,.90,.30)','retiree u=(.20,.98,.60)','liquid u=(.10,.70,.50)'};

fig = figure('Position',[40 40 1400 560],'Color','w');
tl = tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');
title(tl,'Is the \pi sawtooth temporal? (pi\_pol at FIXED states, across age)','FontWeight','bold');

nexttile; hold on; grid on; box on;
for s=1:size(states,1)
    pit = zeros(1,p.T);
    for t=1:p.T
        F = griddedInterpolant(gr, sol.pi_pol(:,:,:,t), 'linear','nearest');
        pit(t) = F(states(s,1),states(s,2),states(s,3));
    end
    plot(ages, pit, '-o','MarkerSize',3,'DisplayName',names{s});
    d2 = abs(diff(pit,2));
    fprintf('%-26s: mean |2nd diff| over age = %.4f (max jump age-to-age %.3f)\n', ...
        names{s}, mean(d2), max(abs(diff(pit))));
end
xline(67,'k--','HandleVisibility','off'); ylim([0 1.02]);
xlabel('Age'); ylabel('\pi_{pol} at the FIXED state'); legend('Location','best','FontSize',8);
title('(a) hold state fixed, vary age  -> pure temporal policy noise');

% Compare: the simulated mean pi(age) (state moves too)
nexttile; hold on; grid on; box on;
plot(ages, mean(sim.pi,1), '-o','MarkerSize',3,'Color',[0.2 0.4 0.7]);
xline(67,'k--'); ylim([0 1.02]);
xlabel('Age'); ylabel('mean simulated \pi'); title('(b) simulated mean \pi(age) (state + policy both move)');

exportgraphics(fig, fullfile(scratch,'fig_temporal_test.png'),'Resolution',140);
fprintf('wrote fig_temporal_test.png\n');
end
