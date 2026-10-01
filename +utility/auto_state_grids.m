function [p, rep] = auto_state_grids(p, dims, gh_n, opt)
%AUTO_STATE_GRIDS  Choose the cube from the calibration, not from constants.
%
%   [p, rep] = utility.auto_state_grids(p, dims)
%   [p, rep] = utility.auto_state_grids(p, dims, gh_n, opt)
%
%   The hand-set axis bounds -- lambda_lo/hi, u2_lo, u3_lo/hi, grid_pow -- are
%   numbers measured off one calibration. Change alpha, the income profile, the
%   contribution rate or the tenure and they are wrong, silently: nodes go
%   where nobody lives and the occupied band is left in a cell or two. This
%   picks them instead, in two passes.
%
%     PASS 1  solve on a small cube spanning the model's own hard bounds, and
%             simulate. The pilot only has to be good enough to say where
%             households end up, not to price anything.
%     PASS 2  place the nodes at quantiles of that occupancy, with a margin of
%             nodes carrying on to the hard ends, and solve for real.
%
%   This returns p after pass 1, ready for the real solve. The pilot costs one
%   coarse solve, so the result is cached against the calibration and reused
%   until something that moves the ergodic distribution changes.
%
%   Why a pilot rather than an analytic rule. Where households end up is the
%   answer to the model, not an input to it: with a rent index carried inside
%   wealth, the occupied band on the income axis depends on the rent, the
%   income profile, the return process and the horizon together. A formula over
%   the calibration would be another set of constants to go stale.
%
%   opt fields, all optional:
%     pilot_dims  cube for pass 1                     [10 10 8]
%     pilot_gh    quadrature nodes for pass 1         3
%     n_sim       households simulated in pass 1      4000
%     seed        simulation seed                     20260919
%     band        occupied-band percentiles           [1 99]
%     weight      quantile-versus-even mix            0.75
%     margin      share of nodes outside the band     0.25
%     ages        model ages to pool over             all
%     cache       .mat path, '' to disable            <repo>/+utility/grid_cache.mat
%     force       ignore a cached entry               false
%     verbose     print the chosen axes               true
%
%   rep carries the occupancy, the chosen axes and the pilot's runtime.
%
%   See also utility.occupancy, utility.grid_from_occupancy,
%   utility.build_state_grids.

if nargin < 2, dims = []; end
if nargin < 3, gh_n = []; end
if nargin < 4 || isempty(opt), opt = struct; end

pilot_dims = getf(opt, 'pilot_dims', [10 10 8]);
pilot_gh   = getf(opt, 'pilot_gh',   3);
n_sim      = getf(opt, 'n_sim',      4000);
seed       = getf(opt, 'seed',       20260919);
ages       = getf(opt, 'ages',       []);
force      = getf(opt, 'force',      false);
verbose    = getf(opt, 'verbose',    true);
cache      = getf(opt, 'cache', fullfile(fileparts(mfilename('fullpath')), 'grid_cache.mat'));
sim_in     = getf(opt, 'sim', []);
axis_opt   = struct('band',     getf(opt, 'band',     [1 99]), ...
                    'weight',   getf(opt, 'weight',   0.75), ...
                    'margin',   getf(opt, 'margin',   0.25), ...
                    'dens_pow', getf(opt, 'dens_pow', 0.5), ...
                    'curv_pow', getf(opt, 'curv_pow', 0.5), ...
                    'pad',      getf(opt, 'pad', 0));

assert(isfield(p, 'grid_type') && strcmp(char(p.grid_type), 'lna'), ...
    'auto_state_grids:grid_type', 'the automatic grid is for the cube (grid_type = lna).');
if isempty(dims)
    assert(all(isfield(p, {'N_u1', 'N_u2', 'N_u3'})), 'auto_state_grids:dims', ...
        'p has no N_u1/N_u2/N_u3 and no dims were supplied.');
    dims = [p.N_u1 p.N_u2 p.N_u3];
end

% A panel handed in beats any pilot. The pilot exists because occupancy is an
% answer to the model, not an input, but if a solve of this calibration has
% already been run its panel is the same measurement without the coarseness --
% and the coarseness matters: a pilot on 1152 nodes puts the 1st percentile of
% the illiquid share at 0.75 where a production solve puts it at 0.59, which
% moves the bottom of that axis by two thirds of its occupied width.
sec = 0; key = '';
if ~isempty(sim_in)
    if verbose, fprintf('auto grid: measuring occupancy from the panel supplied\n'); end
    occ = utility.occupancy(p, sim_in, ages, getf(opt, 'sol', []));
    cache = '';
else
    key = calib_key(p, pilot_dims, pilot_gh, n_sim, seed, ages);
    occ = [];
    if ~force && ~isempty(cache) && isfile(cache)
        occ = cache_get(cache, key);
        if ~isempty(occ) && verbose
            fprintf('auto grid: reusing the cached pilot for this calibration\n');
        end
    end
end

if isempty(occ)
    if verbose
        fprintf('auto grid: pilot solve on %s, gh_n = %d ...\n', mat2str(pilot_dims), pilot_gh);
    end
    tic; occ = run_pilot(p, pilot_dims, pilot_gh, n_sim, seed, ages); sec = toc;
    if verbose, fprintf('auto grid: pilot took %.0f s\n', sec); end
    if ~isempty(cache), cache_put(cache, key, occ); end
end

% Hard ends: what the model permits, independent of where anyone turned out to
% be. utility.build_state_grids owns the income-axis pair; the other two are
% shares and run over the unit interval.
q = p; q.N_u1 = dims(1); q.N_u2 = dims(2); q.N_u3 = dims(3);
q = rmfields(q, {'lambda_lo', 'lambda_hi', 'u2_lo', 'u3_lo', 'u3_hi', 'grid_nodes'});
q = utility.build_state_grids(q, dims, gh_n);
hard = [min(q.u1_grid) max(q.u1_grid); 0 1; 0 1];

% Widen the income axis if the sample found households outside it. The default
% bounds are an argument about what the model permits, and the sample is
% evidence about what it does: on the owner calibration a small tail sits below
% the default floor, and lookups there are nearest-extrapolated onto a flat
% continuation with only a warning. Widening is one-way -- the axis is never
% pulled in to the sample, since a shock this sample happened not to draw is
% still reachable.
%
% The headroom is deliberately generous. The axis has to hold a DIFFERENT draw
% than the one that set it, and the ends of a sample are where its own noise
% is: an earlier version used 0.8 times the observed minimum, which left three
% per cent of headroom and let a fresh simulation off the bottom of the axis.
% Headroom at the ends is close to free -- the tail nodes are placed by
% distance from the occupied band, so a wider hard end moves the outermost node
% and no other.
if isfinite(occ.u1.lo), hard(1,1) = max(1e-5, min(hard(1,1), 0.4 * occ.u1.lo)); end
if isfinite(occ.u1.hi), hard(1,2) = min(1.0,  max(hard(1,2), 1.3 * occ.u1.hi)); end

ao = axis_opt;
ao.curv = curv_of(occ, 'u1'); [g1, i1] = utility.grid_from_occupancy(occ.u1.x, dims(1), hard(1,1), hard(1,2), ao);
ao.curv = curv_of(occ, 'u2'); [g2, i2] = utility.grid_from_occupancy(occ.u2.x, dims(2), hard(2,1), hard(2,2), ao);
ao.curv = curv_of(occ, 'u3'); [g3, i3] = utility.grid_from_occupancy(occ.u3.x, dims(3), hard(3,1), hard(3,2), ao);

p.grid_nodes = struct('u1', g1, 'u2', g2, 'u3', g3);
p = utility.build_state_grids(p, dims, gh_n);

rep = struct('occ', occ, 'pilot_sec', sec, 'key', key, ...
             'info', struct('u1', i1, 'u2', i2, 'u3', i3), ...
             'u1', p.u1_grid, 'u2', p.u2_grid, 'u3', p.u3_grid);

if verbose, report(p, rep); end
end

% ------------------------------------------------------------------------
function occ = run_pilot(p, dims, gh_n, n_sim, seed, ages)
%RUN_PILOT  Coarse solve on the model's hard bounds, then simulate.
q = rmfields(p, {'grid_nodes', 'lambda_lo', 'lambda_hi', 'u2_lo', 'u3_lo', 'u3_hi'});
q.grid_mode = 'none'; q.polish_ver = 2; q.polish_algo = 'active-set';
q.use_refine = true; q.refine_stage = 'pre';
q = utility.build_state_grids(q, dims, gh_n);

[~, mg, sl] = config.income_profile(q);
pf.mu_growth = mg; pf.sigma_l_log = sl; pf.p_surv = config.survival(q);
sk  = grids.shock_grid(q);
an  = pension.annuity_price(q, pf, sk);
sol = solver.solve_lifecycle_lna(q, pf, sk, an);
s   = simulate.forward(q, pf, sol, an, n_sim, seed, q.b0);
occ = utility.occupancy(q, s, ages, sol);
end

% ------------------------------------------------------------------------
function c = curv_of(occ, ax)
%CURV_OF  The curvature profile for one axis, empty when the pilot is older
%   than this feature and did not record one.
c = [];
if isfield(occ, 'curv') && ~isempty(occ.curv) && isfield(occ.curv, ax)
    c = occ.curv.(ax);
end
end

% ------------------------------------------------------------------------
function key = calib_key(p, dims, gh, n_sim, seed, ages)
%CALIB_KEY  A digest of everything that moves the ergodic distribution.
%   Grid sizes are deliberately out of it: the same pilot serves every cube
%   size, which is the point of caching it. Anything not on the struct is
%   skipped, so an older p-struct still keys cleanly.
f = {'is_owner', 'gamma', 'beta', 'T', 't_ret', 'b0', 'b_alt', 'h_mult', ...
     'alpha', 'theta', 'delta', 'kappa', 'phi_floor', 'tau_inc', 'tau_cg_bond', ...
     'tau_wealth', 'Rf', 'mu_S_level', 'sigma_S_level', 'mu_H_level', ...
     'sigma_H_level', 'mu_R_level', 'sigma_R_level', 'sell_cost', 'LTV', ...
     'm_rate_path', 'coord1', 'reit_active', 'reit_effective', 'choose_tau_S'};
acc = {};
for i = 1:numel(f)
    if ~isfield(p, f{i}), continue; end
    v = p.(f{i});
    if ischar(v) || isstring(v)
        acc{end+1} = sprintf('%s=%s', f{i}, char(v));                     %#ok<AGROW>
    elseif islogical(v) || isnumeric(v)
        acc{end+1} = sprintf('%s=%s', f{i}, mat2str(double(v(:).'), 8));  %#ok<AGROW>
    end
end
acc{end+1} = sprintf('pilot=%s/%d/%d/%d', mat2str(dims), gh, n_sim, seed);
acc{end+1} = sprintf('ages=%s', mat2str(ages(:).'));
% band, weight and margin are deliberately absent. They decide where the nodes
% go once the occupancy is known; they do not change the occupancy, so keying
% on them would re-run the pilot for every placement experiment.
% The descriptor itself is the key. Hashing it would only shorten it, and a
% hash that collides hands back the wrong calibration's occupancy without
% saying so.
key = strjoin(acc, '|');
end

% ------------------------------------------------------------------------
function occ = cache_get(path, key)
%CACHE_GET  Look up a pilot, tolerating a cache that is missing or being
%   written by another process. A cache miss only costs a pilot, so nothing
%   here is worth failing a run over.
occ = [];
try
    C = load(path);
catch
    return
end
if ~isfield(C, 'E') || isempty(C.E), return; end
hit = find(strcmp({C.E.key}, key), 1);
if ~isempty(hit), occ = C.E(hit).occ; end
end

% ------------------------------------------------------------------------
function cache_put(path, key, occ)
%CACHE_PUT  Add a pilot to the cache, written atomically.
%   Several solves can share one cache and run at once -- a placement sweep
%   does exactly that -- so the file is written under a unique name and then
%   moved into place. A reader either sees the old file or the new one, never a
%   half-written one, and a process that loses the race has only lost a cache
%   entry.
E = struct('key', {}, 'occ', {}, 'when', {});
try
    C = load(path);
    if isfield(C, 'E'), E = C.E; end
catch
end
hit = find(strcmp({E.key}, key), 1);
if isempty(hit), hit = numel(E) + 1; end
E(hit).key = key; E(hit).occ = occ; E(hit).when = datestr(now, 31);      %#ok<TNOW1,DATST>
tmp = sprintf('%s.%d.tmp', path, feature('getpid'));
try
    save(tmp, 'E', '-v7.3');
    [ok, msg] = movefile(tmp, path, 'f');
    if ~ok
        warning('auto_state_grids:cache', 'could not update the grid cache: %s', msg);
        if isfile(tmp), delete(tmp); end
    end
catch ME
    warning('auto_state_grids:cache', 'could not write the grid cache: %s', ME.message);
    if isfile(tmp), delete(tmp); end
end
end

% ------------------------------------------------------------------------
function s = rmfields(s, f)
for i = 1:numel(f)
    if isfield(s, f{i}), s = rmfield(s, f{i}); end
end
end

% ------------------------------------------------------------------------
function report(p, rep)
nm = {'u1  income share of wealth', 'u2  illiquid share', 'u3  pension share'};
ax = {'u1', 'u2', 'u3'};
fprintf('\nauto grid: %d x %d x %d = %d nodes\n', ...
    p.N_u1, p.N_u2, p.N_u3, p.N_u1*p.N_u2*p.N_u3);
fprintf('%-28s %18s %18s %10s\n', 'axis', 'occupied 1-99 pct', 'axis span', 'in band');
for i = 1:3
    inf_i = rep.info.(ax{i});
    g = rep.(ax{i});
    fprintf('%-28s %8.4f %8.4f %8.4f %8.4f %5d/%d\n', nm{i}, ...
        inf_i.band(1), inf_i.band(2), min(g), max(g), ...
        sum(g >= inf_i.band(1) & g <= inf_i.band(2)), numel(g));
end
fprintf('\n');
end

% ------------------------------------------------------------------------
function v = getf(s, f, d)
if isstruct(s) && isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = d; end
end
