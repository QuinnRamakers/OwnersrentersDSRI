% PLOT_DC_EQUITY_SHARE  Standalone driver for the DC-equity-share slide figures.
%
%   Builds the age profiles of the chosen equity shares for both tenures,
%   caches them, and renders fig_dc_equity_share.{png,pdf} and
%   fig_dc_equity_dispersion.{png,pdf}.
%
%   Reads combined_<ten>_freetau[_lna].mat -- run_combined's free-DC arm on
%   whichever coordinate system CGM_GRID selects (the cube by default). Both
%   coordinate systems now solve free tau through the same validated route: the
%   glide value stays in the seed grid and is polished from pinned, so free
%   choice cannot score below the glide.
%
%   This used to offer a second 'lna' source backed by ovnf.*, an unvalidated
%   grid-only port with no polish on the tau axis. It pinned 82% of renters to
%   the tau = 1 corner at age 30 against 18% on the simplex, flattening away
%   both the dispersion and the owner/renter contrast this figure exists to
%   show. That port is gone; the cube arm now comes from the same solver the
%   simplex arm does.
%
%   The solution is re-simulated here at X0_FRAC rather than reused from the
%   run, whose own sim sits at the much poorer p.b0 anchor (~0.08 yr). A
%   household with a 0.08-year buffer holds a different portfolio than one with
%   a 1-year buffer, so reusing it would confound the buffer with the arm.
%
%   The cache exists so the figures can be restyled without re-loading the
%   solutions: delete it (or set REBUILD = true) when the solutions change.

repo = fileparts(which('plot_dc_equity_share'));
if isempty(repo), repo = pwd; end
addpath(repo);

% repo locates the CODE; out_dir locates the DATA. They are the same folder
% in the documented workflow (cwd = repo, CGM_OUTPUT_DIR unset), and differ on
% the cluster, where outputs go to the mounted volume. Reading .mat files from
% repo meant this script found nothing there.
out_dir = utility.output_dir();

X0_FRAC = 1.0;               % initial liquid buffer, in years of income
N_sim   = 10000;
REBUILD = false;             % force a rebuild even if the cache is there

tenures = {'renter', 'owner'};
suffix  = utility.grid_suffix();   % '' simplex, '_lna' cube

% Rebuild if the cache predates a field the figures now need, so an old cache
% cannot silently break the plot.
needed = {'ages_tr', 'tau_free', 'pi_free', 'tau_p10', 'tau_p50', 'tau_p90', 'tau_glide'};
cache  = fullfile(out_dir, sprintf('dc_equity_share_data%s.mat', suffix));
stale  = REBUILD || ~isfile(cache);
if ~stale
    Q = load(cache, 'S');
    stale = ~all(isfield(Q.S.renter, needed));
end

if stale
    for i = 1:numel(tenures)
        ten = tenures{i};
        % simulate.forward dispatches on D.p.grid_type, so the arm is
        % simulated in the coordinates it was solved in whatever the file is.
        D   = load(fullfile(out_dir, sprintf('combined_%s_freetau%s.mat', ten, suffix)));
        sim = simulate.forward(D.p, D.profile, D.sol, D.ann_price, N_sim, [], X0_FRAC);
        p   = D.p;
        buffer = X0_FRAC;

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
    % Record the coordinate system from the solved p, not from the session, so
    % a stale cache cannot be mistaken for the other grid's.
    grid_used = char(p.grid_type);
    save(cache, 'S', 'p', 'buffer', 'grid_used');
    fprintf('Cached %s age profiles to %s\n', grid_used, cache);
else
    load(cache, 'S', 'p', 'buffer');
    fprintf('Loaded cached age profiles from %s\n', cache);
end

figs = {@dc_equity_share_figure,      ['fig_dc_equity_share' suffix]; ...
        @dc_equity_dispersion_figure, ['fig_dc_equity_dispersion' suffix]};
for i = 1:size(figs, 1)
    f = figs{i,1}(S, p, buffer);
    exportgraphics(f, fullfile(out_dir, [figs{i,2} '.png']), 'Resolution', 300);
    exportgraphics(f, fullfile(out_dir, [figs{i,2} '.pdf']), 'ContentType', 'vector');
    close(f);
    fprintf('Saved: %s.png, %s.pdf\n', figs{i,2}, figs{i,2});
end
