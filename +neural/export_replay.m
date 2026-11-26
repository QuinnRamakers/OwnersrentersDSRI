function out = export_replay(r, N, seed, file)
%EXPORT_REPLAY  A simulated panel of a grid solve, for the Julia replay test.
%
%   out = neural.export_replay(r, N, seed)
%   out = neural.export_replay(r, N, seed, file)   % also saves it
%
%   r is the output of model.run. Simulates N households with
%   simulate.paths_lna from the entry state (b0 years of income in liquid
%   wealth) and returns, in one struct per part:
%     out.model    neural.export_model of the calibration
%     out.draws    neural.draw_shocks for the same seed (N x (T-1) each)
%     out.panel    what paths_lna applied and produced: c_frac, pi (NaN once
%                  bankrupt), tau_A, reit_A, absorbed, floored, C, LW, X, A,
%                  H, Y, q, bequest, R_S
%     out.value    the value at entry from the value function: V_entry
%                  (V_tilde at the welfare anchor) and ce_entry (model.checks)
%   Julia fed out.draws and the panel's choices must reproduce the panel.

sim = simulate.paths_lna(r.p, r.profile, r.sol, r.ann_price, N, seed, r.p.b0);

out = struct();
out.model = neural.export_model(r.p, r.profile, r.ann_price);
d = neural.draw_shocks(r.p, N, seed);
out.draws = struct('eps_Y', d.eps_Y, 'eps_S', d.eps_S, 'eps_H', d.eps_H, ...
                   'eps_R', d.eps_R, 'seed', seed);

f = {'c_frac', 'pi', 'tau_A', 'reit_A', 'C', 'LW', 'X', 'A', 'H', 'Y', 'q', ...
     'bequest', 'R_S'};
panel = struct();
for i = 1:numel(f), panel.(f{i}) = sim.(f{i}); end
panel.absorbed = double(sim.absorbed);
panel.floored  = double(sim.floored);
out.panel = panel;

out.value = struct('V_entry', r.checks.V_entry, 'ce_entry', r.checks.ce_entry, ...
                   'b0', r.p.b0, 'h_mult', r.p.h_mult);

if nargin >= 4 && ~isempty(file)
    save(file, '-struct', 'out', '-v7');
end
end
