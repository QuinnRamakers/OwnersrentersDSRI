function G = case_gaps(r, ref, bands)
%CASE_GAPS  Largest gaps of one solve to a reference, by age band.
%
%   G = case_gaps(r, ref)
%   G = case_gaps(r, ref, {[25 39], [40 54], [55 66], [67 89], [90 95]})
%
%   Means over the same simulated households (same seed and size). Bands are
%   ages 26-39, 40-66 and 67-95 unless given as a cell of [first last] ages.
%   Fields, each 1 x the number of bands:
%     pi   largest |difference| in the mean liquid equity share
%     C    largest |difference| in mean consumption, share of the reference
%     X    largest |difference| in mean liquid savings, in years of the
%          reference's mean income at that age
%     piw  largest |difference| in the equity share of liquid saving, all
%          households' stock holdings over their liquid saving. Unlike the
%          mean share it gives no weight to households that save nothing,
%          whose share has no effect; ages where liquid saving is under 1%
%          of income are left out (computed when both results carry the
%          field piw, added by case_load)
%   and the same over 26-95 as pi_all, C_all, X_all with the age where each
%   is reached (pi_age, C_age, X_age). The ladder's stop rule is 0.02 in the
%   equity share and 2% in consumption.

if nargin < 3, bands = {[26 39], [40 66], [67 95]}; end
s0 = ref.summary; s1 = r.summary;
a = s0.ages;
nb = numel(bands);
bands = cellfun(@(b) a >= b(1) & a <= b(2), bands, 'UniformOutput', false);
if isfield(r, 'piw') && isfield(ref, 'piw')
    dpw = abs(r.piw - ref.piw);
else
    dpw = nan(size(a));
end
dpi = abs(s1.pi - s0.pi);
dC  = abs(s1.C.mean ./ s0.C.mean - 1);
dX  = abs(s1.X.mean - s0.X.mean) ./ s0.Y.mean;
G = struct('pi', zeros(1, nb), 'C', zeros(1, nb), 'X', zeros(1, nb), 'piw', zeros(1, nb));
for b = 1:nb
    w = bands{b};
    G.pi(b) = max(dpi(w)); G.C(b) = max(dC(w)); G.X(b) = max(dX(w)); G.piw(b) = max(dpw(w));
end
w = a >= 26 & a <= 95;
[G.pi_all, i] = max(dpi .* w); G.pi_age = a(i);
[G.C_all, i]  = max(dC .* w);  G.C_age  = a(i);
[G.X_all, i]  = max(dX .* w);  G.X_age  = a(i);
end
