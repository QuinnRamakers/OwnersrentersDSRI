function r = restart_sim(r, b)
%RESTART_SIM  A saved result simulated again from other starting savings.
%
%   r = restart_sim(r, b)      % b: liquid savings at 25, in years of gross income
%
%   The solution (value function and policies) is unchanged. The panel is
%   simulated again with the run's own households and seed, starting from
%   b * Y0 in liquid savings instead of p.b0 * Y0, and the summary and the
%   checks are recomputed. p.b0 is set to b so that every figure built from r
%   uses the new start. The value at entry is interpolated when b is not one
%   of the entry nodes (p.b0 and p.b_alt at solve time).

p = r.p; p.b0 = b;
[~, shocks] = config.model_inputs(p);
sim = simulate.forward(p, r.profile, r.sol, r.ann_price, r.timing.N_sim, r.timing.seed, b);
r.p = p;
r.sim = sim;
r.summary = model.summarize(p, sim);
r.checks = model.checks(p, r.sol, sim, r.summary, r.profile, shocks);
end
