function shocks = shock_grid(p)
%SHOCK_GRID  Gauss-Hermite nodes/weights for stock, income, and housing shocks.
%   Three independent shocks at gh_n nodes each -> gh_n^3 joint nodes.
%   Returns:
%       shocks.R_S, w_S            stock return + weights (1 x n)
%       shocks.eps_Y_unit, w_Y     income shock z-points + weights
%       shocks.R_H, w_H            house gross return draws + weights
%       shocks.joint.{R_S, eps_Y_unit, R_H, w}   tensor product, vectors

[x, w] = gauss_hermite(p.gh_n);
z  = sqrt(2) * x(:).';
wz = w(:).' / sqrt(pi);

shocks.R_S = exp(p.mu_S + p.sigma_S * z);
shocks.w_S = wz;

shocks.eps_Y_unit = z;
shocks.w_Y        = wz;

shocks.R_H = exp(p.mu_H + p.sigma_H * z);
shocks.w_H = wz;

[Rs, EpsY, Rh] = ndgrid(shocks.R_S, shocks.eps_Y_unit, shocks.R_H);
[Ws, Wy, Wh]   = ndgrid(shocks.w_S, shocks.w_Y, shocks.w_H);
shocks.joint.R_S        = Rs(:);
shocks.joint.eps_Y_unit = EpsY(:);
shocks.joint.R_H        = Rh(:);
shocks.joint.w          = Ws(:) .* Wy(:) .* Wh(:);
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
