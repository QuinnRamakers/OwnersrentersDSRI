function g = active_grid()
%ACTIVE_GRID  Which coordinate system this session solves on.
%
%   g = utility.active_grid()      % 'lna' (default) or 'simplex'
%
%   The LNA cube (u1,u2,u3) is production. The simplex (lambda,s_A,s_H) is
%   maintained as a full alternative, not a legacy path: both solvers, both
%   simulators and both grid builders are live, and utility.param_fingerprint
%   records which one produced a file so the two can never be ranked against
%   each other by accident. Select the simplex for a session with
%
%       setenv('CGM_GRID', 'simplex')
%
%   This is the ONE place the default lives. config.params reads it, so a
%   p-struct is born already tagged, and the runners inherit it rather than
%   each parsing the environment. Anything that needs the tag off a solved
%   file must read p.grid_type from the file, never call this -- the
%   environment describes the current session, not the file's provenance.

DEFAULT_GRID = 'lna';

g = getenv('CGM_GRID');
if isempty(g), g = DEFAULT_GRID; end
g = char(g);

assert(any(strcmp(g, {'simplex', 'lna'})), 'active_grid:CGM_GRID', ...
    'CGM_GRID must be ''simplex'' or ''lna'', got ''%s''.', g);
end
