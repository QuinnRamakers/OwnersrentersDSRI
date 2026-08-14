function s = grid_suffix(x)
%GRID_SUFFIX  Output-filename tag for a coordinate system.
%
%   s = utility.grid_suffix(p)          % from a p-struct's grid_type
%   s = utility.grid_suffix('lna')      % from a name
%   s = utility.grid_suffix()           % from utility.active_grid()
%
%   Returns '_lna' for the cube and '' for the simplex.
%
%   The asymmetry is deliberate, and survives the cube becoming the default.
%   The alternative -- give the default the bare name and suffix the other --
%   would mean combined_renter.mat denotes a cube file here and a simplex file
%   in every folder, cluster volume and backup written before the switch. One
%   filename, two coordinate systems, no way to tell them apart by name. The
%   fingerprint gate would catch the mix on any comparison, but "caught
%   loudly later" is worse than "impossible", and the README already records
%   what happened the one time stale files got mixed with fresh ones.
%
%   So the rule stays what it has always been: an _lna file is a cube solve, a
%   bare file is a simplex solve. Only which one the runners produce by
%   default has changed.

if nargin < 1 || isempty(x)
    g = utility.active_grid();
elseif isstruct(x)
    assert(isfield(x, 'grid_type'), 'grid_suffix:no_grid_type', ...
        ['p has no grid_type. config.params sets it; a p-struct that ' ...
         'predates the tag is a simplex solve and must be tagged by hand ' ...
         'before it can be named.']);
    g = char(x.grid_type);
else
    g = char(x);
end

switch g
    case 'lna',     s = '_lna';
    case 'simplex', s = '';
    otherwise
        error('grid_suffix:grid_type', ...
            'grid_type must be ''simplex'' or ''lna'', got ''%s''.', g);
end
end
