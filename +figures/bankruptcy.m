function B = bankruptcy(d, p)
%BANKRUPTCY  Share of households bankrupt, or at the floor, by age.
%
%   B = figures.bankruptcy(d, p)   % d from figures.panel_data, p the result's parameters
%
%   With the absorbing floor, B.cum is the % of households bankrupt by each
%   age (bankruptcy lasts for life) and B.rate the % of those not yet bankrupt
%   who go bankrupt at that age. With the yearly top-up, B.cum is the % ever
%   floored by each age and B.rate the % floored at that age. B.label is
%   'bankrupt' or 'floored'; B.cum_label and B.rate_label describe the two
%   series. The panel has no mortality, so the shares are of the households
%   alive at each age.

s = d.sim;
[absorbing, B.label] = model.floor_kind(p);
if absorbing && isfield(s, 'absorbed')
    M = logical(s.absorbed);
    before = [false(size(M, 1), 1), M(:, 1:end-1)];
    B.cum  = 100 * mean(M, 1);
    B.rate = 100 * sum(M & ~before, 1) ./ max(sum(~before, 1), 1);
    B.cum_label  = '% bankrupt by this age';
    B.rate_label = '% going bankrupt at this age';
else
    F = logical(s.floored);
    B.cum  = 100 * mean(cummax(F, 2), 1);
    B.rate = 100 * mean(F, 1);
    B.cum_label  = '% ever at the floor by this age';
    B.rate_label = '% at the floor at this age';
end
end
