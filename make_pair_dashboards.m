function make_pair_dashboards(renter_mat, owner_mat, label)
%MAKE_PAIR_DASHBOARDS  Both tenure dashboards plus the renter-vs-owner figure.
%
%   make_pair_dashboards('v2_renter.mat', 'v2_owner.mat', 'v2')
%
%   make_plots is a script keyed to combined_<tenure>.mat read from
%   utility.output_dir(). combined_renter.mat is a TRACKED file in this repo,
%   so staging over it in place destroys it -- this stages into a scratch
%   directory via CGM_OUTPUT_DIR instead and copies the figures back. That also
%   keeps the stale committed combined_owner.mat from being picked up as a
%   third scenario.
%
%   Staging both tenures is what unlocks fig_renter_vs_owner; with only one
%   present make_plots reports the other missing and skips that comparison.

repo    = pwd;
scratch = fullfile(tempdir, 'cgm_dash', label);
if ~isfolder(scratch), mkdir(scratch); end

assert(isfile(renter_mat), 'make_pair_dashboards:missing', 'No such file: %s', renter_mat);
assert(isfile(owner_mat),  'make_pair_dashboards:missing', 'No such file: %s', owner_mat);
copyfile(fullfile(repo, renter_mat), fullfile(scratch, 'combined_renter.mat'));
copyfile(fullfile(repo, owner_mat),  fullfile(scratch, 'combined_owner.mat'));

setenv('CGM_OUTPUT_DIR', scratch);
setenv('CGM_ARM',  'glide');
% 'simplex', not '': the files above are staged under the BARE names, and bare
% is the simplex convention (utility.grid_suffix). Empty would mean "whatever
% the session default is", which is the cube, and make_plots would then look
% for combined_*_lna.mat and find nothing.
setenv('CGM_GRID', 'simplex');

fprintf('=== dashboards for %s ===\n', label);
try
    run(fullfile(repo, 'make_plots.m'));
catch err
    fprintf('  note: make_plots stopped later on (%s)\n', err.message);
end

produced = { 'fig_dashboard_full_renter_glide.png', sprintf('fig_dashboard_%s_renter.png', label); ...
             'fig_dashboard_full_owner_glide.png',  sprintf('fig_dashboard_%s_owner.png',  label); ...
             'fig_renter_vs_owner_glide.png',       sprintf('fig_renter_vs_owner_%s.png',  label) };
for k = 1:size(produced, 1)
    src = fullfile(scratch, produced{k,1});
    if isfile(src)
        copyfile(src, fullfile(repo, produced{k,2}));
        fprintf('  wrote %s\n', produced{k,2});
    else
        fprintf('  MISSING %s\n', produced{k,1});
    end
end
close all
setenv('CGM_OUTPUT_DIR', '');
end
