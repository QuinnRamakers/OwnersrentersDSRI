function shocks = shock_grid(p)
%SHOCK_GRID  Gauss-Hermite nodes/weights for stock, income, and housing shocks.
%   Three shocks at gh_n nodes each -> gh_n^3 joint nodes (unchanged count).
%   The joint scenarios are built from the same independent per-dimension
%   GH abscissas as before, then Cholesky-correlated (income L, stock S,
%   housing H) via p.corr_SL / p.corr_HL / p.corr_SH -- no resampling, no
%   increase in node count. This is exact for jointly Gaussian quadrature:
%   if Z ~ iid N(0,1) and Sigma = Lc*Lc', then Lc*Z has correlation Sigma
%   with the same standard-normal marginals, so the tensor-product weights
%   are unchanged.
%
%   NOTE: corr_SL/corr_HL/corr_SH represent covariances of a single
%   composite income shock -- the model has no aggregate/idiosyncratic
%   income split, so each pairwise correlation conflates both channels
%   (see TODO.md, "Code <-> paper audit").
%
%   Returns:
%       shocks.R_S, w_S            stock return + weights (1 x n), UNCORRELATED
%                                   marginal nodes -- used by annuity_price.m,
%                                   which only needs the R_S marginal.
%       shocks.eps_Y_unit, w_Y     income shock z-points + weights (marginal)
%       shocks.R_H, w_H            house gross return draws + weights (marginal)
%       shocks.joint.{R_S, eps_Y_unit, R_H, w}   Cholesky-correlated tensor
%                                   product, vectors

[x, w] = gauss_hermite(p.gh_n);
z  = sqrt(2) * x(:).';
wz = w(:).' / sqrt(pi);

% Marginal (uncorrelated) univariate nodes/weights -- kept for annuity_price.m
shocks.R_S = exp(p.mu_S + p.sigma_S * z);
shocks.w_S = wz;

shocks.eps_Y_unit = z;
shocks.w_Y        = wz;

shocks.R_H = exp(p.mu_H + p.sigma_H * z);
shocks.w_H = wz;

% Independent standardized tensor-product nodes (order: L, S, H)
[Zl, Zs, Zh] = ndgrid(z, z, z);
[Wl, Ws, Wh] = ndgrid(wz, wz, wz);
w_joint = Wl(:) .* Ws(:) .* Wh(:);

% 3x3 correlation matrix (income L, stock S, housing H) + Cholesky factor
Sigma = [1,         p.corr_SL, p.corr_HL; ...
         p.corr_SL, 1,         p.corr_SH; ...
         p.corr_HL, p.corr_SH, 1        ];
Lc = chol(Sigma, 'lower');

Zind  = [Zl(:).'; Zs(:).'; Zh(:).'];   % 3 x n_shock independent std-normal nodes
Zcorr = Lc * Zind;                     % 3 x n_shock correlated std-normal nodes
zL = Zcorr(1, :).'; zS = Zcorr(2, :).'; zH = Zcorr(3, :).';

shocks.joint.R_S        = exp(p.mu_S + p.sigma_S * zS);
shocks.joint.eps_Y_unit = zL;
shocks.joint.R_H        = exp(p.mu_H + p.sigma_H * zH);
shocks.joint.w          = w_joint;
end

function [x, w] = gauss_hermite(n)
% Golub-Welsch on Hermite Jacobi matrix (physicist weight e^{-x^2}).
i = (1:n-1).';
beta = sqrt(i / 2);
J = diag(beta, 1) + diag(beta, -1);
[V, D] = eig(J);
x = diag(D);
[x, idx] = sort(x);
V = V(:, idx);
w = sqrt(pi) * V(1, :).'.^2;
end
