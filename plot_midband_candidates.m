% PLOT_MIDBAND_CANDIDATES  Private equity-share responses under the three
% candidate collective allocations fitted to the midpoint band.
%
%   Same layout and styling as plot_mandated_strategy_response: one figure
%   per strategy, renter and owner against the plan's imposed share, axes
%   labelled, no in-figure legend (fig_response_legend covers all three).
%
%   Prints how far each solved plan line ends up from the new midpoint --
%   the fit was made against the band under spl_100_100_100, and the band
%   moves once households re-optimise against the candidate itself.

clear R
repo = fileparts(which('plot_midband_candidates'));
if isempty(repo), repo = pwd; end
addpath(repo);

X0_FRAC = 1.0;
N_sim   = 6000;
X_MIN   = 0.05;

arms = {'spl_lin_77_06',   'Compromise A', 'lin';
        'spl_knot3_77_06', 'Compromise B', 'knot3';
        'spl_mid_100eq',   'Compromise C', 'mid'};
tenures = {'renter', 'owner'};

for i = 1:size(arms,1)
    for j = 1:numel(tenures)
        ten = tenures{j};
        D   = load(fullfile(repo, sprintf('%s_%s.mat', arms{i,1}, ten)));
        sim = simulate.forward(D.p, D.profile, D.sol, D.ann_price, N_sim, [], X0_FRAC);
        act = (sim.X ./ sim.Y) > X_MIN;
        pi_ = sim.pi;  pi_(~act) = NaN;
        R.(arms{i,3}).(ten) = 100 * mean(pi_, 1, 'omitnan');
        R.ages = double(sim.ages);
        R.(arms{i,3}).tau = 100 * reshape(D.p.tau_S, 1, []);
        p = D.p;
    end
end

blue   = [0.00 0.45 0.70];
orange = [0.90 0.45 0.05];
grey   = [0.45 0.45 0.45];
sty = {'-', '--', ':'};
LWr = 2.6; LWo = 2.6; LWt = 3.2;

keep = R.ages < p.retirement_age;
age  = R.ages(keep);

styleax = @(ax) set(ax, 'FontSize',12.5, 'LineWidth',1.0, 'TickDir','out', ...
    'XColor',[0.2 0.2 0.2], 'YColor',[0.2 0.2 0.2], 'YGrid','on', ...
    'GridColor',[0.82 0.82 0.82], 'GridAlpha',0.9, 'Layer','bottom');

fprintf('\ncandidate                        in band   max gap to the new midpoint\n');
for i = 1:size(arms,1)
    k = arms{i,3};
    f  = figure('Color','w', 'Position',[100 100 720 540]);
    ax = axes(f); hold(ax,'on');
    tau  = R.(k).tau;                      % length T-1, one per transition
    tage = R.ages(1:numel(tau));
    kt   = tage < p.retirement_age;
    plot(ax, tage(kt), tau(kt), sty{3}, 'LineWidth',LWt, 'Color',grey);
    plot(ax, age, R.(k).renter(keep), sty{1}, 'LineWidth',LWr, 'Color',blue);
    plot(ax, age, R.(k).owner(keep),  sty{2}, 'LineWidth',LWo, 'Color',orange);
    styleax(ax); box(ax,'off');
    xlim(ax, [age(1) p.retirement_age]); ylim(ax, [0 105]); yticks(ax, 0:25:100);
    xlabel(ax, 'Age', 'FontSize',13);
    ylabel(ax, 'Equity share of the account (%)', 'FontSize',13);

    stem = fullfile(repo, sprintf('fig_response_%s', arms{i,3}));
    exportgraphics(f, [stem '.png'], 'Resolution', 300);
    exportgraphics(f, [stem '.pdf'], 'ContentType','vector');
    close(f);

    t   = tau(kt);
    lo  = min(R.(k).renter(keep), R.(k).owner(keep));
    hi  = max(R.(k).renter(keep), R.(k).owner(keep));
    n   = min([numel(t) numel(lo)]);
    newmid = 0.5*(R.(k).renter(keep) + R.(k).owner(keep));
    fprintf('  %-30s %5.0f%%   %6.1f pp\n', arms{i,1}, ...
        100*mean(t(1:n) >= lo(1:n) & t(1:n) <= hi(1:n)), ...
        max(abs(t(1:n) - newmid(1:n))));
end

fprintf('\nSaved: fig_response_{lin,knot3,mid}.{png,pdf}\n');
for i = 1:size(arms,1)
    k = arms{i,3};
    for ag = [35 50 65]
        m = find(R.ages == ag);
        fprintf('%-16s age %d | renter %.0f%%  plan %.0f%%  owner %.0f%%\n', ...
            arms{i,1}, ag, R.(k).renter(m), R.(k).tau(m), R.(k).owner(m));
    end
end
