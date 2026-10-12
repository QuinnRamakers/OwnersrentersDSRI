function [coef, sigma_l] = income_process(p)
%INCOME_PROCESS  Income cubic and permanent shock std for the tenure of p.
%
%   [coef, sigma_l] = config.income_process(p)
%
%   Owners use income_coef and sigma_l_log, renters income_coef_rent and
%   sigma_l_log_rent. Without housing, is_owner still selects the pair, so a
%   step whose two pairs differ is solved once for each tenure
%   (model.tenures_differ). A p-struct without the renter fields falls back to
%   the owner pair, which is what every solve before the split assumed.

is_owner = isfield(p, 'is_owner') && p.is_owner;

if ~is_owner && isfield(p, 'income_coef_rent') && isfield(p, 'sigma_l_log_rent')
    coef    = p.income_coef_rent;
    sigma_l = p.sigma_l_log_rent;
else
    coef    = p.income_coef;
    sigma_l = p.sigma_l_log;
end
end
