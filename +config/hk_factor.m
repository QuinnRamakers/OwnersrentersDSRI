function phi = hk_factor(p)
%HK_FACTOR  Human capital per unit of current income, by age.
%
%   phi = config.hk_factor(p)
%
%   phi(t) is the present value of the income still to be received, divided by
%   income at t. Deterministic: mean log growth, survival-weighted, discounted at
%   the risk-free rate. Because it is state-independent, HK_t = phi(t) * Y_t is a
%   multiple of an existing state and a chart built on it is a relabelling of the
%   same three states rather than a fourth one.
%
%   The point of it is the retirement handover. phi jumps UP at t_ret by very
%   nearly the factor income falls, because the present value of the remaining
%   stream does not step when only its composition changes -- the wage stops and
%   the AOW starts, but no payment is made at the switch. So HK is continuous
%   where Y is not.
%
%   Pure function of p, so it can be called from the grid builder, the solver and
%   the simulator without passing a profile around.

[~, mu_growth] = config.income_profile(p);
surv = config.survival(p);
T    = p.T;
Rf   = 1 + p.r;

phi = zeros(T, 1);
for t = 1:T
    acc = 0; rel = 1; s_acc = 1;
    for s = t : T-1
        rel   = rel * exp(mu_growth(s));      % E[Y_{s+1}] / Y_t
        s_acc = s_acc * surv(s);
        acc   = acc + s_acc * rel / Rf^(s - t + 1);
    end
    phi(t) = acc;
end
end
