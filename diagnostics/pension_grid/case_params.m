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
%     age, ageq, age32   points that follow age (age_grid), placed from a
%               pilot solve of the same step (see the case below)
%     logw      the log-wealth rule of the step-7 grid study
%               (diagnostics/grid_design/grid_rule.m, on the path)
%   u3 and q keep the standard base counts (10 and 8) unless a suffix below
%   sets them; without housing or a DC pillar u3 collapses anyway, and q is a
%   single node where it is not a state (renters). arm is 'renter' or 'owner'.
%   More suffixes:
%     _mop      maint_on_purchase (maintenance on the purchase price), the
%               housing variant without the ruin cliff; it changes the model
%     _mcv      maint_on_purchase = false (maintenance on the current house
%               value), for steps 17-18, which charge the purchase price; it
%               changes the model
%     _u3x2     u3 (pension against house) at twice its base points
%     _u3n<n>   u3 at n base points instead of 10
%     _u3p<n>   u3 bunched toward 0 with grid_pow_u3 = n
%     _u3even   u3 evenly spaced (grid_pow_u3 = 1). This is the default, so
%               it only writes the placement into the case name
%     _qn<n>    q (purchase price over house) at n base points instead of 8;
%               q = 1 is spliced in on top
%     _lhi<n>   top of the u1 axis lambda_hi = n/100 (_lhi30 is 0.30), in
%               place of min(0.9, 3/(1+h_mult)); W/Y = 1/u1 then starts at
%               100/n. Households above it are off the grid (model.checks
%               offgrid) and get the flat value at the top node
%     _qhi<n>   top of the q axis q_hi = n/10 (_qhi13 is 1.3), in place of 2.5;
%               at least 1. Owners whose house price fell further are off
%               the grid
%     _nosweep  the global (c, pi) grid search before fmincon switched off
%               (use_refine = false)
%     _as, _sqp the local solve with fmincon's active-set or sqp algorithm
%     _ip       the local solve with interior-point, the default before 24
%               October 2026 (evening); with _nc41 it reproduces the solves
%               saved before then without a routine suffix
%     _util     fmincon on the objective in utility units instead of
%               certainty-equivalent units (fmincon_objective = 'utility')
%     _nc<n>    N_c = n: the sweep's later rounds start from a consumption
%               half-width of (1 - c_floor)/(4(n-1)); _nc11 makes it the
%               first round's half-step (docs/SOLVER_BOUNDS.md, section 2)
%     _cmin<n>  the absorbing consumption floor at c_min = n euros a year
%               (_cmin8000); it changes the model
%     _exact    with the absorbing floor, the bankruptcy test at each
%               quadrature node (abs_node_test = true, the default since
%               24 October 2026; the name marks solves made after that)
%     _interp   the same with abs_node_test = false, the setting of the
%               _cmin solves of 23 October that carry no _exact
%     _beqb<n>  the bequest motive at b = n/10 (_beqb25 is 2.5): chi = b^gamma
%               at the step's gamma, so b = chi^(1/gamma), about the bequest
%               over the last year's consumption, is the same on every step
%               (Quinn, 26 October 2026); it changes the model
%     _reit<n>  the REIT leg of the DC fund at a share of n/100 at every age
%               (_reit10 is 10%, the old placeholder share) in place of the
%               glide's split (reit_risky = 0), with the calibration tables'
%               moments (Table 1: excess return 5.43%, vol 24.48%) and gross
%               pooled correlations (Table 3: income 0.09, stock 0.76, the
%               tenure's H shock: corr_RH 0.17 with the house price for
%               owners, corr_RH_rent 0.59 with the rent for renters). It
%               changes the model
%     _rr<n>    the REIT at n% of the fund's risky share (reit_risky =
%               n/100): the glide's risky share min(0.8, years to retirement /
%               35) is split into stocks, 1 - n/100 of it, and the REIT, so
%               the bond leg and the all-bond fund in retirement are as
%               without the REIT. _rr100 holds no stocks in the fund.
%               Moments and correlations as _reit<n>. Production since step
%               19 is _rr50. It changes the model
%     _rh<n>    with the REIT on (_reit, _rr or step 19), the REIT's
%               correlation with the H shock set to n/100 for both tenures
%               instead of the tables' value (_rh0: a REIT uncorrelated with
%               rent or the house price). It changes the model
%     _rgh<n>   gh_n_reit = n quadrature nodes for the REIT shock (gh_n
%               otherwise)
%   Apart from _mop, _mcv, _cmin, _beqb, _reit, _rr and _rh nothing here changes the model: only grid_dims,
%   grid_pow, grid_pow_u2, grid_pow_u3, lambda_hi, q_hi, grid_nodes, gh_n,
%   gh_n_reit, interp_method, use_refine, fmincon_algorithm, fmincon_objective, N_c,
%   pi_nothing_saved and abs_node_test are set.

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
    case {'age', 'age32', 'ageq'}
        % Points that follow age (age_grid), placed from the panel of the same
        % step solved on the power-3 grid with the limit share: 16x16 for
        % 'age' and 'ageq' (a cheap pilot), 32x32 for 'age32'. 'ageq' moves
        % the points inside the band halfway to the households' percentiles.
        pilot = 'pow3_16x16_lim'; if strcmp(rule, 'age32'), pilot = 'pow3_32x32_lim'; end
        rp = case_load(step, arm, pilot);
        assert(~isempty(rp), 'case_params:pilot', 'the pilot %s of step %s %s is not solved.', pilot, string(step), arm);
        p.grid_pow = 3; p.grid_pow_u2 = 3;
        if strcmp(rule, 'ageq')
            p.grid_nodes = age_grid(rp, N1, N2, blend = 0.5, band = [1 99], d = 1e-3);
        else
            p.grid_nodes = age_grid(rp, N1, N2);
        end
    case 'u1only', p.grid_pow = 3;        % power 3 on u1, u2 even
    case 'u2only', p.grid_pow_u2 = 3;     % power 3 on u2, u1 even
    case 'logw'
        % The log-wealth rule of the step-7 grid study (diagnostics/grid_design)
        p.grid_nodes = grid_rule('logwealth', N1, N2, config.derive(p));
    otherwise
        error('case_params:rule', 'unknown rule %s', rule);
end
g = regexp(extra, '_gh(\d+)', 'tokens', 'once');
if ~isempty(g), p.gh_n = str2double(g{1}); end
if contains(extra, '_makima'), p.interp_method = 'makima'; end
if contains(extra, '_lim'), p.pi_nothing_saved = 'limit'; end
if contains(extra, '_mop'), p.maint_on_purchase = true; end
if contains(extra, '_mcv'), p.maint_on_purchase = false; end                % maintenance on the current value
if contains(extra, '_u3x2'), p.grid_dims(3) = 2 * p.grid_dims(3); end      % pension-against-house axis doubled
g = regexp(extra, '_u3n(\d+)', 'tokens', 'once');
if ~isempty(g), p.grid_dims(3) = str2double(g{1}); end                     % u3 base points
g = regexp(extra, '_qn(\d+)', 'tokens', 'once');
if ~isempty(g), p.grid_dims(4) = str2double(g{1}); end                     % q base points
g = regexp(extra, '_u3p(\d+)', 'tokens', 'once');
if ~isempty(g), p.grid_pow_u3 = str2double(g{1}); end                      % u3 bunched toward 0
if contains(extra, '_u3even'), p.grid_pow_u3 = 1; end                      % u3 evenly spaced
g = regexp(extra, '_lhi(\d+)', 'tokens', 'once');
if ~isempty(g), p.lambda_hi = str2double(g{1}) / 100; end                  % top of u1
g = regexp(extra, '_qhi(\d+)', 'tokens', 'once');
if ~isempty(g), p.q_hi = str2double(g{1}) / 10; end                        % top of q
if contains(extra, '_nosweep'), p.use_refine = false; end                  % fmincon from the warm start, no grid search
if contains(extra, '_as'), p.fmincon_algorithm = 'active-set'; end         % local solve
if contains(extra, '_sqp'), p.fmincon_algorithm = 'sqp'; end
if contains(extra, '_ip'), p.fmincon_algorithm = 'interior-point'; end
if contains(extra, '_util'), p.fmincon_objective = 'utility'; end
g = regexp(extra, '_nc(\d+)', 'tokens', 'once');
if ~isempty(g), p.N_c = str2double(g{1}); end                              % sweep's consumption step
g = regexp(extra, '_cmin(\d+)', 'tokens', 'once');
if ~isempty(g), p.c_min = str2double(g{1}); end                            % absorbing floor, euros
if contains(extra, '_exact'), p.abs_node_test = true; end                  % bankruptcy tested at the quadrature nodes
if contains(extra, '_interp'), p.abs_node_test = false; end                % interpolated across the edge
g = regexp(extra, '_beqb(\d+)', 'tokens', 'once');
if ~isempty(g), p.chi = (str2double(g{1}) / 10) ^ p.gamma; end             % bequest at b = chi^(1/gamma)
g = regexp(extra, '_reit(\d+)', 'tokens', 'once');
if ~isempty(g)                                                             % REIT leg at a share of the fund
    p.tau_REIT = str2double(g{1}) / 100; p.reit_risky = 0;
    p = reit_tables(p);
end
g = regexp(extra, '_rr(\d+)', 'tokens', 'once');
if ~isempty(g)                                                             % REIT as a share of the glide's risky part
    p.reit_risky = str2double(g{1}) / 100;
    p = reit_tables(p);
end
g = regexp(extra, '_rh(\d+)', 'tokens', 'once');
if ~isempty(g)                                                             % REIT with the H shock, in place of Table 3
    assert(config.reit_active(p), 'case_params:rh', '_rh needs the REIT on: _reit, _rr or step 19');
    p.corr_RH = str2double(g{1}) / 100; p.corr_RH_rent = p.corr_RH;
end
g = regexp(extra, '_rgh(\d+)', 'tokens', 'once');
if ~isempty(g), p.gh_n_reit = str2double(g{1}); end                        % REIT quadrature nodes
p = config.derive(p);
end

function p = reit_tables(p)
% The calibration tables' REIT moments (Table 1) and gross pooled correlations
% (Table 3), production's values since step 19
p.mu_REIT_level = 0.0543; p.sigma_REIT_level = 0.2448;
p.corr_RL = 0.09; p.corr_RS = 0.76;
p.corr_RH = 0.17; p.corr_RH_rent = 0.59;                                   % house price for owners, rent for renters
end
