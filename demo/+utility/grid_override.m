function [dims, gh_n] = grid_override(dims_default, gh_default)
%Override the default grid with this function
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
