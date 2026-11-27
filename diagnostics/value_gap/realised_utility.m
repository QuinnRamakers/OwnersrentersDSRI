function [U, ce, se] = realised_utility(p, profile, sim)
%REALISED_UTILITY  Realised lifetime utility of a panel, with the bequest motive.
%
%   [U, ce, se] = realised_utility(p, profile, sim)
%
%   As neural.sim_utility (utility of C / Y0, discounted with survival; the
%   bankrupt or defaulted household worth u(F) D_beq(t) from its year of
%   entry), plus with chi > 0 the bequest term beta (1 - p_t) chi u(b_t) of
%   each solvent year, b_t the liquid wealth and the house net of the sale
%   cost the household carries into t+1, at least 1e-12 of W (the solver's
%   bound). The last year's bequest is taken before its year of returns
%   (the panel has none after 100); the Julia year adds them, a difference
%   weighted by the survival to 100 alone. With chi = 0 this is
%   neural.sim_utility. ce and se as there.
g = p.gamma; T = p.T; N = size(sim.C, 1);
Y0 = sim.Y(1, 1);
u = @(x) (x / Y0) .^ (1 - g) / (1 - g);
ps = profile.p_surv(:);
ab = sim.absorbed;
ever = any(ab, 2);
t_ab = T - sum(ab, 2) + 1; t_ab(~ever) = T + 1;
Cbar = zeros(N, 1); Cbar(ever) = sim.C(sub2ind([N T], find(ever), t_ab(ever)));
hb = p.is_owner * (1 - p.sell_cost);
disc = ones(1, T); for t = 2:T, disc(t) = disc(t - 1) * p.beta * ps(t - 1); end
U = zeros(N, 1);
for t = 1:T
    s = t < t_ab;
    rt = u(sim.C(s, t));
    if p.chi > 0
        if t < T, b = sim.X(s, t + 1) + hb * sim.H(s, t + 1); else, b = sim.bequest(s); end
        b = max(b, 1e-12 * sim.W(s, t));
        rt = rt + p.beta * (1 - ps(t)) * p.chi * u(b);
    end
    U(s) = U(s) + disc(t) * rt;
    e = t_ab == t;
    U(e) = U(e) + disc(t) * u(Cbar(e)) * p.D_beq(t);
end
EU = mean(U);
ce = ((1 - g) * EU / p.D_abs(1))^(1 / (1 - g));
se = ce * (std(U) / sqrt(N)) / abs((1 - g) * EU);
end
