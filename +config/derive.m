function p = derive(p)
%DERIVE  Everything that follows from the primitive inputs in config.params.
%
%   p = config.derive(p)
%
%   Rebuilds, from the primitives alone: the log-return moments of the three
%   lognormal processes, the retirement period, the DC glide path, the
%   contribution-rate profile, the house at entry (h_mult, from h_rule), the
%   mortgage schedule, the periods in which the
%   purchase-price ratio q is a state, and the state grid with the entry-state
%   anchors. Nothing is carried over from an earlier call, so
%   it is safe to run after any override -- change a primitive, call this, and
%   no derived field is left stale.

p.grid_type = 'lna';

% Lognormal gross returns. Stock levels are an excess return over r_f; the
% house and the rent index are own returns.
p.Rf      = 1 + p.r;
p.sigma_S = sqrt(log(1 + (p.sigma_S_level / (1 + p.r + p.mu_S_level))^2));
p.mu_S    = log(1 + p.r + p.mu_S_level) - 0.5 * p.sigma_S^2;
p.sigma_H = sqrt(log(1 + (p.sigma_H_level / (1 + p.mu_H_level))^2));
p.mu_H    = log(1 + p.mu_H_level) - 0.5 * p.sigma_H^2;
p.sigma_R = sqrt(log(1 + (p.sigma_R_level / (1 + p.mu_R_level))^2));
p.mu_R    = log(1 + p.mu_R_level) - 0.5 * p.sigma_R^2;

p.t_ret = p.retirement_age - p.age0 + 1;

% DC glide path over the T-1 transitions: glide_cap far from retirement, then
% linear to zero at retirement, zero after.
ages    = (p.age0 : p.age0 + p.T - 2).';
glide   = max(0.0, min(p.glide_cap, (p.retirement_age - ages) / p.glide_span));
glide(ages >= p.retirement_age) = 0.0;
p.tau_S = glide;

assert(p.LTV == 1.00, 'derive:LTV', ...
    ['LTV = %.4f: only 1.00 is implemented. A lower LTV needs a down-payment ' ...
     'endowment the model does not have.'], p.LTV);
assert(p.phi_floor > 0, 'derive:phi_floor', ...
    'phi_floor must be positive: utility is unbounded below at zero consumption.');
alloc = config.tau_effective(p) + config.reit_effective(p);
assert(all(alloc <= 1 + 1e-12), 'derive:reit_alloc', ...
    'tau_S + tau_REIT exceeds 1 at some age (max %.4f): the fund bond leg would go negative.', ...
    max(alloc));
% The franchise is a euro amount and the 'poly' profile is not in euros, so
% contributions would silently compute to zero.
assert(~(p.kappa_base > 0 && strcmp(p.income_source, 'poly')), 'derive:poly_dc', ...
    'A DC pillar needs income in euros: use income_source = ''dhs'' or ''table''.');

% Contribution rate on gross income, from the franchise rule on the
% deterministic profile. Realised income cannot enter: only Y/W is a state.
% The profile is the tenure's (config.income_process), so derive again after
% changing is_owner.
logY_det = config.income_profile(p);
Y_det    = exp(logY_det);
p.kappa  = zeros(p.T, 1);
work_t   = 1 : (p.t_ret - 1);
p.kappa(work_t) = p.kappa_base .* max(Y_det(work_t) - p.franchise, 0) ./ Y_det(work_t);

% House (owner) or rent index (renter) at entry as a multiple of income, h_mult.
% 'none': no housing, h_mult = 0. 'fixed': h_fixed. 'nibud': the largest
% mortgage the Nibud norms allow at the tenure's gross income at age0 and the
% mortgage rate; with LTV = 1 the loan is the house. The rest of the model
% reads h_mult, and h_mult = 0 means no housing.
assert((ischar(p.h_rule) || isstring(p.h_rule)) && any(strcmp(char(p.h_rule), {'none', 'fixed', 'nibud'})), ...
    'derive:h_rule', 'h_rule must be ''none'', ''fixed'' or ''nibud'' (got %s).', mat2str(p.h_rule));
switch char(p.h_rule)
    case 'none'
        p.h_mult = 0;
    case 'fixed'
        assert(p.h_fixed > 0, 'derive:h_fixed', ...
            'h_rule = ''fixed'' needs h_fixed > 0 (got %g); use h_rule = ''none'' for no housing.', p.h_fixed);
        p.h_mult = p.h_fixed;
    case 'nibud'
        assert(~strcmp(p.income_source, 'poly'), 'derive:poly_nibud', ...
            'The Nibud rule needs income in euros: use income_source = ''dhs'' or ''table''.');
        p.h_mult = config.nibud_lti(Y_det(1), p.r_m, p.nibud_extra);
end

% Mortgage payment per euro of purchase price for N_mort years: LTV times the
% annuity factor at r_m. The annuity charges it on the purchase price, q*H;
% the proportional contract on the current house value, H.
assert((ischar(p.mortgage) || isstring(p.mortgage)) && ...
    any(strcmp(char(p.mortgage), {'annuity', 'proportional'})), 'derive:mortgage', ...
    'mortgage must be ''annuity'' or ''proportional'' (got %s).', mat2str(p.mortgage));
assert(isscalar(p.maint_on_purchase) && any(p.maint_on_purchase == [0 1]), ...
    'derive:maint_on_purchase', 'maint_on_purchase must be true or false.');
amort_rate    = p.LTV * p.r_m * (1 + p.r_m)^p.N_mort / ((1 + p.r_m)^p.N_mort - 1);
p.m_rate_path = zeros(p.T - 1, 1);
p.m_rate_path(1 : min(p.N_mort, p.T - 1)) = amort_rate;

% q = H0/H is a state in the periods where it enters an owner's budget: while
% the annuity is paid, and at every age when maintenance is on the purchase
% price.
pays     = (1 : p.T).' <= min(p.N_mort, p.T - 1);
annuity  = strcmp(char(p.mortgage), 'annuity');
p.q_live = (p.is_owner && p.h_mult > 0) & ((annuity & pays) | logical(p.maint_on_purchase));

p = utility.build_state_grids(p, p.grid_dims, p.gh_n);
end
