function p = case_params(step, arm, name)
%CASE_PARAMS  A ladder step's calibration on one of the grid study's numerics.
%
%   p = case_params(12, 'owner', 'pow2_32x32')
%   p = case_params('dc_stocks', 'renter', 'uniform_64x64_gh7')
%
%   name is <rule>_<N1>x<N2>, optionally followed by _gh<n> (quadrature nodes
%   per shock, 5 otherwise), _makima (the continuation interpolant) and _lim
%   (pi_nothing_saved = 'limit': the share of the first euro saved where
%   nothing is saved, instead of 1). The
%   rule places the base nodes of u1 (income over total resources) and u2
%   (the pension pot's share of non-income wealth) with existing primitives:
%     uniform   evenly spaced, as the ladder's numerics
%     pow2      grid_pow 2 and grid_pow_u2 2: u1 bunched toward its bottom
%               (large resources over income), u2 toward 1 (little liquid
%               saving beside the pot)
%     pow3      the same with power 3; on u1 close to even spacing in the log
%               of total resources over income between 1 and about 300
%     u1pow3    u1 at power 3, u2 at power 2
%     u1only    u1 at power 3, u2 even; u2only the other way round
%   u3 and q keep the standard base counts (10 and 8); without housing they
%   collapse anyway. arm is 'renter' or 'owner' (the no-housing arms of the
%   DC steps). Nothing here changes the model: only grid_dims, grid_pow,
%   grid_pow_u2, gh_n and interp_method are set.

tok = regexp(char(name), '^(\w+?)_(\d+)x(\d+)((?:_\w+)*)$', 'tokens', 'once');
assert(~isempty(tok), 'case_params:name', 'case name %s is not <rule>_<N1>x<N2>[_gh<n>][_makima]', name);
rule = tok{1}; N1 = str2double(tok{2}); N2 = str2double(tok{3}); extra = tok{4};

p = ladder.params(step);
p.is_owner = strcmp(arm, 'owner');
p.grid_dims = [N1 N2 10 8];
p.gh_n = 5;
switch rule
    case 'uniform'
    case 'pow2',   p.grid_pow = 2; p.grid_pow_u2 = 2;
    case 'pow3',   p.grid_pow = 3; p.grid_pow_u2 = 3;
    case 'u1pow3', p.grid_pow = 3; p.grid_pow_u2 = 2;
    case 'u1only', p.grid_pow = 3;        % power 3 on u1, u2 even
    case 'u2only', p.grid_pow_u2 = 3;     % power 3 on u2, u1 even
    otherwise
        error('case_params:rule', 'unknown rule %s', rule);
end
g = regexp(extra, '_gh(\d+)', 'tokens', 'once');
if ~isempty(g), p.gh_n = str2double(g{1}); end
if contains(extra, '_makima'), p.interp_method = 'makima'; end
if contains(extra, '_lim'), p.pi_nothing_saved = 'limit'; end
p = config.derive(p);
end
