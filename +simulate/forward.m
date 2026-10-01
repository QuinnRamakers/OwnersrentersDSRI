function sim = forward(p, profile, sol, ann_price, N, seed, X0_frac)
%FORWARD  Monte Carlo simulation of the solved policies.
%
%   sim = simulate.forward(p, profile, sol, ann_price)
%   sim = simulate.forward(p, profile, sol, ann_price, N, seed, X0_frac)
%
%   Defaults: N = 5000 households, seed 20260511, and households entering with
%   p.b0 years of income in liquid wealth -- the state utility.welfare_anchor
%   reads the entry value at. See simulate.paths_lna for the fields returned.

if nargin < 5, N = []; end
if nargin < 6, seed = []; end
if nargin < 7 || isempty(X0_frac), X0_frac = p.b0; end
sim = simulate.paths_lna(p, profile, sol, ann_price, N, seed, X0_frac);
end
