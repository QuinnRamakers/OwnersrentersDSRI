function [mu, sigma] = reit_process(p)
%REIT_PROCESS  Log drift and vol of the DC REIT's gross return factor.
%
%   [mu, sigma] = config.reit_process(p)
%
%   The REIT return is lognormal, R_REIT = exp(mu + sigma*z) with z standard
%   normal, calibrated the same way as the stock: mu_REIT_level is an EXCESS
%   return over r_f, so the expected gross return is 1 + r + mu_REIT_level and
%   is invariant to the volatility.
%
%   Unlike config.h_process (which reads the derived p.mu_H / p.mu_R that
%   config.params caches), this derives straight from the LEVEL inputs
%   mu_REIT_level / sigma_REIT_level every call. That is deliberate: it makes
%   the level the single source of truth, so a sweep that overrides
%   p.mu_REIT_level or p.sigma_REIT_level on an existing p-struct takes effect
%   without having to re-run config.params to refresh a cached moment. It also
%   matches utility.param_fingerprint, which keys on the level.
%
%   Absent levels default to 0 (a REIT with no excess return and no vol), so a
%   p-struct that never set them still evaluates.

mu_lvl  = field_or(p, 'mu_REIT_level', 0);
sig_lvl = field_or(p, 'sigma_REIT_level', 0);
sigma   = sqrt(log(1 + (sig_lvl / (1 + p.r + mu_lvl))^2));
mu      = log(1 + p.r + mu_lvl) - 0.5 * sigma^2;
end

function v = field_or(p, f, default)
if isfield(p, f) && ~isempty(p.(f)), v = p.(f); else, v = default; end
end
