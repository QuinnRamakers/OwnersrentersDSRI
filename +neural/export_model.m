function m = export_model(p, profile, ann_price, file)
%EXPORT_MODEL  The numbers the Julia model year needs, from a derived calibration.
%
%   m = neural.export_model(p, profile, ann_price)
%   m = neural.export_model(p, profile, ann_price, file)   % also saves m
%
%   p must be derived for its tenure (config.derive after setting is_owner);
%   profile and ann_price come from config.model_inputs(p). Every field of m
%   is a number or a vector, and the Julia code in neural/src reads them and
%   derives nothing itself. Vectors by age have T elements, or T - 1 for the
%   transitions from t to t + 1, as in simulate.paths_lna. The policies
%   themselves are not exported.

T = p.T;
m = struct();
m.T = T;
m.t_ret = p.t_ret;
m.age0 = p.age0;
m.is_owner = double(p.is_owner);
m.gamma = p.gamma;
m.beta = p.beta;
m.chi = p.chi;
m.beq_bankrupt = p.beq_bankrupt;
m.beq_shift = p.beq_shift;

% Taxes and returns
m.tau_inc = p.tau_inc;
m.tau_cg_bond = p.tau_cg_bond;
m.tau_wealth = p.tau_wealth;
m.tau_cg_stock = 0; if isfield(p, 'tau_cg_stock'), m.tau_cg_stock = p.tau_cg_stock; end
m.cg_loss_offset = double(isfield(p, 'cg_loss_offset') && ~isempty(p.cg_loss_offset) && p.cg_loss_offset);
m.r = p.r;
m.Rf = p.Rf;
m.mu_S = p.mu_S;
m.sigma_S = p.sigma_S;
[m.mu_H, m.sigma_H] = config.h_process(p);
[m.corr_HL, m.corr_SH, m.corr_RH] = config.h_corr(p);
m.corr_SL = p.corr_SL;
m.corr_RL = p.corr_RL;
m.corr_RS = p.corr_RS;
[m.mu_REIT, m.sigma_REIT] = config.reit_process(p);
m.reit_on = double(config.reit_active(p));
m.tau_e = config.tau_effective(p);
m.reit_e = config.reit_effective(p);
m.dc_choice = double(isfield(p, 'dc_choice') && p.dc_choice);

% Income, contributions, survival and the annuity
logY = config.income_profile(p);
m.Y0 = exp(logY(1));
m.b0 = p.b0;
m.replacement = p.replacement;
m.kappa = p.kappa(min((1:T)', numel(p.kappa)));
m.mu_growth = profile.mu_growth(:);
m.sigma_l_log = profile.sigma_l_log(:);
m.p_surv = profile.p_surv(:);
m.ann_price = ann_price(:);

% Housing
m.h_mult = p.h_mult;
m.alpha = p.alpha;
m.theta = p.theta;
m.sell_cost = p.sell_cost;
m.annuity = double(strcmp(p.mortgage, 'annuity'));
m.maint_on_purchase = double(p.maint_on_purchase);
m.m_rate = zeros(T, 1);
n = min(numel(p.m_rate_path), T);
m.m_rate(1:n) = p.m_rate_path(1:n);

% The floor
m.floor_absorbing = double(isfield(p, 'floor_absorbing') && p.floor_absorbing);
m.default_choice = double(isfield(p, 'default_choice') && p.default_choice);
m.phi_floor = p.phi_floor;
m.phi_path = p.phi_floor * ones(T, 1);
if isfield(p, 'phi_path'), m.phi_path = p.phi_path(:); end
m.D_abs = p.D_abs(:);
m.D_beq = p.D_beq(:);

% The correlation of the draws, in the order income, stock, house, REIT
m.chol = neural.draw_shocks(p, 1, 1).L;

if nargin >= 4 && ~isempty(file)
    save(file, '-struct', 'm', '-v7');
end
end
