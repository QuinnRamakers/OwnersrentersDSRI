function [corr_HL, corr_SH] = h_corr(p)
%H_CORR  Correlations of the H shock with income and with the stock return, by tenure.
%
%   [corr_HL, corr_SH] = config.h_corr(p)
%
%   The H shock is the house-price return for an owner and the rent increase
%   for a renter (config.h_process), so its correlations are tenure-specific:
%   owners use corr_HL and corr_SH, renters corr_HL_rent and corr_SH_rent. A
%   p-struct without the renter fields falls back to the owner pair.

is_owner = isfield(p, 'is_owner') && p.is_owner;

if ~is_owner && isfield(p, 'corr_HL_rent') && isfield(p, 'corr_SH_rent')
    corr_HL = p.corr_HL_rent;
    corr_SH = p.corr_SH_rent;
else
    corr_HL = p.corr_HL;
    corr_SH = p.corr_SH;
end
end
