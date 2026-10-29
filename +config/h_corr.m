function [corr_HL, corr_SH, corr_RH] = h_corr(p)
%H_CORR  Correlations of the H shock with income, the stock and the REIT, by tenure.
%
%   [corr_HL, corr_SH, corr_RH] = config.h_corr(p)
%
%   The H shock is the house-price return for an owner and the rent increase
%   for a renter (config.h_process), so its correlations are tenure-specific:
%   owners use corr_HL, corr_SH and corr_RH, renters corr_HL_rent,
%   corr_SH_rent and corr_RH_rent. A p-struct without the renter fields falls
%   back to the owner's, and one without corr_RH (saved before the REIT leg)
%   reads it as 0.

is_owner = isfield(p, 'is_owner') && p.is_owner;

if ~is_owner && isfield(p, 'corr_HL_rent') && isfield(p, 'corr_SH_rent')
    corr_HL = p.corr_HL_rent;
    corr_SH = p.corr_SH_rent;
else
    corr_HL = p.corr_HL;
    corr_SH = p.corr_SH;
end

corr_RH = 0;
if isfield(p, 'corr_RH') && ~isempty(p.corr_RH), corr_RH = p.corr_RH; end
if ~is_owner && isfield(p, 'corr_RH_rent') && ~isempty(p.corr_RH_rent)
    corr_RH = p.corr_RH_rent;
end
end
