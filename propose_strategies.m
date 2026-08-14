% PROPOSE_STRATEGIES  Candidate collective allocations that run between the
% owner's and the renter's private equity share.
%
%   Plots only. Nothing here is solved: the private responses are the ones
%   already simulated under spl_075_050_050, and the candidates are drawn
%   against that band. The band itself will move once a candidate is solved
%   -- households re-optimise against whatever the plan does -- so treat the
%   fit statistics as a starting point, not a result.
%
%   Candidates:
%     midpoint    the pointwise average of the two private paths (target)
%     4-knot      PCHIP through the midpoint at ages 25/40/55/67
%     linear      straight line between the midpoint's endpoints
%     3-knot      the current menu parameterisation (knots at 25/67/99 only)

clear
repo = fileparts(which('propose_strategies'));
if isempty(repo), repo = pwd; end
addpath(repo);

REF     = 'spl_100_100_100';   % arm whose private responses set the band
X0_FRAC = 1.0;
N_sim   = 6000;
X_MIN   = 0.05;

for ten = {'renter','owner'}
    D   = load(fullfile(repo, sprintf('%s_%s.mat', REF, ten{1})));
    sim = simulate.forward(D.p, D.profile, D.sol, D.ann_price, N_sim, [], X0_FRAC);
    act = (sim.X ./ sim.Y) > X_MIN;
    pi_ = sim.pi;  pi_(~act) = NaN;
    PI.(ten{1}) = 100 * mean(pi_, 1, 'omitnan');
    ages = double(sim.ages);
    p = D.p;
end

work = ages < p.retirement_age;          % accumulation phase
age  = ages(work);
mid  = 0.5 * (PI.renter(work) + PI.owner(work));
idx  = @(a) find(age == a, 1);
val  = @(a) mid(idx(a));                 % midpoint at a given age

%% Candidate knot sets (fracs rounded to whole percent, ready to run)
kn4 = [25 40 55 p.retirement_age];
kf4 = round([val(25) val(40) val(55) mid(end)]) / 100;

kn3 = [p.age0 p.retirement_age p.age0 + p.T - 2];
kf3 = round([val(25) mid(end) mid(end)]) / 100;

lin = linspace(val(25), mid(end), numel(age));

% spline_tau returns a column; keep everything a row so the fit statistics
% below compare element-wise instead of broadcasting into a matrix
tau4 = 100 * reshape(strategy.spline_tau(p, kn4, kf4), 1, []);
tau3 = 100 * reshape(strategy.spline_tau(p, kn3, kf3), 1, []);
tau_now = 100 * p.tau_S(:).';
tau_age = ages(1:numel(tau_now));

C = {  % name, y over `age`, colour, style, width
    'Midpoint of the two (target)',        mid,                  [0.15 0.15 0.15], '-',  1.6;
    'Spline, 4 knots (25/40/55/67)',       tau4(work),           [0.45 0.16 0.55], '-',  3.0;
    'Linear glide',                        lin,                  [0.10 0.55 0.35], '-.', 2.4;
    'Spline, 3 knots (current menu)',      tau3(work),           [0.80 0.20 0.20], '-',  2.2;
    sprintf('%s (the arm this is based on)', strrep(REF,'_','\_')), ...
                                           tau_now(tau_age < p.retirement_age), [0.45 0.45 0.45], ':', 3.0};

%% Fit statistics against the current band
lo = min(PI.renter(work), PI.owner(work));
hi = max(PI.renter(work), PI.owner(work));
fprintf('\ncandidate                              in band   max gap to midpoint\n');
for k = 1:size(C,1)
    y = C{k,2};
    fprintf('  %-36s %5.0f%%   %6.1f pp\n', C{k,1}, ...
        100*mean(y >= lo & y <= hi), max(abs(y - mid)));
end
fprintf('\n4-knot fracs at ages [%s]: [%s]\n', num2str(kn4), num2str(kf4, ' %.2f'));
fprintf('3-knot fracs at ages [%s]: [%s]\n', num2str(kn3), num2str(kf3, ' %.2f'));
fprintf('run: run_spline_strategies(struct(''name'',''spl_mid4'',''knot_ages'',[%s],''knot_fracs'',[%s]))\n', ...
    num2str(kn4), num2str(kf4, ' %.2f'));

%% Figure
blue   = [0.00 0.45 0.70];
orange = [0.90 0.45 0.05];

f  = figure('Color','w', 'Position',[100 100 980 640]);
ax = axes(f); hold(ax,'on');

fill(ax, [age fliplr(age)], [lo fliplr(hi)], [0.90 0.90 0.90], ...
     'EdgeColor','none', 'FaceAlpha',0.7, 'HandleVisibility','off');

h = gobjects(size(C,1),1);
for k = 1:size(C,1)
    h(k) = plot(ax, age, C{k,2}, C{k,4}, 'LineWidth', C{k,5}, 'Color', C{k,3});
end
plot(ax, kn4(kn4 < p.retirement_age), 100*kf4(kn4 < p.retirement_age), 'o', ...
     'MarkerSize',7, 'MarkerFaceColor',[0.45 0.16 0.55], 'MarkerEdgeColor','w', ...
     'LineWidth',1.2, 'HandleVisibility','off');

hr = plot(ax, age, PI.renter(work), '-',  'LineWidth',2.2, 'Color',blue);
ho = plot(ax, age, PI.owner(work),  '--', 'LineWidth',2.2, 'Color',orange);

set(ax, 'FontSize',12.5, 'LineWidth',1.0, 'TickDir','out', ...
    'XColor',[0.2 0.2 0.2], 'YColor',[0.2 0.2 0.2], 'YGrid','on', ...
    'GridColor',[0.85 0.85 0.85], 'GridAlpha',0.9, 'Layer','bottom');
box(ax,'off');
xlim(ax, [age(1) p.retirement_age]); ylim(ax, [0 105]); yticks(ax, 0:25:100);
xlabel(ax, 'Age', 'FontSize',13);
ylabel(ax, 'Equity share of the account (%)', 'FontSize',13);
title(ax, 'Candidate collective allocations against the private responses', ...
      'FontSize',14.5, 'FontWeight','bold');

lg = legend(ax, [hr; ho; h], [{'Renter, private account'; 'Owner, private account'}; C(:,1)], ...
            'Location','southwest', 'FontSize',11.5, 'Box','off');
lg.ItemTokenSize = [34 18];

exportgraphics(f, fullfile(repo,'fig_strategy_options.png'), 'Resolution', 300);
exportgraphics(f, fullfile(repo,'fig_strategy_options.pdf'), 'ContentType','vector');
close(f);
fprintf('\nSaved: fig_strategy_options.{png,pdf}\n');
