function axis_channel(sp, out_dir)
%AXIS_CHANNEL  Which axis carries the early-life collapse?
%
%   Refining the whole cube turns the age-34 objective along c from a gentle
%   decline into a collapse. The cube has three axes, and they are not
%   interchangeable: the continuation value entering the objective is read at
%   (u1', u2', u3'), and a high c drives u2' towards 1 while leaving u3'
%   untouched. Measured on the solved value function, z along u2 is smooth,
%   decreasing and convex, so a linear interpolant on a coarse u2 axis is a
%   chord sitting above it and overstates what the household's savings are
%   worth in exactly the states a high-c choice lands in.
%
%   That is a hypothesis about which axis matters, and it is testable by
%   refining one axis at a time at roughly equal node count:
%
%       [12 12 8]   1568 nodes   baseline
%       [12 40 8]   4680 nodes   u2 refined, u1 and u3 left alone
%       [40 12 8]   4680 nodes   u1 refined, u2 and u3 left alone
%       [12 12 26]  4680 nodes   u3 refined
%
%   Outcome: the collapse follows u1, not u2. At age 34 the objective has lost
%   half its peak by c = 0.44 in the u1 arm against 0.90 in the u2 arm and 0.96
%   at the baseline, and at c = 0.8 the u1 arm is at 0.8% of its peak against
%   57% for u2. Refining the illiquid axis changes almost nothing. So the
%   channel is the income axis, where ruin_line_by_grid shows a ruin region
%   whose upper edge climbs into the occupied band as the axis is refined.
%
%   Resumable: one entry per cube.

if nargin < 1 || isempty(sp)
    sp = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad';
end
if nargin < 2 || isempty(out_dir)
    out_dir = 'C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc/diagnostics';
end
res = fullfile(out_dir, 'axis_channel.mat');

ARMS = {'baseline',   [12 12 8]; ...
        'u2 refined', [12 40 8]; ...
        'u1 refined', [40 12 8]; ...
        'u3 refined', [12 12 26]};
TS  = [10 20 30];                       % ages 34, 44, 54
TGT = [0.1393 0.6549 0.2757; ...
       0.1016 0.6532 0.5244; ...
       0.0780 0.7365 0.6728];

G = struct('arm', {}, 'dim', {}, 'N', {}, 'n', {}, 'sec', {}, 'dir', {}, ...
           't', {}, 'node', {}, 'coord', {}, 'bud', {});
if isfile(res), L = load(res); G = L.G; end

for i = 1:size(ARMS, 1)
    if any(strcmp({G.arm}, ARMS{i,1})), continue; end
    sd = fullfile(sp, 'scans_axis', matlab.lang.makeValidName(ARMS{i,1}));
    if isfolder(sd), rmdir(sd, 's'); end
    mkdir(sd);
    fprintf('[%s] %s  %s ...\n', datestr(now, 'HH:MM:SS'), ARMS{i,1}, mat2str(ARMS{i,2}));

    p = config.params(); p.is_owner = false;
    p.grid_mode = 'none'; p.polish_ver = 2; p.polish_algo = 'active-set'; p.use_refine = 0;
    p.lambda_lo = 0.0008; p.lambda_hi = 0.44; p.grid_pow = 1.6;
    p.u2_lo = 0.40; p.grid_pow_u2 = 1; p.u3_lo = 0.02; p.u3_hi = 0.98;
    p = utility.build_state_grids(p, ARMS{i,2}, 5);
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

    G(end+1).arm = ARMS{i,1}; G(end).dim = ARMS{i,2}; G(end).N = N;   %#ok<AGROW>
    G(end).n = prod(N); G(end).sec = sec; G(end).dir = sd;
    G(end).t = TS; G(end).node = nodes; G(end).coord = coord;
    G(end).bud = budget_next(p, TS);
    save(res, 'G', '-v7.3');
    fprintf('   %s = %d nodes | %.0f s | %d scans\n', mat2str(N), prod(N), sec, ...
        numel(dir(fullfile(sd, 'scan_*.mat'))));
end
fprintf('done: %d arms\n', numel(G));
end

% ------------------------------------------------------------------------
function b = budget_next(p, ts)
%BUDGET_NEXT  Next period's liquid-resource coefficients at the landing state.
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
