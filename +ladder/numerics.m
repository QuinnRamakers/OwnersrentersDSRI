function n = numerics(name)
%NUMERICS  Grid, quadrature and panel size for a ladder run.
%
%   n = ladder.numerics('quick' | 'standard' | 'fine')
%
%   One setting is held fixed along the whole ladder, so that differences
%   between steps come from the calibration and not from the numerics.
%
%     quick      [12 12 8], gh_n 3,  4,000 households   for exploring
%     standard   [16 16 10], gh_n 5, 10,000 households  the default
%     fine       [20 20 12], gh_n 5, 10,000 households  as config.params
%
%   dims are base node counts (the entry anchors add up to two on u1 and u2).
%   Steps without housing or a DC pillar collapse the axes the model cannot
%   move along, so they solve in a fraction of the time. CGM_STATE_GRID and
%   CGM_GH_N override the grid for smoke tests (utility.grid_override); the
%   results folder is named after the numerics actually used, so runs at
%   different settings never mix.

switch char(name)
    case 'quick',    n = struct('dims', [12 12 8],  'gh_n', 3, 'N_sim', 4000);
    case 'standard', n = struct('dims', [16 16 10], 'gh_n', 5, 'N_sim', 10000);
    case 'fine',     n = struct('dims', [20 20 12], 'gh_n', 5, 'N_sim', 10000);
    otherwise
        error('ladder:numerics', 'numerics must be quick, standard or fine (got %s).', char(name));
end
[n.dims, n.gh_n] = utility.grid_override(n.dims, n.gh_n);
n.name = char(name);
n.dir  = fullfile(utility.output_dir(), 'ladder', ...
    sprintf('%s_%dx%dx%d_gh%d', n.name, n.dims, n.gh_n));
end
