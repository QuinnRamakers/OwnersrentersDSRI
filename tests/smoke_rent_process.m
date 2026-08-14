function smoke_rent_process()
%SMOKE_RENT_PROCESS  Checks for the tenure-conditional H growth process.
%
%   (a) config.h_process returns the rent pair for renters, the housing pair
%       for owners, and falls back to housing for a p-struct that predates the
%       split.
%   (b) With mu_R_level/sigma_R_level left at their defaults the shock grid is
%       identical for both tenures, so the split is a no-op until the rent
%       figures are actually changed.
%   (c) Changing the rent parameters moves the renter's shocks and leaves the
%       owner's untouched.
%   (d) The full solve/simulate chain runs on a coarse grid under both
%       calibrations, and a lower rent drift lowers the renter's rent path and
%       the incidence of zero consumption.
%
%   Coarse grid throughout -- this is a plumbing check, not a calibration run.

fprintf('smoke_rent_process\n');
n_fail = 0;

p = config.params();
% Pinned to the simplex: this file drives the simplex solver/simulator
% directly, and config.params now defaults to the cube (utility.active_grid).
p.grid_type = 'simplex';
pr = p; pr.is_owner = false;
po = p; po.is_owner = true;

% (a) selector
[mr, sr] = config.h_process(pr);
[mo, so] = config.h_process(po);
n_fail = n_fail + check('renter uses the rent pair', isequal([mr sr], [p.mu_R p.sigma_R]));
n_fail = n_fail + check('owner uses the housing pair', isequal([mo so], [p.mu_H p.sigma_H]));

legacy = rmfield(pr, {'mu_R', 'sigma_R', 'mu_R_level', 'sigma_R_level'});
[ml, sl] = config.h_process(legacy);
n_fail = n_fail + check('legacy p-struct falls back to housing', ...
                        isequal([ml sl], [p.mu_H p.sigma_H]));

% (b) the calibrated rent process really is distinct from the house process,
% and setting it equal collapses the two tenures back onto one process
s_r = grids.shock_grid(pr);
s_o = grids.shock_grid(po);
n_fail = n_fail + check('calibrated rent process differs from the house process', ...
                        ~isequal(s_r.joint.R_H, s_o.joint.R_H));
p_same = set_rent(pr, p.mu_H_level, p.sigma_H_level);
s_same = grids.shock_grid(p_same);
n_fail = n_fail + check('equating the two calibrations collapses them onto one process', ...
                        isequal(s_same.joint.R_H, s_o.joint.R_H) && isequal(s_same.R_H, s_o.R_H));

% (c) the split bites once the rent figures move
pr2 = set_rent(pr, 0.005, 0.02);
po2 = pr2; po2.is_owner = true;
s_r2 = grids.shock_grid(pr2);
s_o2 = grids.shock_grid(po2);
n_fail = n_fail + check('rent parameters move the renter', ~isequal(s_r2.joint.R_H, s_r.joint.R_H));
n_fail = n_fail + check('rent parameters leave the owner alone', isequal(s_o2.joint.R_H, s_o.joint.R_H));

% (d) end-to-end
base = config.params();
% Pinned to the simplex: this file drives the simplex solver/simulator
% directly, and config.params now defaults to the cube (utility.active_grid).
base.grid_type = 'simplex';
base.is_owner = false;
base.legacy_fill = false;
base = utility.build_state_grids(base, [10 8 8], 3);
base.N_c = 9; base.N_pi = 9;

% Distress is measured as how often the consumption floor binds. C = 0 is
% extinct once the floor is on, so the old zero-consumption count no longer
% separates anything -- see tests/smoke_consumption_floor.
[rent_hi, ruin_hi] = solve_and_sim(set_rent(base, 0.027, 0.037));  % house-price drift
[rent_lo, ruin_lo] = solve_and_sim(set_rent(base, 0.005, 0.02));   % lower drift

fprintf('  2.7%% drift: rent @67 = %8.0f, floor binds in %.1f%% of household-years\n', rent_hi, 100*ruin_hi);
fprintf('  0.5%% drift: rent @67 = %8.0f, floor binds in %.1f%% of household-years\n', rent_lo, 100*ruin_lo);
n_fail = n_fail + check('lower rent drift lowers the rent path', rent_lo < rent_hi);
n_fail = n_fail + check('lower rent drift lowers distress incidence', ruin_lo < ruin_hi);

if n_fail == 0
    fprintf('smoke_rent_process: all checks passed\n');
else
    error('smoke_rent_process:fail', '%d check(s) failed', n_fail);
end
end

function q = set_rent(q, mu_level, sigma_level)
q.mu_R_level    = mu_level;
q.sigma_R_level = sigma_level;
q.sigma_R = sqrt(log(1 + (sigma_level / (1 + mu_level))^2));
q.mu_R    = log(1 + mu_level) - 0.5 * q.sigma_R^2;
end

function [rent_ret, ruin] = solve_and_sim(q)
[~, mg, sl] = config.income_profile(q);
profile.mu_growth   = mg;
profile.sigma_l_log = sl;
profile.p_surv      = config.survival(q);
shocks    = grids.shock_grid(q);
ann_price = pension.annuity_price(q, profile, shocks);
sol       = solver.solve_lifecycle(q, profile, shocks, ann_price);
sim       = simulate.paths(q, profile, sol, ann_price, 1500, 7, q.b0);
rent_ret  = median(q.alpha * sim.H(:, q.t_ret));
phi       = 0; if isfield(q, 'phi_floor'), phi = q.phi_floor; end
if phi > 0
    ruin = mean(sim.LW(:) < phi * sim.Y(:));   % floor binds
else
    ruin = mean(sim.C(:) <= 0);                % pre-floor convention
end
end

function bad = check(name, ok)
if ok
    fprintf('  ok   %s\n', name);
    bad = 0;
else
    fprintf('  FAIL %s\n', name);
    bad = 1;
end
end
