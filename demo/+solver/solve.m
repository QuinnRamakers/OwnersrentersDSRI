function sol = solve(p, profile, shocks, ann_price)
%wrapper function toverify input and then solve a model

assert(isfield(p, 'grid_type') && strcmp(char(p.grid_type), 'lna'), ...
    'solve:grid_type', 'p.grid_type must be ''lna'' (got ''%s'').', ...
    char(string(getfield_default(p, 'grid_type', 'unset'))));

sol = solver.solve_lifecycle_lna(p, profile, shocks, ann_price);
end

function v = getfield_default(s, f, d)
v = d;
if isfield(s, f) && ~isempty(s.(f)), v = s.(f); end
end
