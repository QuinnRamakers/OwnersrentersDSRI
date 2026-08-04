function [dims, gh_n] = grid_override(dims_default, gh_default)
%GRID_OVERRIDE  Environment override for a runner's hardcoded state grid.
%
%   [dims, gh_n] = utility.grid_override([25 15 15], 5)
%
%   Returns dims_default / gh_default unless the environment supplies
%   CGM_STATE_GRID and/or CGM_GH_N, in which case those win:
%
%       CGM_STATE_GRID = "12 10 12"   (or "12,10,12") -> dims  = [12 10 12]
%       CGM_GH_N       = "3"                          -> gh_n  = 3
%
%   Motivation: run_combined.m and run_nodc.m both hardcode the sweep grid
%   that makes their welfare numbers comparable to run_spline_strategies.m,
%   and that grid is deliberately not a parameter -- changing it silently
%   would break the comparability the docstrings promise. But a smoke test
%   needs a much smaller grid to finish in minutes rather than hours, and
%   before this helper the only way to get one was to edit the runner, which
%   means the thing being smoke-tested is not the thing that ships.
%
%   So the default path is unchanged and the override is opt-in, explicit,
%   and loud: the caller is expected to print the grid it ended up with (both
%   runners do). Do NOT set these variables for a production solve -- the
%   resulting .mat is not welfare-comparable to the spline sweep, and
%   utility.param_fingerprint will (correctly) fence it off from files solved
%   at the default grid.
%
%   dims is passed straight to utility.build_state_grids, which re-inserts
%   the welfare anchors and can return N_lambda/N_sH up to +2 larger.

dims = dims_default;
gh_n = gh_default;

raw = getenv('CGM_STATE_GRID');
if ~isempty(raw)
    v = sscanf(strrep(raw, ',', ' '), '%f').';
    assert(numel(v) == 3 && all(v == round(v)) && all(v >= 2), ...
        'grid_override:CGM_STATE_GRID', ...
        ['CGM_STATE_GRID must be three integers >= 2, e.g. "12 10 12" ' ...
         '(got "%s").'], raw);
    dims = v;
end

raw = getenv('CGM_GH_N');
if ~isempty(raw)
    v = sscanf(raw, '%f');
    assert(isscalar(v) && v == round(v) && v >= 1, 'grid_override:CGM_GH_N', ...
        'CGM_GH_N must be a positive integer (got "%s").', raw);
    gh_n = v;
end
end
