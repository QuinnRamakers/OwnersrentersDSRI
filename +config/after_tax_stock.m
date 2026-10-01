function R_S_at = after_tax_stock(p, R_S)
%AFTER_TAX_STOCK  Liquid-account equity return after box-3 CGT and wealth tax.
%
%   R_S_at = config.after_tax_stock(p, R_S)
%
%   R_S is a gross return factor, so the period's gain is R_S - 1. The DC fund
%   is sheltered and never passes through here; this is the taxable private
%   account only.
%
%   p.cg_loss_offset selects the treatment of a losing year:
%
%     false (default)  Tax is levied on positive gains only. A loss earns no
%                      rebate, so the household keeps (1 - tau_s) of the upside
%                      and carries all of the downside. This is the calibrated
%                      box-3 treatment and what every solve before the flag
%                      existed used.
%
%     true             Tax is levied on the gain whatever its sign, so a loss is
%                      rebated at the same rate. Symmetric, and it leaves a
%                      larger after-tax equity premium.
%
%   The asymmetry is not a detail. At the production calibration (tau_s = 0.36,
%   4% excess return, 16% vol) the no-offset rule cuts the after-tax equity
%   premium from 4.0% to 1.2%, which is most of the reason the model's liquid
%   equity share sits far below what a pre-tax calibration implies. Switching
%   the flag on is a change to the modelled tax system, not a numerical tweak.
%
%   Still linear in the balance, so the homothetic z-transform is unaffected
%   either way.

tau_s = 0; if isfield(p, 'tau_cg_stock'), tau_s = p.tau_cg_stock; end
tau_w = 0; if isfield(p, 'tau_wealth'),   tau_w = p.tau_wealth;   end

if isfield(p, 'cg_loss_offset') && ~isempty(p.cg_loss_offset) && p.cg_loss_offset
    gain = R_S - 1;
else
    gain = max(R_S - 1, 0);
end

R_S_at = (R_S - tau_s .* gain) .* (1 - tau_w);
end
