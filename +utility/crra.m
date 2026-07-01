function u = crra(c, gamma)
%CRRA  Un-normalised CRRA: u(c) = c^(1-gamma)/(1-gamma).
%
%   Required for the homothetic Bellman in the pension model:
%       V(W, lam, sA) = W^(1-gamma) * V_tilde(lam, sA)
%   only works when u is HOMOGENEOUS of degree 1-gamma, i.e. when
%   u(c*W) = W^(1-gamma) * u(c). The normalized form (c^(1-gamma)-1)/(1-gamma)
%   has a "-1" constant that breaks homotheticity.
%
%   Returns -Inf for c <= 0.

if nargin < 2, error('crra:gamma', 'gamma must be supplied'); end

u = -inf(size(c));
mask = c > 0;

if abs(gamma - 1) < 1e-12
    u(mask) = log(c(mask));
else
    u(mask) = c(mask).^(1 - gamma) ./ (1 - gamma);
end
end
