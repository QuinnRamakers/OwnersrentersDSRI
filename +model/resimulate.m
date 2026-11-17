function r = resimulate(file, opts)
%RESIMULATE  Simulate a saved solve again, without solving it.
%
%   r = model.resimulate(file)                          % the saved seed and panel size
%   r = model.resimulate(file, N_sim=100000, seed=7)    % more households, another seed
%   r = model.resimulate(file, keep_sim=true)           % also return the panel
%
%   file is a solve that model.strategies saved with keep_sol (the default),
%   so it holds p and sol. The inputs (income profile, shocks, annuity prices)
%   are rebuilt from p by config.model_inputs, as model.run builds them, and
%   the panel is simulated with simulate.forward. With the saved seed and
%   panel size this reproduces the saved summary exactly.
%
%   Returns r as model.run does: tenure, p, profile, ann_price, summary,
%   checks, timing (sim_sec, N_sim, seed), sim with keep_sim. r.sol is left
%   out (it is in the file).

arguments
    file (1,:) char
    opts.N_sim double = []
    opts.seed double = []
    opts.keep_sim (1,1) logical = false
end

w = whos('-file', file);
assert(ismember('sol', {w.name}), 'resimulate:no_sol', ...
    '%s holds no solution; it was saved with keep_sol=false. Solve it again to resimulate.', file);
L = load(file, 'p', 'sol', 'timing');
p = L.p;
N_sim = opts.N_sim; if isempty(N_sim), N_sim = L.timing.N_sim; end
seed  = opts.seed;  if isempty(seed),  seed  = L.timing.seed;  end

[profile, shocks, ann_price] = config.model_inputs(p);
t1 = tic;
sim = simulate.forward(p, profile, L.sol, ann_price, N_sim, seed, p.b0);
t_sim = toc(t1);

r = struct();
r.tenure    = model.tenure(p);
r.p         = p;
r.profile   = profile;
r.ann_price = ann_price;
r.summary   = model.summarize(p, sim);
r.checks    = model.checks(p, L.sol, sim, r.summary, profile, shocks);
if opts.keep_sim, r.sim = sim; end
r.timing = struct('sim_sec', t_sim, 'N_sim', N_sim, 'seed', seed, 'file', file);
end
