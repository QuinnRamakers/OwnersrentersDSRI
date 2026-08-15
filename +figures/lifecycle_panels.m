function f = lifecycle_panels(simA, simB, p, ttl, labels)
%LIFECYCLE_PANELS  Six-panel life-cycle comparison of two simulated arms.
%
%   f = figures.lifecycle_panels(simA, simB, p, ttl)
%   f = figures.lifecycle_panels(simA, simB, p, ttl, {'no DC account', 'DC + free choice'})
%
%   Panels, left to right and top to bottom: mean consumption, liquid wealth,
%   DC pension assets, financial wealth (X + A), gross annuity payout, and the
%   equity shares -- both arms' liquid share plus arm B's applied DC share.
%
%   Returns an invisible figure handle; the caller saves and closes it.
%
%   The two simulations are passed in so the caller controls which initial
%   buffer they were drawn at. Each needs the fields C, X, A, ann_pay, pi,
%   tau_A and ages, which both simulate.paths and simulate.paths_lna return.
%   tau_A (the chosen pension equity share) is drawn for arm B only.

if nargin < 5 || isempty(labels)
    labels = {'arm A', 'arm B'};
end

ages    = double(simA.ages);
ages_tr = ages(1:end-1);
m       = @(F) mean(F, 1);          % cross-household mean by age
cA      = labels{1};
cB      = labels{2};

f  = figure('Visible','off', 'Position',[80 80 1180 720]);
tl = tiledlayout(f, 2, 3, 'TileSpacing','compact', 'Padding','compact');

nexttile; hold on; grid on;
plot(ages, m(simA.C), '-', 'LineWidth',1.6);
plot(ages, m(simB.C), '-', 'LineWidth',1.6);
xline(p.retirement_age, ':k'); title('Mean consumption'); xlabel('age');
legend({cA, cB}, 'Location','northwest'); ylabel('level (age-25 income = 1)');

nexttile; hold on; grid on;
plot(ages, m(simA.X), '-', 'LineWidth',1.6);
plot(ages, m(simB.X), '-', 'LineWidth',1.6);
xline(p.retirement_age, ':k'); title('Mean liquid savings (X)'); xlabel('age');

nexttile; hold on; grid on;
plot(ages, m(simA.A), '-', 'LineWidth',1.6);
plot(ages, m(simB.A), '-', 'LineWidth',1.6);
xline(p.retirement_age, ':k'); title('Mean pension balance (A)'); xlabel('age');

% Financial wealth is liquid plus pension only. Housing is assigned rather than
% chosen here, so including it would add a term neither arm controls.
nexttile; hold on; grid on;
plot(ages, m(simA.X + simA.A), '-', 'LineWidth',1.6);
plot(ages, m(simB.X + simB.A), '-', 'LineWidth',1.6);
xline(p.retirement_age, ':k'); title('Mean financial wealth (liquid + pension)'); xlabel('age');

nexttile; hold on; grid on;
plot(ages, m(simA.ann_pay), '-', 'LineWidth',1.6);
plot(ages, m(simB.ann_pay), '-', 'LineWidth',1.6);
xline(p.retirement_age, ':k'); title('Mean annuity income'); xlabel('age');

% The liquid share pi is recorded every period; the pension share tau_A only at
% the transitions between periods, so it is drawn against the transition ages.
nexttile; hold on; grid on;
plot(ages, m(simA.pi), '-', 'LineWidth',1.4);
plot(ages, m(simB.pi), '-', 'LineWidth',1.4);
plot(ages_tr, m(simB.tau_A), '--', 'LineWidth',1.6);
xline(p.retirement_age, ':k'); title('Equity shares'); xlabel('age'); ylim([0 1.02]);
legend({[cA ': liquid share \pi'], [cB ': liquid share \pi'], [cB ': pension share \tau']}, ...
       'Location','northeast');

title(tl, ttl);
end
