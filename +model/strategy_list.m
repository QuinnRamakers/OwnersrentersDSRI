function S = strategy_list()
%STRATEGY_LIST  A first set of DC fund strategies for model.strategies.
%
%   S = model.strategy_list()
%
%   A struct array, one strategy each:
%     name    identifier used in file names; unique
%     label   one line for tables
%     set     overrides of primitives of config.params, applied to the base
%             calibration; empty for the base itself
%
%   The first is the production fund, the reference of the comparison. A fund
%   strategy by age is a glide_rule: 'knots' with glide_knots, rows of
%   [age, stock share, REIT share] (one row: a constant fund), or one of the
%   named rules. Funds that hold risk after 67 pay a variable annuity, priced
%   off the fund. Pass a subset, S(ismember({S.name}, {...})), or build a list
%   of your own with the same three fields. The free choice is last, since it
%   is the slowest solve.
%
%   A starting set (16 November 2026), not a search: no data source for any.

S = struct('name', {}, 'label', {}, 'set', {});
S(end+1) = one('lifecycle', 'Lifecycle: 80% risky to 39, 0% at 67, half REIT (production)', struct());
S(end+1) = one('no_dc',     'No pension account', struct('kappa_base', 0));
S(end+1) = one('bonds',     'All bonds', knots([25 0 0]));
S(end+1) = one('stocks',    'All stocks', knots([25 1 0]));
S(end+1) = one('reit',      'All REIT', knots([25 0 1]));
S(end+1) = one('mix60',     '60% risky (half REIT), 40% bonds', knots([25 0.3 0.3]));
S(end+1) = one('age100',    '100 - age, half REIT', struct('glide_rule', 'age100'));
S(end+1) = one('age100_stocks', '100 - age, stocks only', struct('glide_rule', 'age100', 'reit_risky', 0));
S(end+1) = one('age100_reit',   '100 - age, REIT only', struct('glide_rule', 'age100', 'reit_risky', 1));
S(end+1) = one('reverse',   'Age%, half REIT (risk rising with age)', struct('glide_rule', 'reverse'));
S(end+1) = one('lifecycle_keep20', 'Lifecycle to 20% risky at 67, kept in retirement, half REIT', ...
    knots([25 0.4 0.4; 39 0.4 0.4; 67 0.1 0.1; 100 0.1 0.1]));
S(end+1) = one('free',      'Free choice of the fund''s stock and REIT shares', struct('dc_choice', true));
end

function s = one(name, label, set)
s = struct('name', name, 'label', label, 'set', set);
end

function set = knots(K)
set = struct('glide_rule', 'knots', 'glide_knots', K);
end
