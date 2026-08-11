% PLOT_MANDATED_STRATEGY_RESPONSE  How owners and renters respond to a
% collective (mandatory) DC investment strategy.
%
%   One figure per mandated strategy: the equity share the household picks in
%   its own account outside the pension, against the share the plan imposes.
%
%   The legend is exported as its own file, to be placed under the two
%   figures. Both figures carry their own axis labels and share y-limits, so
%   they can be read side by side. Private saving is still computed, for the
%   diagnostics printed at the end.

clear R
repo = fileparts(which('plot_mandated_strategy_response'));
if isempty(repo), repo = pwd; end
addpath(repo);

X0_FRAC = 1.0;               % initial liquid buffer, in years of income
N_sim   = 6000;
X_MIN   = 0.05;              % skip near-ruin paths: the equity share is
                             % undefined when there is nothing to invest

arms = {'spl_100_100_100', 'Full equity allocation',                'full_equity';
        'spl_075_050_050', 'Decreasing equity allocation with age', 'glide'};
tenures = {'renter', 'owner'};

for i = 1:size(arms,1)
    for j = 1:numel(tenures)
        ten = tenures{j};
        D   = load(fullfile(repo, sprintf('%s_%s.mat', arms{i,1}, ten)));
        sim = simulate.paths(D.p, D.profile, D.sol, D.ann_price, N_sim, [], X0_FRAC);

        R.(arms{i,1}).(ten).X = mean(sim.X ./ sim.Y, 1);

        % equity share of the own account, averaged over paths that still
        % hold savings
        act = (sim.X ./ sim.Y) > X_MIN;
        pi_ = sim.pi;  pi_(~act) = NaN;
        R.(arms{i,1}).(ten).pi   = 100 * mean(pi_, 1, 'omitnan');
        R.(arms{i,1}).(ten).nact = mean(act, 1);

        R.ages = double(sim.ages);
        R.(arms{i,1}).tau = D.p.tau_S(:).';
        p = D.p;
    end
end

blue  = [0.00 0.45 0.70];    % renter, solid
orange= [0.90 0.45 0.05];    % owner, dashed
grey  = [0.45 0.45 0.45];    % plan, dotted

sty = {'-', '--', ':'};
LWr = 2.6; LWo = 2.6; LWt = 3.2;   % dotted needs extra weight to read

keep = R.ages < p.retirement_age;
age  = R.ages(keep);

styleax = @(ax) set(ax, 'FontSize',12.5, 'LineWidth',1.0, 'TickDir','out', ...
    'XColor',[0.2 0.2 0.2], 'YColor',[0.2 0.2 0.2], 'YGrid','on', ...
    'GridColor',[0.82 0.82 0.82], 'GridAlpha',0.9, 'Layer','bottom');

%% One figure per mandated strategy
for i = 1:size(arms,1)
    f  = figure('Color','w', 'Position',[100 100 720 540]);

    % how the own account is invested, against the plan's mandated share
    ax = axes(f); hold(ax,'on');
    tau_age = R.ages(1:numel(R.(arms{i,1}).tau));
    kt = tau_age < p.retirement_age;
    plot(ax, tau_age(kt), 100*R.(arms{i,1}).tau(kt), sty{3}, 'LineWidth',LWt, 'Color',grey);
    plot(ax, age, R.(arms{i,1}).renter.pi(keep), sty{1}, 'LineWidth',LWr, 'Color',blue);
    plot(ax, age, R.(arms{i,1}).owner.pi(keep),  sty{2}, 'LineWidth',LWo, 'Color',orange);
    styleax(ax); box(ax,'off');
    xlim(ax, [age(1) p.retirement_age]); ylim(ax, [0 105]);
    yticks(ax, 0:25:100);
    xlabel(ax, 'Age', 'FontSize',13);
    ylabel(ax, 'Equity share of the account (%)', 'FontSize',13);

    stem = fullfile(repo, sprintf('fig_response_%s', arms{i,3}));
    exportgraphics(f, [stem '.png'], 'Resolution', 300);
    exportgraphics(f, [stem '.pdf'], 'ContentType','vector');
    close(f);
end

%% Standalone legend, to be placed below the two figures
f  = figure('Color','w', 'Position',[100 100 1180 90]);
ax = axes(f, 'Position',[0 0 1 1], 'Visible','off'); hold(ax,'on');
h1 = plot(ax, NaN, NaN, sty{1}, 'LineWidth',LWr, 'Color',blue);
h2 = plot(ax, NaN, NaN, sty{2}, 'LineWidth',LWo, 'Color',orange);
h3 = plot(ax, NaN, NaN, sty{3}, 'LineWidth',LWt, 'Color',grey);
lg = legend(ax, [h1 h2 h3], ...
    {'Renter, private account', 'Owner, private account', 'Collective investment, pension account'}, ...
    'Orientation','horizontal', 'FontSize',13, 'Box','off');
lg.ItemTokenSize = [34 18];
lg.Position = [0 0.15 1 0.7];
exportgraphics(f, fullfile(repo,'fig_response_legend.png'), 'Resolution', 300);
exportgraphics(f, fullfile(repo,'fig_response_legend.pdf'), 'ContentType','vector');
close(f);

fprintf('Saved: fig_response_full_equity, fig_response_glide, fig_response_legend {.png,.pdf}\n');

for i = 1:size(arms,1)
    for ag = [35 50 65]
        k = find(R.ages == ag);
        fprintf('%s age %d | X: rent %.2f own %.2f | pi: rent %.0f%% own %.0f%% | plan %.0f%%\n', ...
            arms{i,1}, ag, R.(arms{i,1}).renter.X(k), R.(arms{i,1}).owner.X(k), ...
            R.(arms{i,1}).renter.pi(k), R.(arms{i,1}).owner.pi(k), 100*R.(arms{i,1}).tau(k));
    end
end
