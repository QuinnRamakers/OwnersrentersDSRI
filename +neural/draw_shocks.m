function d = draw_shocks(p, N, seed)
%DRAW_SHOCKS  The correlated draws of simulate.paths_lna for the same seed.
%
%   d = neural.draw_shocks(p, N, seed)
%
%   Reproduces the draws of simulate.paths_lna(p, ..., N, seed, ...): rng(seed),
%   then independent normals in the order stock, income, house (and REIT when
%   the leg is active), correlated by the lower Cholesky factor of the
%   correlation matrix in the order income, stock, house, REIT. paths_lna
%   draws nothing else. Returns N x (T-1) arrays eps_Y, eps_S, eps_H and
%   eps_R (zeros with the REIT off), the factor L, and reit_on.
%   tests/neural_tests.m checks that the paths built from these draws equal
%   those of paths_lna in every bit.

rng(seed);
T = p.T;
[corr_HL, corr_SH, corr_RH] = config.h_corr(p);
reit_on = config.reit_active(p);

eps_S_ind = randn(N, T-1);
eps_Y_ind = randn(N, T-1);
eps_H_ind = randn(N, T-1);
if reit_on
    eps_R_ind = randn(N, T-1);
    Sigma = [1,         p.corr_SL, corr_HL,   p.corr_RL; ...
             p.corr_SL, 1,         corr_SH,   p.corr_RS; ...
             corr_HL,   corr_SH,   1,         corr_RH;   ...
             p.corr_RL, p.corr_RS, corr_RH,   1        ];
    L  = chol(Sigma, 'lower');
    Zc = L * [eps_Y_ind(:).'; eps_S_ind(:).'; eps_H_ind(:).'; eps_R_ind(:).'];
    eps_R = reshape(Zc(4, :), N, T-1);
else
    Sigma = [1,         p.corr_SL, corr_HL; ...
             p.corr_SL, 1,         corr_SH; ...
             corr_HL,   corr_SH,   1      ];
    L  = chol(Sigma, 'lower');
    Zc = L * [eps_Y_ind(:).'; eps_S_ind(:).'; eps_H_ind(:).'];
    eps_R = zeros(N, T-1);
end

d = struct();
d.eps_Y = reshape(Zc(1, :), N, T-1);
d.eps_S = reshape(Zc(2, :), N, T-1);
d.eps_H = reshape(Zc(3, :), N, T-1);
d.eps_R = eps_R;
d.L = L;
d.reit_on = reit_on;
d.seed = seed;
end
