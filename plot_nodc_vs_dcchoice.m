% PLOT_NODC_VS_DCCHOICE  Life-cycle comparison: no-DC-account benchmark vs
% the free-DC-investment-choice model, for renter and owner tenure.
%
%   no DC   : combined_{tenure}_nodc.mat     (kappa=0; liquid + housing only)
%   DC free : combined_{tenure}_freetau.mat  (kappa=0.2, individually optimal
%             DC equity share, EET-sheltered, annuitised at retirement)
%   Same calibration + production grid, so levels and welfare are comparable.
%
%   Produces nodc_vs_dcchoice_{renter,owner}.png (6-panel life-cycle) and
%   prints the welfare gain (CEV at the initial node) of having the DC
%   pension with free investment choice.

repo = 'C:\Users\Quinn\Desktop\claudecodetest\OwnersrentersDSRI';
addpath(repo);
tenures = {'renter', 'owner'};

for i = 1:numel(tenures)
    ten = tenures{i};
    B = load(fullfile(repo, sprintf('combined_%s_nodc.mat', ten)));      % no DC
    D = load(fullfile(repo, sprintf('combined_%s_freetau.mat', ten)));   % DC free choice
    p = D.p; ages = double(D.sim.ages);
    ages_tr = ages(1:end-1);

    mB = @(F) mean(F, 1);   % cross-household mean by age
    cB = 'no DC account'; cD = 'DC + free choice';

    f = figure('Visible','off','Position',[80 80 1180 720]);
    tl = tiledlayout(f, 2, 3, 'TileSpacing','compact', 'Padding','compact');

    nexttile; hold on; grid on;
    plot(ages, mB(B.sim.C), '-', 'LineWidth',1.6);
    plot(ages, mB(D.sim.C), '-', 'LineWidth',1.6);
    xline(p.retirement_age, ':k'); title('mean consumption C'); xlabel('age');
    legend({cB, cD}, 'Location','northwest'); ylabel('level (Y_0 units)');

    nexttile; hold on; grid on;
    plot(ages, mB(B.sim.X), '-', 'LineWidth',1.6);
    plot(ages, mB(D.sim.X), '-', 'LineWidth',1.6);
    xline(p.retirement_age, ':k'); title('mean liquid wealth X'); xlabel('age');

    nexttile; hold on; grid on;
    plot(ages, mB(B.sim.A), '-', 'LineWidth',1.6);
    plot(ages, mB(D.sim.A), '-', 'LineWidth',1.6);
    xline(p.retirement_age, ':k'); title('mean DC pension assets A'); xlabel('age');

    nexttile; hold on; grid on;
    % Net worth = liquid + DC + home equity (renter home equity = 0 in this
    % passive-housing model's welfare sense; show liquid+DC financial wealth).
    plot(ages, mB(B.sim.X + B.sim.A), '-', 'LineWidth',1.6);
    plot(ages, mB(D.sim.X + D.sim.A), '-', 'LineWidth',1.6);
    xline(p.retirement_age, ':k'); title('mean financial wealth (X + A)'); xlabel('age');

    nexttile; hold on; grid on;
    plot(ages, mB(B.sim.ann_pay), '-', 'LineWidth',1.6);
    plot(ages, mB(D.sim.ann_pay), '-', 'LineWidth',1.6);
    xline(p.retirement_age, ':k'); title('mean annuity payout (gross)'); xlabel('age');

    nexttile; hold on; grid on;
    plot(ages, mB(B.sim.pi), '-', 'LineWidth',1.4);
    plot(ages, mB(D.sim.pi), '-', 'LineWidth',1.4);
    plot(ages_tr, mB(D.sim.tau_A), '--', 'LineWidth',1.6);
    xline(p.retirement_age, ':k'); title('equity shares'); xlabel('age'); ylim([0 1.02]);
    legend({[cB ': liquid \pi'], [cD ': liquid \pi'], [cD ': DC \tau_A']}, ...
           'Location','northeast');

    title(tl, sprintf('%s: no-DC-account vs DC + free investment choice (production grid)', ten));
    saveas(f, fullfile(repo, sprintf('nodc_vs_dcchoice_%s.png', ten)));
    close(f);

    gamma = p.gamma;
    cev = (D.welfare0.Vt0 / B.welfare0.Vt0)^(1/(1-gamma)) - 1;
    fprintf('%-7s: Vt0 no-DC=% .6g  DC-free=% .6g  -> welfare gain of DC+choice = %+.2f%% CEV\n', ...
        ten, B.welfare0.Vt0, D.welfare0.Vt0, 100*cev);
    fprintf('  Saved nodc_vs_dcchoice_%s.png\n', ten);
end
