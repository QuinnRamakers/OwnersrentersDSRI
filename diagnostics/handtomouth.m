function handtomouth(sp, out_dir)
%HANDTOMOUTH  Why high consumption turns catastrophic in early life as the cube
%   is refined.
%
%   S29/S31 showed that at age 34, at the state households occupy, the
%   objective along c is a gentle decline at 600 and 1568 nodes and a collapse
%   to zero by c ~ 0.5 at 5808. Consuming out of liquid resources goes from
%   mildly costly to ruinous purely by adding nodes.
%
%   The Bellman right hand side is
%       rhs(c, pi) = u(c LW) + beta E[V'] + bequest
%   and only the middle term can be responsible: u(c LW) is increasing in c at
%   any gamma, so current utility always argues for consuming more. What has to
%   be explained is the continuation.
%
%   This re-solves the ladder with the node dump carrying the budget primitives
%   (scan .prim), so at the occupied node the objective can be split into its
%   terms exactly -- no re-derivation of the transition -- and the next-period
%   state each c leads to can be read off. Two things are then separable:
%
%     the LANDING STATE, u1' and u2' as functions of c. This is arithmetic on
%     the budget and does not depend on the cube at all.
%
%     the VALUE ASSIGNED to that landing state, which is an interpolant of the
%     solved value function and does depend on the cube.
%
%   If the landing states coincide across cubes but the value assigned to them
%   does not, refinement is changing what the household is told its savings are
%   worth, not what its savings are.
%
%   Resumable: one entry per cube.

if nargin < 1 || isempty(sp)
    sp = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad';
end
if nargin < 2 || isempty(out_dir)
    out_dir = 'C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc/diagnostics';
end
res = fullfile(out_dir, 'handtomouth.mat');

DIMS = {[8 8 6], [12 12 8], [16 16 10], [20 20 12]};
TS   = [10 20 30];                      % ages 34, 44, 54
TGT  = [0.1393 0.6549 0.2757;           % 34
        0.1016 0.6532 0.5244;           % 44
        0.0780 0.7365 0.6728];          % 54

G = struct('dim', {}, 'N', {}, 'n', {}, 'sec', {}, 'dir', {}, 't', {}, ...
           'node', {}, 'coord', {}, 'bud', {});
if isfile(res), L = load(res); G = L.G; end

for i = 1:numel(DIMS)
    if any(arrayfun(@(g) isequal(g.dim, DIMS{i}), G)), continue; end
    sd = fullfile(sp, 'scans_hm', sprintf('n%05d', prod(DIMS{i})));
    if isfolder(sd), rmdir(sd, 's'); end
    mkdir(sd);
    fprintf('[%s] cube %s ...\n', datestr(now, 'HH:MM:SS'), mat2str(DIMS{i}));

    p = config.params(); p.is_owner = false;
    p.grid_mode = 'none'; p.polish_ver = 2; p.polish_algo = 'active-set'; p.use_refine = 0;
    p.lambda_lo = 0.0008; p.lambda_hi = 0.44; p.grid_pow = 1.6;
    p.u2_lo = 0.40; p.grid_pow_u2 = 1; p.u3_lo = 0.02; p.u3_hi = 0.98;
    p = utility.build_state_grids(p, DIMS{i}, 5);
    N = [p.N_u1 p.N_u2 p.N_u3];

    nodes = zeros(numel(TS), 1); coord = zeros(numel(TS), 3);
    for a = 1:numel(TS)
        [~, i1] = min(abs(p.u1_grid(:) - TGT(a, 1)));
        [~, i2] = min(abs(p.u2_grid(:) - TGT(a, 2)));
        [~, i3] = min(abs(p.u3_grid(:) - TGT(a, 3)));
        nodes(a) = sub2ind(N, i1, i2, i3);
        coord(a, :) = [p.u1_grid(i1) p.u2_grid(i2) p.u3_grid(i3)];
    end
    p.scan = struct('t', TS, 'nodes', unique(nodes), 'c_n', 121, 'pi_n', 61, 'dir', sd);

    [~, mg, sl] = config.income_profile(p);
    pf.mu_growth = mg; pf.sigma_l_log = sl; pf.p_surv = config.survival(p);
    sk = grids.shock_grid(p); an = pension.annuity_price(p, pf, sk);
    tic; solver.solve_lifecycle_lna(p, pf, sk, an); sec = toc;

    G(end+1).dim = DIMS{i}; G(end).N = N; G(end).n = prod(N); G(end).sec = sec;  %#ok<AGROW>
    G(end).dir = sd; G(end).t = TS; G(end).node = nodes; G(end).coord = coord;
    G(end).bud = budget_next(p, TS);
    save(res, 'G', '-v7.3');
    fprintf('   cube %s = %d nodes | %.0f s | %d scans\n', mat2str(N), prod(N), sec, ...
        numel(dir(fullfile(sd, 'scan_*.mat'))));
end
fprintf('done: %d cubes\n', numel(G));
end

% ------------------------------------------------------------------------
function b = budget_next(p, ts)
%BUDGET_NEXT  Next period's liquid-resource coefficients, so the landing state
%   can be checked against the consumption floor. Working branch, renter:
%       LW'/W' = s_X' + cf * lambda' - alpha * s_H'
%   mirrors the identity the solver forms at the top of its state loop.
net_inc = 1; if isfield(p, 'tau_inc'), net_inc = 1 - p.tau_inc; end
b = struct('t', {}, 'cf', {}, 'hc', {}, 'phi_floor', {}, 'retired', {});
for a = 1:numel(ts)
    t2 = ts(a) + 1;
    kap = p.kappa(min(t2, numel(p.kappa)));
    b(a).t = t2;
    b(a).retired = t2 >= p.t_ret;
    if b(a).retired
        b(a).cf = (1 - p.delta) * net_inc;
    else
        b(a).cf = (1 - p.delta) * (1 - kap) * net_inc;
    end
    if p.is_owner
        mr = 0; if t2 <= numel(p.m_rate_path), mr = p.m_rate_path(t2); end
        b(a).hc = p.theta + mr;
    else
        b(a).hc = p.alpha;
    end
    b(a).phi_floor = 0;
    if isfield(p, 'phi_floor'), b(a).phi_floor = p.phi_floor; end
end
end
