% PLOT_PRIVATE_SAVINGS_RESPONSE  How owners and renters adjust their private
% (liquid) savings under two DC investment strategies.
%
%   One panel per strategy -- free DC choice vs the plan's imposed glide path
%   -- with both tenures in each. Reading across the panels gives the response
%   of private saving to the pension's investment rule.
%
%   Both arms are simulated here at the same buffer, so the panels differ only
%   in the DC strategy.

repo = fileparts(which('plot_private_savings_response'));
if isempty(repo), repo = pwd; end
addpath(repo);

X0_FRAC = 1.0;               % initial liquid buffer, in years of income
N_sim   = 10000;

arms = {'freetau', 'free DC choice'; ...
        'glide',   'imposed glide path'};
tenures = {'renter', 'owner'};

for i = 1:size(arms,1)
    for j = 1:numel(tenures)
        ten = tenures{j};
        if strcmp(arms{i,1}, 'freetau')
            fn = sprintf('combined_%s_freetau.mat', ten);
        else
            fn = sprintf('combined_%s.mat', ten);
        end
        D = load(fullfile(repo, fn));
        sim = simulate.paths(D.p, D.profile, D.sol, D.ann_price, N_sim, [], X0_FRAC);
        % Liquid wealth relative to current income: "how many years of income
        % is this household holding outside the pension".
        R.(arms{i,1}).(ten) = mean(sim.X ./ sim.Y, 1);
        R.ages = double(sim.ages);
        p = D.p;
    end
end

blue = [0.00 0.45 0.70];     % renter
red  = [0.84 0.37 0.00];     % owner
faint= [0.55 0.55 0.55];

keep = R.ages < p.retirement_age;
age  = R.ages(keep);
ymax = 0;
for i = 1:size(arms,1)
    for j = 1:numel(tenures)
        ymax = max(ymax, max(R.(arms{i,1}).(tenures{j})(keep)));
    end
end

f  = figure('Color','w', 'Position',[100 100 1120 540]);
tl = tiledlayout(f, 1, 2, 'TileSpacing','compact', 'Padding','compact');

for i = 1:size(arms,1)
    ax = nexttile(tl); hold(ax,'on');
    hr = plot(ax, age, R.(arms{i,1}).renter(keep), '-', 'LineWidth',2.6, 'Color',blue);
    ho = plot(ax, age, R.(arms{i,1}).owner(keep),  '-', 'LineWidth',2.6, 'Color',red);

    ax.FontSize  = 13;
    ax.LineWidth = 1.0;
    ax.TickDir   = 'out';
    ax.XColor    = [0.2 0.2 0.2];
    ax.YColor    = [0.2 0.2 0.2];
    ax.YGrid     = 'on';
    ax.GridColor = [0.8 0.8 0.8];
    ax.GridAlpha = 0.9;
    ax.Layer     = 'bottom';
    box(ax,'off');

    xlim(ax, [age(1) p.retirement_age]);
    ylim(ax, [0 1.05*ymax]);          % shared scale, so the panels are comparable
    title(ax, arms{i,2}, 'FontSize',15, 'FontWeight','bold');

    if i == 1
        ylabel(ax, 'private savings (years of income)', 'FontSize',14);
        lg = legend([hr ho], {'renter','owner'}, 'Location','northwest', ...
                    'FontSize',13, 'Box','off');
        lg.ItemTokenSize = [30 18];
    else
        ax.YTickLabel = [];
    end
end

xlabel(tl, 'age', 'FontSize',14);
title(tl, 'Private saving under two DC investment strategies', ...
      'FontSize',16, 'FontWeight','bold');
subtitle(tl, sprintf(['mean liquid wealth outside the pension, accumulation phase; ' ...
                      '\\gamma = %g, X_0 = %.1f yr of income'], p.gamma, X0_FRAC), ...
         'FontSize',12, 'Color',faint);

exportgraphics(f, fullfile(repo, 'fig_private_savings_response.png'), 'Resolution', 300);
exportgraphics(f, fullfile(repo, 'fig_private_savings_response.pdf'), 'ContentType', 'vector');
close(f);
fprintf('Saved: fig_private_savings_response.{png,pdf}\n');

for ag = [35 45 55 65]
    k = find(R.ages == ag);
    fprintf('age %d | free: rent %.2f own %.2f | glide: rent %.2f own %.2f\n', ag, ...
        R.freetau.renter(k), R.freetau.owner(k), R.glide.renter(k), R.glide.owner(k));
end
