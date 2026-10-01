function r = run(p, opts)
%RUN  Solve, simulate and summarise the model for one tenure.
%
%   r = model.run(p)
%   r = model.run(p, N_sim=10000, seed=20260511, keep_sim=false, verbose=true)
%
%   p must already be derived (config.params, config.derive or ladder.params);
%   the tenure is p.is_owner, and without housing (h_mult = 0) the two tenures
%   coincide. Households enter at age p.age0 with p.b0 years of income in
%   liquid wealth. Returns
%     r.tenure                       'renter', 'owner' or 'nohousing'
%     r.p, r.profile, r.ann_price    the calibration and its inputs
%     r.sol                          value function and policies on the cube
%     r.summary                      per-age statistics of the panel (model.summarize)
%     r.checks                       what to look at before reading results (model.checks)
%     r.sim                          the panel itself, only with keep_sim
%     r.timing
%
%   Opens a parallel pool if none is open (utility.start_pool).

arguments
    p (1,1) struct
    opts.N_sim (1,1) double = 10000
    opts.seed (1,1) double = 20260511
    opts.keep_sim (1,1) logical = false
    opts.verbose (1,1) logical = true
end

if isempty(gcp('nocreate')), utility.start_pool(); end
nthreads = maxNumCompThreads(1);              % BLAS on one thread while the parfor runs
restore  = onCleanup(@() maxNumCompThreads(nthreads));

[profile, shocks, ann_price] = config.model_inputs(p);
tenure = model.tenure(p);
if opts.verbose
    fprintf('Solving %s on %d x %d x %d nodes, gh_n = %d ...\n', ...
        tenure, p.N_u1, p.N_u2, p.N_u3, p.gh_n);
end

t0  = tic;
sol = solver.solve(p, profile, shocks, ann_price, opts.verbose);
t_solve = toc(t0);

t1  = tic;
sim = simulate.forward(p, profile, sol, ann_price, opts.N_sim, opts.seed, p.b0);
t_sim = toc(t1);

r = struct();
r.tenure    = tenure;
r.p         = p;
r.profile   = profile;
r.ann_price = ann_price;
r.sol       = sol;
r.summary   = model.summarize(p, sim);
r.checks    = model.checks(p, sol, sim, r.summary, profile, shocks);
if opts.keep_sim, r.sim = sim; end
r.timing = struct('solve_sec', t_solve, 'sim_sec', t_sim, 'N_sim', opts.N_sim, ...
                  'seed', opts.seed, 'pool', sol.timing.pool, ...
                  'host', sol.timing.hostname, 'when', char(datetime('now')));
if opts.verbose
    fprintf('Solved in %.0f s, simulated %d households in %.0f s.\n', t_solve, opts.N_sim, t_sim);
    model.print_checks(r);
end
end
