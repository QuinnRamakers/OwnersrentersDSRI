% Is the equity peak at retirement ruin contamination, or the household undoing
% the DC fund's glide path?
%
% The two explanations make opposite predictions about TOTAL equity exposure,
% liquid plus pension:
%
%   ruin contamination -> the liquid share is distorted, so total exposure
%       inherits the distortion and peaks at retirement too.
%   glide-path offsetting -> the fund de-risks into bonds as retirement
%       approaches, the household re-risks its liquid account to compensate, and
%       TOTAL exposure passes through retirement smoothly while the liquid share
%       spikes.
%
% No new solves: this reads the stored simulations, which carry the applied DC
% equity share tau_A alongside pi.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
o = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
A = load([o 'final_grid_run.mat']);      % renter, default vs designed, gh_n=5
B = load([o 'owner_fixed.mat']);         % owner, incl. housing x0.50 and x0.25

    function s = expo(sim)
        K = 1:size(sim.tau_A, 2);
        X = sim.X(:,K); Apot = sim.A(:,K);
        pi_l = sim.pi(:,K); tau = sim.tau_A(:,K);
        eq   = pi_l .* X + tau .* Apot;          % euros in equity
        fin  = X + Apot;
        s.ages  = sim.ages(K);
        s.pi    = mean(pi_l, 1, 'omitnan');       % liquid share
        s.tau   = mean(tau,  1, 'omitnan');       % DC share
        s.tot   = mean(eq ./ max(fin, eps), 1, 'omitnan');   % total exposure
        s.liqsh = mean(X ./ max(fin, eps), 1, 'omitnan');    % liquid / financial
    end

S = {}; nm = {};
S{end+1} = expo(A.S{2}.sim);  nm{end+1} = 'renter, housing x1.00';
S{end+1} = expo(B.R{2}.sim);  nm{end+1} = 'owner,  housing x1.00';
S{end+1} = expo(B.R{3}.sim);  nm{end+1} = 'owner,  housing x0.50';
S{end+1} = expo(B.R{4}.sim);  nm{end+1} = 'owner,  housing x0.25';

fprintf('%-24s %7s %7s %7s %7s %7s %7s %7s\n','series','age55','age62','age66','age67','age70','age80','jump67');
for k = 1:numel(S)
    s = S{k}; g = @(a) s.tot(a - s.ages(1) + 1);
    p = @(a) s.pi (a - s.ages(1) + 1);
    fprintf('%-24s  total exposure: %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f  %+6.2f\n', ...
        nm{k}, g(55), g(62), g(66), g(67), g(70), g(80), g(67)-g(66));
    fprintf('%-24s  liquid share  : %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f  %+6.2f\n', ...
        '', p(55), p(62), p(66), p(67), p(70), p(80), p(67)-p(66));
end

f = figure('Position',[60 60 1320 720],'Color','w');
tl = tiledlayout(f,2,2,'Padding','compact','TileSpacing','compact');
for k = 1:numel(S)
    s = S{k}; ax = nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    plot(ax, s.ages, s.pi,  'Color',[.85 .33 .10],'LineWidth',1.8);
    plot(ax, s.ages, s.tau, 'Color',[.47 .67 .19],'LineWidth',1.5,'LineStyle','--');
    plot(ax, s.ages, s.tot, 'Color',[.20 .35 .75],'LineWidth',2.2);
    xline(ax,67,':','Color',[.4 .4 .4]); ylim(ax,[0 1.05]); xlim(ax,[25 95]);
    title(ax, nm{k},'FontWeight','normal'); xlabel(ax,'age');
    if k==1
        ylabel(ax,'equity share');
        legend(ax,{'liquid account (pi)','DC fund (tau\_A)','TOTAL, liquid + DC'}, ...
               'Box','off','Location','south');
    end
end
sgtitle(f,'Does the retirement peak survive in TOTAL exposure, or is it the household offsetting the glide path?', ...
        'FontWeight','normal','FontSize',12);
exportgraphics(f,[o 'fig_total_exposure.png'],'Resolution',150);
disp('done');
