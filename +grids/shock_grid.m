function shocks = shock_grid(p)
%SHOCK_GRID  Gauss-Hermite nodes/weights for the model's return/income shocks.
%   Three shocks -- income L, stock S, housing H -- at gh_n nodes each, plus an
%   optional fourth: the retirement-account REIT R at gh_n_reit nodes. The joint
%   scenarios are built from the independent per-dimension GH abscissas, then
%   Cholesky-correlated via the p.corr_* fields -- no resampling. This is exact
%   for jointly Gaussian quadrature: if Z ~ iid N(0,1) and Sigma = Lc*Lc', then
%   Lc*Z has correlation Sigma with the same standard-normal marginals, so the
%   tensor-product weights are unchanged.
%
%   The fourth (REIT) dimension is built ONLY when config.reit_active(p) is
%   true -- a nonzero REIT share or a nonzero REIT correlation. Otherwise the
%   joint tensor is the old gh_n^3 one and shocks.joint.R_REIT is a unit vector,
%   so the pre-REIT model is reproduced at its old node count. When it IS built,
%   the joint has gh_n^3 * gh_n_reit nodes.
%
%   corr_SL/corr_HL/corr_SH (and corr_RL/corr_RS/corr_RH) are correlations
%   with a single composite income shock: the model has no aggregate versus
%   idiosyncratic split, so each one stands for both channels.
%
%   Returns:
%       shocks.R_S, w_S            stock return + weights (1 x n), UNCORRELATED
%                                   marginal nodes -- used by annuity_price.m,
%                                   which only needs the marginals.
%       shocks.eps_Y_unit, w_Y     income shock z-points + weights (marginal)
%       shocks.R_H, w_H            H-state gross growth draws + weights
%                                   (marginal); house-price return for owners,
%                                   rent increase for renters -- config.h_process
%       shocks.R_REIT, w_REIT      REIT return + weights (marginal); always
%                                   built (cheap; annuity_price.m needs its mean)
%       shocks.joint.{R_S, eps_Y_unit, R_H, R_REIT, w}   Cholesky-correlated
%                                   tensor product, vectors

[x, w] = gauss_hermite(p.gh_n);
z  = sqrt(2) * x(:).';
wz = w(:).' / sqrt(pi);

% Growth process of the H state: house-price return for owners, rent increase
% for renters. Same lognormal shape either way, so the node structure below is
% tenure-independent -- only the two parameters move.
[mu_H, sigma_H] = config.h_process(p);

% REIT marginal nodes at gh_n_reit (defaults to gh_n). Always built: it is
% cheap and pension.annuity_price needs the REIT mean whenever the share is on.
gh_n_reit = p.gh_n;
if isfield(p, 'gh_n_reit') && ~isempty(p.gh_n_reit), gh_n_reit = p.gh_n_reit; end
[xr, wr] = gauss_hermite(gh_n_reit);
zr  = sqrt(2) * xr(:).';
wzr = wr(:).' / sqrt(pi);
[mu_REIT, sigma_REIT] = config.reit_process(p);

% Marginal (uncorrelated) univariate nodes/weights -- kept for annuity_price.m
shocks.R_S = exp(p.mu_S + p.sigma_S * z);
shocks.w_S = wz;

shocks.eps_Y_unit = z;
shocks.w_Y        = wz;

shocks.R_H = exp(mu_H + sigma_H * z);
shocks.w_H = wz;

shocks.R_REIT = exp(mu_REIT + sigma_REIT * zr);
shocks.w_REIT = wzr;

corr_RL = field_or(p, 'corr_RL', 0);
corr_RS = field_or(p, 'corr_RS', 0);
corr_RH = field_or(p, 'corr_RH', 0);

if config.reit_active(p)
    % Four shocks (income L, stock S, housing H, REIT R): gh_n^3 * gh_n_reit
    % joint nodes.
    [Zl, Zs, Zh, Zr] = ndgrid(z, z, z, zr);
    [Wl, Ws, Wh, Wr] = ndgrid(wz, wz, wz, wzr);
    w_joint = Wl(:) .* Ws(:) .* Wh(:) .* Wr(:);

    Sigma = [1,         p.corr_SL, p.corr_HL, corr_RL; ...
             p.corr_SL, 1,         p.corr_SH, corr_RS; ...
             p.corr_HL, p.corr_SH, 1,         corr_RH; ...
             corr_RL,   corr_RS,   corr_RH,   1      ];
    Lc = chol(Sigma, 'lower');

    Zind  = [Zl(:).'; Zs(:).'; Zh(:).'; Zr(:).'];
    Zcorr = Lc * Zind;
    zL = Zcorr(1, :).'; zS = Zcorr(2, :).'; zH = Zcorr(3, :).'; zR = Zcorr(4, :).';
    shocks.joint.R_REIT = exp(mu_REIT + sigma_REIT * zR);
else
    % Pre-REIT model: three shocks, gh_n^3 joint nodes. The REIT leg is inert
    % (share 0 everywhere), so a unit placeholder keeps the solver's return
    % expression valid without changing any value.
    [Zl, Zs, Zh] = ndgrid(z, z, z);
    [Wl, Ws, Wh] = ndgrid(wz, wz, wz);
    w_joint = Wl(:) .* Ws(:) .* Wh(:);

    Sigma = [1,         p.corr_SL, p.corr_HL; ...
             p.corr_SL, 1,         p.corr_SH; ...
             p.corr_HL, p.corr_SH, 1        ];
    Lc = chol(Sigma, 'lower');

    Zind  = [Zl(:).'; Zs(:).'; Zh(:).'];
    Zcorr = Lc * Zind;
    zL = Zcorr(1, :).'; zS = Zcorr(2, :).'; zH = Zcorr(3, :).';
    shocks.joint.R_REIT = ones(numel(w_joint), 1);
end

shocks.joint.R_S        = exp(p.mu_S + p.sigma_S * zS);
shocks.joint.eps_Y_unit = zL;
shocks.joint.R_H        = exp(mu_H + sigma_H * zH);
shocks.joint.w          = w_joint;

% The underlying standard-normal quadrature nodes and their probabilities
% (sum(wz) = 1).
shocks.z  = z;
shocks.wz = wz;
end

function v = field_or(p, f, default)
% Scalar field read with a default when absent/empty.
if isfield(p, f) && ~isempty(p.(f)), v = p.(f); else, v = default; end
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
