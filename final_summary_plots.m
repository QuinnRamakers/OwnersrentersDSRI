% FINAL_SUMMARY_PLOTS  Final review plots for the free-DC-choice work, with a
% modest initial liquid buffer so the comparison is not anchored at the
% degenerate zero-wealth corner.
%
%   X0_FRAC = 1 year of income of initial liquid savings (the household is no
%   longer "completely poor" at age 25). Policies are unchanged -- only the
%   simulation's initial state and the welfare anchor move off X0=0.
%
%   Produces:
%     summary_lifecycle_renter.png, summary_lifecycle_owner.png
%       6-panel no-DC vs DC+free-choice life cycle at the buffer.
%     summary_dc_equity_share.png
%       free (individually optimal) vs glide DC equity share, both tenures.
%     summary_welfare_by_buffer.png
%       CEV of DC+free-choice vs no-DC across the initial-buffer sweep, with
%       the chosen anchor marked.
%   Prints the welfare CEV table (DC vs no-DC, and free vs glide) at X0_FRAC.

repo = 'C:\Users\Quinn\Desktop\claudecodetest\OwnersrentersDSRI';
addpath(repo);
X0_FRAC = 1.0;               % initial liquid buffer, in years of income
N_sim   = 5000;

tenures = {'renter', 'owner'};

fprintf('=== Welfare with X0 = %.2f yr initial liquid buffer (gamma=5) ===\n', X0_FRAC);
for i = 1:numel(tenures)
    ten = tenures{i};
    B = load(fullfile(repo, sprintf('combined_%s_nodc.mat',    ten)));   % no DC
    G = load(fullfile(repo, sprintf('combined_%s.mat',         ten)));   % DC glide
    D = load(fullfile(repo, sprintf('combined_%s_freetau.mat', ten)));   % DC free choice
    p = D.p; gamma = p.gamma; hm = p.h_mult;

    % Re-simulate all three regimes with the initial buffer.
    simB = simulate.paths(B.p, B.profile, B.sol, B.ann_price, N_sim, [], X0_FRAC);
    simG = simulate.paths(G.p, G.profile, G.sol, G.ann_price, N_sim, [], X0_FRAC);
    simD = simulate.paths(D.p, D.profile, D.sol, D.ann_price, N_sim, [], X0_FRAC);

    ages = double(D.sim.ages); ages_tr = ages(1:end-1);
    mB = @(F) mean(F, 1);
    cB = 'no DC account'; cD = 'DC + free choice';

    % ---- 6-panel life cycle ----
    f = figure('Visible','off','Position',[80 80 1180 720]);
    tl = tiledlayout(f, 2, 3, 'TileSpacing','compact', 'Padding','compact');

    nexttile; hold on; grid on;
    plot(ages, mB(simB.C), '-', 'LineWidth',1.6);
    plot(ages, mB(simD.C), '-', 'LineWidth',1.6);
    xline(p.retirement_age, ':k'); title('mean consumption C'); xlabel('age');
    legend({cB, cD}, 'Location','northwest'); ylabel('level (Y_0 units)');

    nexttile; hold on; grid on;
    plot(ages, mB(simB.X), '-', 'LineWidth',1.6);
    plot(ages, mB(simD.X), '-', 'LineWidth',1.6);
    xline(p.retirement_age, ':k'); title('mean liquid wealth X'); xlabel('age');

    nexttile; hold on; grid on;
    plot(ages, mB(simB.A), '-', 'LineWidth',1.6);
    plot(ages, mB(simD.A), '-', 'LineWidth',1.6);
    xline(p.retirement_age, ':k'); title('mean DC pension assets A'); xlabel('age');

    nexttile; hold on; grid on;
    plot(ages, mB(simB.X + simB.A), '-', 'LineWidth',1.6);
    plot(ages, mB(simD.X + simD.A), '-', 'LineWidth',1.6);
    xline(p.retirement_age, ':k'); title('mean financial wealth (X + A)'); xlabel('age');

    nexttile; hold on; grid on;
    plot(ages, mB(simB.ann_pay), '-', 'LineWidth',1.6);
    plot(ages, mB(simD.ann_pay), '-', 'LineWidth',1.6);
    xline(p.retirement_age, ':k'); title('mean annuity payout (gross)'); xlabel('age');

    nexttile; hold on; grid on;
    plot(ages, mB(simB.pi), '-', 'LineWidth',1.4);
    plot(ages, mB(simD.pi), '-', 'LineWidth',1.4);
    plot(ages_tr, mB(simD.tau_A), '--', 'LineWidth',1.6);
    xline(p.retirement_age, ':k'); title('equity shares'); xlabel('age'); ylim([0 1.02]);
    legend({[cB ': liquid \pi'], [cD ': liquid \pi'], [cD ': DC \tau_A']}, 'Location','northeast');

    title(tl, sprintf('%s: no-DC vs DC + free choice  (X_0 = %.1f yr buffer, production grid)', ...
          ten, X0_FRAC));
    saveas(f, fullfile(repo, sprintf('summary_lifecycle_%s.png', ten)));
    close(f);

    % ---- welfare CEV at this buffer (V_tilde at buffered initial node) ----
    den = X0_FRAC + hm + 1; lam0 = 1/den; sH0 = hm/den;
    FvB = mk_interp(B.sol.V(:,:,:,1), p);
    FvG = mk_interp(G.sol.V(:,:,:,1), p);
    FvD = mk_interp(D.sol.V(:,:,:,1), p);
    vB = FvB(lam0,0,sH0); vG = FvG(lam0,0,sH0); vD = FvD(lam0,0,sH0);
    cev = @(vf,vg) (vf/vg)^(1/(1-gamma)) - 1;
    fprintf('  %-7s: DC-free vs no-DC = %+6.2f%% | DC-glide vs no-DC = %+6.2f%% | free vs glide = %+5.2f%%\n', ...
        ten, 100*cev(vD,vB), 100*cev(vG,vB), 100*cev(vD,vG));

    % stash tau_A means for the shared DC-equity-share plot
    S.(ten).ages = ages; S.(ten).ages_tr = ages_tr;
    S.(ten).tau_free  = mB(simD.tau_A);
    S.(ten).tau_glide = p.tau_S(:).';
end

% ---- DC equity share: free vs glide, both tenures ----
f = figure('Visible','off','Position',[100 100 820 500]); hold on; grid on;
plot(S.renter.ages_tr, S.renter.tau_free, '-',  'LineWidth',1.7, 'Color',[0 0.45 0.74]);
plot(S.owner.ages_tr,  S.owner.tau_free,  '-',  'LineWidth',1.7, 'Color',[0.85 0.33 0.10]);
plot(S.renter.ages_tr, S.renter.tau_glide,'--k','LineWidth',1.8);
xline(D.p.retirement_age, ':k');
xlabel('age'); ylabel('mean DC equity share \tau_A'); ylim([0 1.02]);
legend({'renter: free choice','owner: free choice','glide path (both)'}, 'Location','northeast');
title(sprintf('Individually optimal vs glide-path DC equity share (X_0 = %.1f yr buffer)', X0_FRAC));
saveas(f, fullfile(repo, 'summary_dc_equity_share.png'));
close(f);

% ---- welfare vs buffer sweep, anchor marked ----
buffers = linspace(0, 10, 41);
f = figure('Visible','off','Position',[100 100 820 500]); hold on; grid on;
cols = [0 0.45 0.74; 0.85 0.33 0.10];
for i = 1:numel(tenures)
    ten = tenures{i};
    Bs = load(fullfile(repo, sprintf('combined_%s_nodc.mat',    ten)), 'sol','p');
    Ds = load(fullfile(repo, sprintf('combined_%s_freetau.mat', ten)), 'sol','p');
    p = Ds.p; gamma = p.gamma; hm = p.h_mult;
    FvB = mk_interp(Bs.sol.V(:,:,:,1), p);
    FvD = mk_interp(Ds.sol.V(:,:,:,1), p);
    cv = arrayfun(@(b) (FvD(1/(b+hm+1),0,hm/(b+hm+1)) / ...
                        FvB(1/(b+hm+1),0,hm/(b+hm+1)))^(1/(1-gamma))-1, buffers);
    plot(buffers, 100*cv, '-', 'LineWidth',1.8, 'Color', cols(i,:));
end
yline(0, ':k','LineWidth',1.1); xline(X0_FRAC, '-.', 'LineWidth',1.2, 'Color',[0.4 0.4 0.4]);
text(X0_FRAC+0.15, -40, sprintf('chosen anchor X_0=%.1f yr', X0_FRAC), 'Color',[0.4 0.4 0.4]);
xlabel('initial liquid buffer X_0 (years of income)');
ylabel('welfare gain of DC + free choice vs no DC  (% CEV)');
title('DC-pension welfare gain rises with initial liquidity');
legend(tenures, 'Location','southeast');
saveas(f, fullfile(repo, 'summary_welfare_by_buffer.png'));
close(f);

fprintf('Saved: summary_lifecycle_{renter,owner}.png, summary_dc_equity_share.png, summary_welfare_by_buffer.png\n');

function F = mk_interp(V0, p)
    Z = V0;
    if any(isnan(Z(:)))
        [NL,NA,NH]=size(Z); mo=~isnan(Z);
        [Ig,Jg,Kg]=ndgrid(1:NL,1:NA,1:NH);
        Io=Ig(mo);Jo=Jg(mo);Ko=Kg(mo);Vo=Z(mo);
        Ib=Ig(~mo);Jb=Jg(~mo);Kb=Kg(~mo);
        for k=1:numel(Ib)
            d2=(Ib(k)-Io).^2+(Jb(k)-Jo).^2+(Kb(k)-Ko).^2;
            [~,q]=min(d2); Z(Ib(k),Jb(k),Kb(k))=Vo(q);
        end
    end
    F = griddedInterpolant({p.lambda_grid,p.sA_grid,p.sH_grid}, Z, 'linear','nearest');
end
