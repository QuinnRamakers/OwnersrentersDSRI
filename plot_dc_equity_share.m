% PLOT_DC_EQUITY_SHARE  Standalone driver for the DC-equity-share slide figures.
%
%   Builds the age profiles of the chosen equity shares for both tenures,
%   caches them, and renders fig_dc_equity_share.{png,pdf} and
%   fig_dc_equity_dispersion.{png,pdf}.
%
%   SOURCE picks the coordinate system:
%     'simplex'  combined_<ten>_freetau.mat, solved by solver.bellman_step on
%                the (lambda, s_A, s_H) simplex. The validated free-tau branch
%                (3-var polish + ridge refinement). Simulated here, so the
%                buffer X0_FRAC is ours to choose.
%     'lna'      ovn_lna_free_<ten>.mat, solved by ovnf.* on the (u1,u2,u3)
%                cube. An UNVALIDATED grid-only port: no polish on the tau
%                axis, tau resolved on p.N_tau levels, and its author's note
%                says to treat the value as a lower bound and not to quote its
%                level.
%   Both sources are re-simulated here at the same X0_FRAC, so the two figures
%   differ only in the coordinate system, not in the initial condition.
%
%   The cache exists so the figures can be restyled without re-loading the
%   solutions: delete it (or set REBUILD = true) when the solutions change.

repo = fileparts(which('plot_dc_equity_share'));
if isempty(repo), repo = pwd; end
addpath(repo);

% 'simplex' is the default: the ovnf 'lna' port grid-searches tau with no
% polish and pins most households to the tau = 1 corner in early-to-mid life
% (82% of renters at age 30, vs 18% on simplex), which flattens away both the
% cross-household dispersion and the owner/renter contrast.
SOURCE  = 'simplex';         % 'simplex' | 'lna'
X0_FRAC = 1.0;               % initial liquid buffer, in years of income
N_sim   = 10000;
REBUILD = false;             % force a rebuild even if the cache is there

tenures = {'renter', 'owner'};
suffix  = '';  if strcmp(SOURCE,'lna'), suffix = '_lna'; end

% Rebuild if the cache predates a field the figures now need, so an old cache
% cannot silently break the plot.
needed = {'ages_tr', 'tau_free', 'pi_free', 'tau_p10', 'tau_p50', 'tau_p90', 'tau_glide'};
cache  = fullfile(repo, sprintf('dc_equity_share_data%s.mat', suffix));
stale  = REBUILD || ~isfile(cache);
if ~stale
    Q = load(cache, 'S');
    stale = ~all(isfield(Q.S.renter, needed));
end

if stale
    for i = 1:numel(tenures)
        ten = tenures{i};
        switch SOURCE
            case 'simplex'
                D   = load(fullfile(repo, sprintf('combined_%s_freetau.mat', ten)));
                sim = simulate.paths(D.p, D.profile, D.sol, D.ann_price, N_sim, [], X0_FRAC);
                p   = D.p;
                buffer = X0_FRAC;
            case 'lna'
                % Re-simulate at X0_FRAC rather than reusing the run's own sim,
                % which sits at the much poorer p.b0 anchor (~0.08 yr). A
                % household with a 0.08-year buffer holds a different portfolio
                % than one with a 1-year buffer, so reusing it would confound
                % the coordinate systems with the initial condition.
                D   = load(fullfile(repo, sprintf('ovn_lna_free_%s.mat', ten)));
                sim = ovnf.paths_lna(D.p, D.profile, D.sol, D.ann_price, N_sim, [], X0_FRAC);
                p   = D.p;
                buffer = X0_FRAC;
            otherwise
                error('plot_dc_equity_share:source', 'unknown SOURCE "%s"', SOURCE);
        end

        % pi is recorded for every period, tau_A only for the T-1 transitions;
        % both are the share chosen at t, so drop pi's last column to align.
        ages  = double(sim.ages);
        pi_tr = sim.pi(:, 1:end-1);
        S.(ten).ages_tr   = ages(1:end-1);
        S.(ten).tau_free  = mean(sim.tau_A, 1);
        S.(ten).pi_free   = mean(pi_tr, 1);
        % Cross-sectional spread of the chosen DC share -- this is what the
        % dispersion figure plots against the plan's single default.
        S.(ten).tau_p10   = prctile(sim.tau_A, 10, 1);
        S.(ten).tau_p50   = prctile(sim.tau_A, 50, 1);
        S.(ten).tau_p90   = prctile(sim.tau_A, 90, 1);
        S.(ten).pi_p25    = prctile(pi_tr, 25, 1);
        S.(ten).pi_p75    = prctile(pi_tr, 75, 1);
        % The plan's glide path is a rule, not another solution's outcome.
        S.(ten).tau_glide = p.tau_S(:).';
    end
    save(cache, 'S', 'p', 'buffer', 'SOURCE');
    fprintf('Cached %s age profiles to %s\n', SOURCE, cache);
else
    load(cache, 'S', 'p', 'buffer');
    fprintf('Loaded cached age profiles from %s\n', cache);
end

figs = {@dc_equity_share_figure,      ['fig_dc_equity_share' suffix]; ...
        @dc_equity_dispersion_figure, ['fig_dc_equity_dispersion' suffix]};
for i = 1:size(figs, 1)
    f = figs{i,1}(S, p, buffer);
    exportgraphics(f, fullfile(repo, [figs{i,2} '.png']), 'Resolution', 300);
    exportgraphics(f, fullfile(repo, [figs{i,2} '.pdf']), 'ContentType', 'vector');
    close(f);
    fprintf('Saved: %s.png, %s.pdf\n', figs{i,2}, figs{i,2});
end
