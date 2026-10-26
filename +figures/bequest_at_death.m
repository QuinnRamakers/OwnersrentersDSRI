function [x, F, mu, med] = bequest_at_death(d, sc)
%BEQUEST_AT_DEATH  The distribution of the bequest at death in a panel.
%
%   [x, F, mu, med] = figures.bequest_at_death(d, scale)   % d from figures.panel_data
%
%   Every household and age, each age weighted by the chance of dying at its
%   end (d.death_w) and split equally among the households not bankrupt then;
%   the bankrupt leave out of it, as from the other averages. x is the bequest
%   times scale, sorted; F the share of deaths leaving at most x; mu and med
%   the mean and median.

if nargin < 2, sc = 1; end
B  = d.bequest * sc;
ok = ~isnan(B);
W  = repmat(d.death_w ./ max(sum(ok, 1), 1), size(B, 1), 1);
x  = B(ok); w = W(ok);
[x, o] = sort(x); w = w(o) / sum(w);
F  = cumsum(w);
mu = sum(x .* w);
med = x(find(F >= 0.5, 1));
end
