function V = verify_cgm(mode, opts)
%VERIFY_CGM  Is rung 0's pi(age) the model's answer, or the optimiser's?
%
%   V = verify_cgm('optimiser')   vary algorithm, refinement and seeding
%   V = verify_cgm('grid')        vary state-grid resolution
%   V = verify_cgm('all')
%
%   run_ablation shows rung 0 has smooth accumulation but rough retirement.
%   Before reading that as economics it has to survive two invariance checks,
%   because a numerical artefact would fail them:
%
%     optimiser  If pi(age) moves when only the algorithm, the derivative-free
%                refinement or the seed changes, the solver is not finding the
%                same argmax twice and the roughness is numerical.
%     grid       If retirement roughness keeps falling as the grid is refined,
%                it is discretisation. If it plateaus while accumulation
%                roughness keeps falling, the two have different causes.
%
%   Roughness is reported over four life phases, not two, because the retirement
%   TRANSITION and the FINAL YEARS are separate suspects from retirement proper:
%
%     accum       age0 .. retirement_age-4
%     transition  retirement_age-3 .. retirement_age+3
%     retired     retirement_age+4 .. 89
%     late        90 .. end
%
%   The final phase deserves its own line. At the terminal period the solver
%   sets pi = 0 by construction (nothing is saved, so it is arbitrary --
%   bellman_step_lna, the t == p.T branch), and under grid_mode 'none' that
%   value is the warm start the next step optimises from. So the last transitions
%   are seeded from a corner on a vanishing stake, which is a mechanical reason
%   for pi to misbehave there that has nothing to do with the economics.

if nargin < 1 || isempty(mode), mode = 'all'; end
if nargin < 2 || isempty(opts), opts = struct(); end
if ~isfield(opts, 'N_sim'), opts.N_sim = 4000; end
if ~isfield(opts, 'seed'),  opts.seed  = 12345; end
if ~isfield(opts, 'rung'),  opts.rung  = 0; end
if ~isfield(opts, 'dims'),  opts.dims  = [16 12 10]; end
if ~isfield(opts, 'gh_n'),  opts.gh_n  = 5; end
if ~isfield(opts, 'tag'),   opts.tag   = 'cgm'; end

here = fileparts(mfilename('fullpath'));
addpath(fileparts(here), here);
cd(fileparts(here));

if isempty(gcp('nocreate'))
    try, parpool('Threads'); catch, warning('verify_cgm:pool', 'no pool'); end
end

V = struct([]);

if any(strcmp(mode, {'optimiser', 'all'}))
    % name, polish_algo, use_refine, grid_mode, N_c, N_pi
    M = {
        'AS+ref (prod)',  'active-set',     true,  'none', 41, 41
        'IP+ref',         'interior-point', true,  'none', 41, 41
        'AS no-ref',      'active-set',     false, 'none', 41, 41
        'IP no-ref',      'interior-point', false, 'none', 41, 41
        'AS+ref gridseed','active-set',     true,  'full', 41, 41
        'AS+ref fine-seed','active-set',    true,  'none', 81, 81
        };
    fprintf('\n############ OPTIMISER INVARIANCE (rung %d, grid [%d %d %d]) ############\n', ...
        opts.rung, opts.dims);
    for k = 1:size(M, 1)
        o = struct('dims', opts.dims, 'gh_n', opts.gh_n);
        [p, meta] = ablation_config(opts.rung, o);
        p.polish_algo = M{k,2};
        p.use_refine  = M{k,3};
        p.grid_mode   = M{k,4};
        p.N_c         = M{k,5};
        p.N_pi        = M{k,6};
        e = run_one(p, meta, M{k,1}, opts);
        if isempty(V), V = e; else, V(end+1) = e; end %#ok<AGROW>
    end
end

if any(strcmp(mode, {'grid', 'all'}))
    G = {[12 8 6], [18 12 10], [26 16 12], [34 20 14]};
    fprintf('\n############ GRID CONVERGENCE (rung %d, AS+refine) ############\n', opts.rung);
    for k = 1:numel(G)
        o = struct('dims', G{k}, 'gh_n', opts.gh_n);
        [p, meta] = ablation_config(opts.rung, o);
        nm = sprintf('grid %d-%d-%d', G{k});
        e = run_one(p, meta, nm, opts);
        if isempty(V), V = e; else, V(end+1) = e; end %#ok<AGROW>
    end
end

fprintf('\n');
print_table(V);
save(fullfile(here, sprintf('verify_%s.mat', opts.tag)), 'V', 'opts', '-v7.3');
fprintf('\nSaved %s\n', fullfile(here, sprintf('verify_%s.mat', opts.tag)));
end

% =============================================================================
function e = run_one(p, meta, name, opts)
fprintf('\n-- %s --\n', name);
[~, mg, sl] = config.income_profile(p);
profile = struct('mu_growth', mg, 'sigma_l_log', sl, 'p_surv', config.survival(p));
sh  = grids.shock_grid(p);
ap  = pension.annuity_price(p, profile, sh);
t0  = tic;
sol = solver.solve(p, profile, sh, ap);
sim = simulate.forward(p, profile, sol, ap, opts.N_sim, opts.seed, p.b0);
el  = toc(t0);

ages  = sim.ages;
% Drop the terminal period. At t = T the household consumes everything
% (c_star = 1) and the solver sets pi = 0 because nothing is saved, so that
% column is a constant, not a choice. Leaving it in puts a spurious step of
% ~0.9 into any second-difference statistic.
n_pi  = min(size(sim.pi, 2), p.T - 1);
a     = ages(1:n_pi);
pim   = mean(sim.pi(:, 1:n_pi), 1, 'omitnan');

% Euros actually allocated by pi: the liquid balance carried into the next
% period. Where this is near zero, pi is a share of nothing and its value
% carries no information.
Xnext = max(sim.X(:, 1:n_pi), 0) .* (1 - sim.c_frac(:, 1:n_pi));
stake = mean(Xnext, 1, 'omitnan');

ret = p.retirement_age;
ph.accum      = a <  ret - 3;
ph.transition = a >= ret - 3 & a <= ret + 3;
ph.retired    = a >  ret + 3 & a < 90;
ph.late       = a >= 90;

e = struct();
e.name   = name;
e.dims   = meta.dims;
e.ages   = a;
e.pi     = pim;
e.stake  = stake;
e.elapsed = el;
f = fieldnames(ph);
for i = 1:numel(f)
    e.(['r_' f{i}])     = rough(pim(ph.(f{i})));
    e.(['z_' f{i}])     = zigzag(pim(ph.(f{i})));
    e.(['stake_' f{i}]) = mean(stake(ph.(f{i})), 'omitnan');
end
e.r_all = rough(pim);
e.z_all = zigzag(pim);

fprintf(['   |d2pi|: accum %.4f | transition %.4f | retired %.4f | late %.4f  (all %.4f)\n' ...
         '   zigzag: accum %.2f | transition %.2f | retired %.2f | late %.2f  (all %.2f)\n' ...
         '   mean stake (EUR): accum %.0f | transition %.0f | retired %.0f | late %.0f\n' ...
         '   %.0f s\n'], ...
    e.r_accum, e.r_transition, e.r_retired, e.r_late, e.r_all, ...
    e.z_accum, e.z_transition, e.z_retired, e.z_late, e.z_all, ...
    e.stake_accum, e.stake_transition, e.stake_retired, e.stake_late, el);
end

function r = rough(v)
v = v(isfinite(v));
if numel(v) < 3, r = NaN; return; end
r = mean(abs(diff(v, 2)));
end

function z = zigzag(v)
%ZIGZAG  Fraction of steps where the direction of pi(age) reverses.
%   Mean |second difference| cannot tell one economic kink from a sawtooth: a
%   policy that bends once at retirement scores high on it for a perfectly good
%   reason. This counts direction reversals instead. A smooth path with a single
%   turning point scores near 0 however sharp the turn; an oscillating one
%   scores near 1. Flat stretches are ignored rather than counted as reversals.
v = v(isfinite(v));
if numel(v) < 3, z = NaN; return; end
dv = diff(v);
dv(abs(dv) < 1e-10) = 0;
s = sign(dv);
s = s(s ~= 0);
if numel(s) < 2, z = 0; return; end
z = mean(s(1:end-1) ~= s(2:end));
end

function print_table(V)
fprintf('%-18s | %27s | %27s | %8s\n', '', ...
    'mean |2nd diff of pi|', 'zigzag (direction flips)', '');
fprintf('%-18s | %6s %6s %6s %6s | %6s %6s %6s %6s | %8s\n', 'config', ...
    'accum', 'trans', 'retire', 'late', 'accum', 'trans', 'retire', 'late', 'stake_rt');
fprintf('%s\n', repmat('-', 1, 100));
for k = 1:numel(V)
    fprintf('%-18s | %6.4f %6.4f %6.4f %6.4f | %6.2f %6.2f %6.2f %6.2f | %8.0f\n', ...
        V(k).name, V(k).r_accum, V(k).r_transition, V(k).r_retired, V(k).r_late, ...
        V(k).z_accum, V(k).z_transition, V(k).z_retired, V(k).z_late, ...
        V(k).stake_retired);
end
end
