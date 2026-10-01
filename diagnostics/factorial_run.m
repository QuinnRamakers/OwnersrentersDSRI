function factorial_run(out_dir, max_cells, budget_h)
%FACTORIAL_RUN  Overnight lever study: main effects and pairwise interactions.
%
%   Eight levers, a centre point, every lever swept one at a time from it, and
%   the pairwise slices that are actually informative. A full factorial would be
%   648 cells per tenure; this is about 120 and covers every main effect plus
%   seven interactions.
%
%   levers          levels
%   ------          ------
%   tenure          renter, owner
%   grid placement  default (production axes), designed (trimmed + graded)
%   grid size       1152, 2560, 4800 nodes
%   entry wealth    b0 = 0.0791, 0.5, 1.0 years of income
%   housing cost    x1.00, x0.50, x0.25 of the calibrated committed outflow
%   consumption floor  phi_floor = 1e-6, 0.05, 0.20
%   floor mechanism    c_floor_frac = 0.01 (production guard), 0.001 (relaxed)
%   quadrature      gh_n = 3, 5
%
%   Everything is saved incrementally to results.mat after every solve, so an
%   overnight failure costs one cell rather than the run. Re-invoking skips
%   cells already present.
%
%   Each cell stores life-cycle profiles, policy slices and scalars -- never a
%   value function, which would be gigabytes across 120 cells.

if nargin < 1 || isempty(out_dir)
    out_dir = fileparts(mfilename('fullpath'));
end
res_file = fullfile(out_dir, 'factorial_results.mat');
log_file = fullfile(out_dir, 'factorial_log.txt');
if nargin < 2 || isempty(max_cells), max_cells = inf; end
if nargin < 3 || isempty(budget_h), budget_h = 8.5; end
BUDGET_H = budget_h;             % slack inside the nine hours

cells = build_cells();
if isfinite(max_cells), cells = cells(1:min(max_cells, numel(cells))); end
fprintf('%d cells queued\n', numel(cells));

R = struct('key', {}, 'cfg', {}, 'out', {});
if isfile(res_file)
    L = load(res_file); R = L.R;
    fprintf('resuming: %d cells already done\n', numel(R));
end
done = {R.key};
t_start = tic;
fid = fopen(log_file, 'a');
fprintf(fid, '\n=== run started %s ===\n', datestr(now));

for k = 1:numel(cells)
    c = cells(k);
    if any(strcmp(c.key, done)), continue; end
    if toc(t_start) / 3600 > BUDGET_H
        fprintf('budget reached, stopping with %d of %d cells\n', numel(R), numel(cells));
        fprintf(fid, 'budget reached at cell %d\n', k); break
    end
    try
        t0 = tic; out = run_cell(c); el = toc(t0);
        R(end+1).key = c.key; R(end).cfg = c; R(end).out = out; %#ok<AGROW>
        save(res_file, 'R', '-v7.3');
        msg = sprintf(['%3d/%3d %-52s %5.0fs  C25=%7.0f C45=%7.0f pi25=%.2f ' ...
                       'pi45=%.2f fl=%.2f%% off=%d cbind=%d'], ...
            numel(R), numel(cells), c.key, el, out.C(1), out.C(21), ...
            out.pi(1), out.pi(21), out.floored, out.off, out.c_binds25);
    catch ME
        msg = sprintf('%3d/%3d %-52s FAILED: %s', numel(R), numel(cells), c.key, ME.message);
    end
    fprintf('%s\n', msg); fprintf(fid, '%s\n', msg);
    if mod(numel(R), 5) == 0, fprintf(fid, '  [%.2f h elapsed]\n', toc(t_start)/3600); end
end
fprintf(fid, '=== finished %s, %.2f h, %d cells ===\n', datestr(now), toc(t_start)/3600, numel(R));
fclose(fid);
fprintf('done: %d cells in %.2f hours -> %s\n', numel(R), toc(t_start)/3600, res_file);
end

% ------------------------------------------------------------------------
function cells = build_cells()
% Centre point, every lever swept from it, then pairwise slices. Duplicates are
% removed by key, which is why the queue is far shorter than the raw list.
base = struct('ten','renter','grid','designed','nodes',2, ...
              'b0',0.0791,'hc',1.00,'phi',1e-6,'cff',0.01,'ghn',3);
NODES = {[10 10 8],[14 14 10],[18 18 12],[22 22 14]};
NS  = 1:4;                       % 1152 / 2560 / 4800 / 8064 nodes
B0  = [0.0791 0.5 1.0];
HC  = [1.00 0.50 0.25];
PHI = [1e-6 0.05 0.10 0.20];
CFF = [0.01 0.001];
GHN = [3 5];
GRD = {'default','designed'};

L = {};
for ten = {'renter','owner'}
    B = base; B.ten = ten{1};
    L{end+1} = B;                                                    %#ok<AGROW>
    % main effects, one lever at a time from the centre
    for g = GRD,  s=B; s.grid=g{1}; L{end+1}=s; end                  %#ok<AGROW>
    for n = NS,   s=B; s.nodes=n;   L{end+1}=s; end                  %#ok<AGROW>
    for v = B0,   s=B; s.b0=v;      L{end+1}=s; end                  %#ok<AGROW>
    for v = HC,   s=B; s.hc=v;      L{end+1}=s; end                  %#ok<AGROW>
    for v = PHI,  s=B; s.phi=v;     L{end+1}=s; end                  %#ok<AGROW>
    for v = CFF,  s=B; s.cff=v;     L{end+1}=s; end                  %#ok<AGROW>
    for v = GHN,  s=B; s.ghn=v;     L{end+1}=s; end                  %#ok<AGROW>
    % pairwise slices
    for a = HC,  for b = PHI, s=B; s.hc=a;  s.phi=b;   L{end+1}=s; end, end  %#ok<AGROW>
    for a = HC,  for n = NS,  s=B; s.hc=a;  s.nodes=n; L{end+1}=s; end, end  %#ok<AGROW>
    for a = PHI, for n = NS,  s=B; s.phi=a; s.nodes=n; L{end+1}=s; end, end  %#ok<AGROW>
    for g = GRD, for n = NS,  s=B; s.grid=g{1}; s.nodes=n; L{end+1}=s; end, end %#ok<AGROW>
    for a = GHN, for n = NS,  s=B; s.ghn=a; s.nodes=n; L{end+1}=s; end, end  %#ok<AGROW>
    for a = CFF, for b = HC,  s=B; s.cff=a; s.hc=b;    L{end+1}=s; end, end  %#ok<AGROW>
    for a = CFF, for b = PHI, s=B; s.cff=a; s.phi=b;   L{end+1}=s; end, end  %#ok<AGROW>
    for a = B0,  for b = HC,  s=B; s.b0=a;  s.hc=b;    L{end+1}=s; end, end  %#ok<AGROW>
    for a = B0,  for b = PHI([1 4]), s=B; s.b0=a; s.phi=b; L{end+1}=s; end, end %#ok<AGROW>
    for g = GRD, for b = PHI, s=B; s.grid=g{1}; s.phi=b; L{end+1}=s; end, end %#ok<AGROW>
    for a = HC,  for b = GHN, s=B; s.hc=a;  s.ghn=b;   L{end+1}=s; end, end  %#ok<AGROW>
    for a = B0,  for n = NS,  s=B; s.b0=a;  s.nodes=n; L{end+1}=s; end, end  %#ok<AGROW>
    for a = CFF, for n = NS,  s=B; s.cff=a; s.nodes=n; L{end+1}=s; end, end  %#ok<AGROW>
end

cells = struct('key',{},'ten',{},'grid',{},'nodes',{},'dims',{}, ...
               'b0',{},'hc',{},'phi',{},'cff',{},'ghn',{});
seen = {};
for i = 1:numel(L)
    s = L{i};
    key = sprintf('%s|%s|n%d|b%.4f|h%.2f|p%.5g|c%.4g|g%d', ...
                  s.ten, s.grid, s.nodes, s.b0, s.hc, s.phi, s.cff, s.ghn);
    if any(strcmp(key, seen)), continue; end
    seen{end+1} = key;                                               %#ok<AGROW>
    s.key = key; s.dims = NODES{s.nodes};
    cells(end+1) = orderfields(s, cells);                            %#ok<AGROW>
end
% cheapest first, so a truncated run still covers the design broadly
cost = arrayfun(@(c) c.nodes * (1 + 2*(c.ghn == 5)), cells);
[~, ord] = sort(cost);
cells = cells(ord);
end

% ------------------------------------------------------------------------
function out = run_cell(c)
p = config.params();
p.is_owner = strcmp(c.ten, 'owner');
p.grid_mode = 'none'; p.polish_ver = 2; p.use_refine = false;
p.b0 = c.b0; p.phi_floor = c.phi; p.c_floor_frac = c.cff;

% housing cost enters only through the carrying rate, so scaling it scales the
% committed outflow and nothing else. Renter: alpha. Owner: theta + m_rate_t.
if p.is_owner
    p.theta = p.theta * c.hc;  p.m_rate_path = p.m_rate_path * c.hc;
else
    p.alpha = p.alpha * c.hc;
end

% Generous bounds on the designed grid: housing cost, wealth and the floor all
% move where households sit, so one set has to hold for every cell. off-grid is
% recorded per cell rather than assumed to be zero.
if strcmp(c.grid, 'designed')
    p.lambda_lo = 0.0008; p.lambda_hi = 0.44; p.grid_pow = 1.6;
    p.u2_lo = 0.40; p.grid_pow_u2 = 1; p.u3_lo = 0.02; p.u3_hi = 0.98;
end
p = utility.build_state_grids(p, c.dims, c.ghn);

[~, mg, sl] = config.income_profile(p);
prof.mu_growth = mg; prof.sigma_l_log = sl; prof.p_surv = config.survival(p);
shk = grids.shock_grid(p); ann = pension.annuity_price(p, prof, shk);
sol = solver.solve_lifecycle_lna(p, prof, shk, ann);
sim = simulate.forward(p, prof, sol, ann, 4000, 20260511, p.b0);

med = @(M) median(M, 1, 'omitnan'); mn = @(M) mean(M, 1, 'omitnan');
d2  = @(v) 100 * mean(abs(diff(v, 2))) / mean(abs(v));
T   = p.T; K = 1:T-1;
out.ages   = sim.ages;
out.C      = med(sim.C(:, K));
out.pi     = mn(sim.pi(:, K));
out.cfrac  = med(sim.c_frac(:, K));
out.LW     = med(sim.LW(:, K));
out.fin    = med(sim.X(:, K) + sim.A(:, K));
out.Wtot   = med(sim.W(:, K));
F          = p.phi_floor * sim.Y(:, K);
out.fl_age = 100 * mean(sim.LW(:, K) <= F, 1);
out.floored = mean(out.fl_age);
out.off    = sim.diagnostics.n_offgrid_u1 + sim.diagnostics.n_offgrid_u2;
out.n      = numel(p.u1_grid) * numel(p.u2_grid) * numel(p.u3_grid);
out.rough_mid = d2(out.pi(16:40));
out.rough_ret = d2(out.pi(41:60));
% does the consumption search bound bind at entry?
lw_share  = med(sim.LW(:,1)) / med(sim.W(:,1));
out.cbound25  = min(max(1e-3, c.cff / lw_share), 0.5);
out.c_binds25 = out.cfrac(1) <= out.cbound25 * 1.02;
% policy slices: c and pi along u2 at the entry u1, lowest u3, three ages
ia = find(abs(p.u1_grid - 1/(1+p.h_mult+p.b0)) < 1e-9, 1);
if isempty(ia), [~, ia] = min(abs(p.u1_grid - 1/(1+p.h_mult+p.b0))); end
out.u2_grid = p.u2_grid(:).';
for j = 1:3
    t = [6 26 46];                       % ages 30, 50, 70
    out.pol_c(j, :)  = squeeze(sol.c_pol(ia, :, 1, t(j))).';
    out.pol_pi(j, :) = squeeze(sol.pi_pol(ia, :, 1, t(j))).';
end
out.u1_grid = p.u1_grid(:).';
out.u3_grid = p.u3_grid(:).';
end
