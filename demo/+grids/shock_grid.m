function shocks = shock_grid(p)
% Function to create gaussian quadrature nodes, also allows for correlation
% through cholesky decompositions
[x, w] = gauss_hermite(p.gh_n);
z  = sqrt(2) * x(:).';
wz = w(:).' / sqrt(pi);

% set house price process to owner or renter
[mu_H, sigma_H] = config.h_process(p);

% Marginal (uncorrelated) univariate nodes/weights -- kept for annuity_price.m
shocks.R_S = exp(p.mu_S + p.sigma_S * z);
shocks.w_S = wz;

shocks.eps_Y_unit = z;
shocks.w_Y        = wz;

shocks.R_H = exp(mu_H + sigma_H * z);
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
shocks.joint.R_H        = exp(mu_H + sigma_H * zH);
shocks.joint.w          = w_joint;

shocks.z  = z;
shocks.wz = wz;
end

function [x, w] = gauss_hermite(n)
i = (1:n-1).';
beta = sqrt(i / 2);
J = diag(beta, 1) + diag(beta, -1);
[V, D] = eig(J);
x = diag(D);
[x, idx] = sort(x);
V = V(:, idx);
w = sqrt(pi) * V(1, :).'.^2;
end
