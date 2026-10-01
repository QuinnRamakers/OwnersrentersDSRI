function [dims, gh_n] = grid_override(dims_default, gh_default)
%GRID_OVERRIDE  Environment override for the state grid, for quick runs.
%
%   [dims, gh_n] = utility.grid_override(p.grid_dims, p.gh_n)
%
%   Returns the defaults unless the environment sets CGM_STATE_GRID and/or
%   CGM_GH_N, in which case those win:
%
%       setenv('CGM_STATE_GRID', '8 6 6')   % or '8,6,6'
%       setenv('CGM_GH_N', '3')
%
%   This exists so a smoke test can run the same code on a small grid without
%   editing anything. Clear both variables (setenv(name, '')) before a run
%   whose output is used. dims are base counts; see utility.build_state_grids.

dims = dims_default;
gh_n = gh_default;

raw = getenv('CGM_STATE_GRID');
if ~isempty(raw)
    v = sscanf(strrep(raw, ',', ' '), '%f').';
    assert(numel(v) == 3 && all(v == round(v)) && all(v >= 2), ...
        'grid_override:CGM_STATE_GRID', ...
        'CGM_STATE_GRID must be three integers >= 2, e.g. "12 10 12" (got "%s").', raw);
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
