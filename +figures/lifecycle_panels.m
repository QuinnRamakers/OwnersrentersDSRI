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
%   Returns an INVISIBLE figure handle; the caller saves and closes it. Same
%   contract as figures.dc_equity_share, so a driver can mix them freely.
%
%   This drawing code had two copies. One read each arm's stored simulation
%   (the run's own, at a zero initial buffer); the other re-simulated at a
%   chosen buffer. Everything else about them -- panels, order, titles, layout,
%   line weights -- was identical, so they could and did drift apart on
%   everything except the one difference that mattered. Taking two sims as
%   arguments makes that difference the caller's, which is where it belongs.
%
%   simA and simB need C, X, A, ann_pay, pi, tau_A and ages -- the fields both
%   simulate.paths and simulate.paths_lna return, so either coordinate system
%   works. tau_A is read from simB only: it is the free-choice arm's applied DC
%   share, and on a glide arm it is the plan's path repeated, which the figure
%   does not claim to show.

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
xline(p.retirement_age, ':k'); title('mean consumption C'); xlabel('age');
legend({cA, cB}, 'Location','northwest'); ylabel('level (Y_0 units)');

nexttile; hold on; grid on;
plot(ages, m(simA.X), '-', 'LineWidth',1.6);
plot(ages, m(simB.X), '-', 'LineWidth',1.6);
xline(p.retirement_age, ':k'); title('mean liquid wealth X'); xlabel('age');

nexttile; hold on; grid on;
plot(ages, m(simA.A), '-', 'LineWidth',1.6);
plot(ages, m(simB.A), '-', 'LineWidth',1.6);
xline(p.retirement_age, ':k'); title('mean DC pension assets A'); xlabel('age');

% Financial wealth only -- liquid plus DC. Housing is assigned rather than
% chosen in this model, so folding it in would add a term neither arm controls.
nexttile; hold on; grid on;
plot(ages, m(simA.X + simA.A), '-', 'LineWidth',1.6);
plot(ages, m(simB.X + simB.A), '-', 'LineWidth',1.6);
xline(p.retirement_age, ':k'); title('mean financial wealth (X + A)'); xlabel('age');

nexttile; hold on; grid on;
plot(ages, m(simA.ann_pay), '-', 'LineWidth',1.6);
plot(ages, m(simB.ann_pay), '-', 'LineWidth',1.6);
xline(p.retirement_age, ':k'); title('mean annuity payout (gross)'); xlabel('age');

% pi is recorded every period, tau_A only for the T-1 transitions; both are
% the share chosen at t, so tau_A is drawn against the transition ages.
nexttile; hold on; grid on;
plot(ages, m(simA.pi), '-', 'LineWidth',1.4);
plot(ages, m(simB.pi), '-', 'LineWidth',1.4);
plot(ages_tr, m(simB.tau_A), '--', 'LineWidth',1.6);
xline(p.retirement_age, ':k'); title('equity shares'); xlabel('age'); ylim([0 1.02]);
legend({[cA ': liquid \pi'], [cB ': liquid \pi'], [cB ': DC \tau_A']}, ...
       'Location','northeast');

title(tl, ttl);
end
