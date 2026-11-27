function b = boundary_mode(p)
%BOUNDARY_MODE  p.default_boundary as 'off', 'cont' or 'extend'.
%
%   b = utility.boundary_mode(p)
%
%   A p-struct saved before default_boundary existed reads as 'off'. What
%   the modes do: solver.bellman_step_lna. The mode matters only with default
%   as a choice.
b = 'off';
if isfield(p, 'default_boundary') && ~isempty(p.default_boundary)
    b = validatestring(char(p.default_boundary), {'off', 'cont', 'extend'}, 'boundary_mode', 'p.default_boundary');
end
end
