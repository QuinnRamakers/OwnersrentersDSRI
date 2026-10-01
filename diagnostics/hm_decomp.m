function d = hm_decomp(S, g, b)
%HM_DECOMP  Split a scanned node's objective along the consumption axis.
%
%   S is one scan_*.mat written by the solver's node dump, carrying the dense
%   (c, pi) surface in S.rhs and the node's budget primitives in S.prim. g is
%   the risk aversion, b next period's liquid-resource coefficients from
%   handtomouth/axis_channel.
%
%   The Bellman right hand side is
%       rhs(c) = u(c LW) + beta E[V'] + bequest
%   and everything here is returned as a certainty equivalent per unit of
%   wealth, so the terms are in comparable units. The current-utility term and
%   the bequest are closed forms of the primitives, so the continuation follows
%   by subtraction and no part of the transition is re-derived.
%
%   Fields that depend only on the budget -- the landing state u1', u2', and
%   whether next period's liquid resources clear the consumption floor there --
%   are the same for any cube solving the same model. Fields that come through
%   E[V'] are interpolants of that cube's value function and are not.

pr  = S.prim;
omg = 1 - g;
[~, im] = max(S.rhs(:));
[~, jg] = ind2sub(size(S.rhs), im);
c   = S.c(:).';
pis = S.pi(jg);

RX    = (1 - pis) * pr.Rf_at + pis * pr.R_S_at;         % n_shock x 1
Xn    = RX * ((1 - c) * pr.LW_W);                        % n_shock x nc
denAH = pr.A_next_W + pr.H_next_W;
Wg    = Xn + denAH + pr.Y_next_W;
u1n   = min(max(pr.Y_next_W ./ Wg, 0), 1);
u2n   = min(max(denAH ./ max(Xn + denAH, 1e-12), 0), 1);
u3n   = min(max(pr.A_next_W ./ max(denAH, 1e-12), 0), 1);

unow = (c * pr.LW_W) .^ omg / omg;
beq  = zeros(1, numel(c));
if pr.beq_eff > 0
    beq = pr.beq_eff * sum(pr.w .* ((Xn + pr.h_beq_fac * pr.H_next_W) .^ omg / omg), 1);
end
rhs  = S.rhs(:, jg).';
cont = rhs - unow - beq;                                 % = beta E[V']
EV   = cont / pr.beta_eff;

d.c       = c;
d.pi      = pis;
d.LW_W    = pr.LW_W;
d.z       = real(((1-g) * rhs) .^ (1/(1-g)));
d.ce_cont = real(((1-g) * EV) .^ (1/(1-g)));
d.ce_now  = c * pr.LW_W;

cw = cumsum(pr.w(:)) / sum(pr.w);
[~, jm] = min(abs(cw - 0.5));
d.u2_med = u2n(jm, :);
d.u1_med = u1n(jm, :);

lam2 = u1n;
sH2  = u2n .* (1 - u1n) .* (1 - u3n);
sX2  = (1 - u1n) .* (1 - u2n);
LW2  = sX2 + b.cf * lam2 - b.hc * sH2;
F2   = max(b.phi_floor * lam2, 1e-12);
d.p_floor = sum(pr.w .* (LW2 <= F2), 1);
d.F2_med  = F2(jm, :);
d.LW2_med = LW2(jm, :);
qs = [0.1 0.5 0.9];
d.LW2_q = zeros(numel(qs), numel(c));
for q = 1:numel(qs)
    [~, jq] = min(abs(cw - qs(q)));
    d.LW2_q(q, :) = LW2(jq, :);
end
d.qs = qs;
end
