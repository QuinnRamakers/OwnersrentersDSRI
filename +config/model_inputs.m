function [profile, shocks, ann_price] = model_inputs(p)
%MODEL_INPUTS  Income profile, survival, shock quadrature and annuity prices.
%
%   [profile, shocks, ann_price] = config.model_inputs(p)
%
%   profile.mu_growth, profile.sigma_l_log   (T-1) x 1 log-income growth and shock std
%   profile.p_surv                           T x 1 one-period survival probabilities
%   shocks                                   Gauss-Hermite nodes (grids.shock_grid)
%   ann_price                                T x 1 unit-annuity prices (pension.annuity_price)

[~, mu_growth, sigma_l_log] = config.income_profile(p);
profile = struct('mu_growth', mu_growth, 'sigma_l_log', sigma_l_log, ...
                 'p_surv', config.survival(p));
shocks    = grids.shock_grid(p);
ann_price = pension.annuity_price(p, profile, shocks);
end
