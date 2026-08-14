function make_prod_dashboards(src, label)
%MAKE_PROD_DASHBOARDS  Per-scenario dashboard for ONE production solve.
%
%   make_prod_dashboards('prod_floor_new.mat', 'prod_new_simplex')
%
%   make_plots is a script keyed to combined_<tenure>.mat read from
%   utility.output_dir(). Rather than staging over those names in the repo --
%   combined_renter.mat is a tracked file, and staging over it destroys it --
%   this points CGM_OUTPUT_DIR at a scratch directory and stages there, so the
%   repo is never written to and the stale committed combined_owner.mat is not
%   picked up as a second scenario.
%
%   Call once per solve, in its own MATLAB process. make_plots is a script and
%   uses `k` as a loop variable, so running it inside a loop here would clobber
%   the caller's own loop counter.

assert(nargin == 2, 'make_prod_dashboards:args', ...
       'Usage: make_prod_dashboards(src_mat, label)');
assert(isfile(src), 'make_prod_dashboards:missing', 'No such file: %s', src);

repo    = pwd;
scratch = fullfile(tempdir, 'cgm_dash', label);
if ~isfolder(scratch), mkdir(scratch); end

% Stage the solve under the renter name make_plots expects. No owner file is
% staged, so make_plots reports the owner scenario missing and skips it --
% these solves are all renters.
copyfile(fullfile(repo, src), fullfile(scratch, 'combined_renter.mat'));

setenv('CGM_OUTPUT_DIR', scratch);
setenv('CGM_ARM',  'glide');    % choose_tau_S is false throughout these runs
% 'simplex', not '': the file above is staged under the BARE name, which is the
% simplex convention (utility.grid_suffix). Empty means the session default,
% now the cube, and make_plots would look for combined_renter_lna.mat instead.
setenv('CGM_GRID', 'simplex');

fprintf('=== %s  <-  %s ===\n', label, src);
try
    run(fullfile(repo, 'make_plots.m'));
catch err
    % Later sections (renter-vs-owner, 3D surfaces) may need what is not
    % staged. The per-scenario dashboard is written before them.
    fprintf('  note: make_plots stopped later on (%s)\n', err.message);
end

produced = fullfile(scratch, 'fig_dashboard_full_renter_glide.png');
target   = fullfile(repo, sprintf('fig_dashboard_%s.png', label));
if isfile(produced)
    copyfile(produced, target);
    fprintf('  wrote %s\n', target);
else
    fprintf('  FAILED: no dashboard produced\n');
end
close all
setenv('CGM_OUTPUT_DIR', '');
end
