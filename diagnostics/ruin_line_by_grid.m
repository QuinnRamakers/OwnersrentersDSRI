function ruin_line_by_grid(sp, out_dir)
%RUIN_LINE_BY_GRID  Does the decision square at an occupied state turn to ruin
%   as the cube is refined, or was that one unlucky node?
%
%   decision_by_grid found that at age 34, at the state households of that age
%   occupy, the share of the (c, pi) square that is ruin runs 0%, 0%, 16%, 53%
%   as the cube goes 600 -> 1568 -> 3240 -> 5808 nodes, while the best
%   attainable value halves. The state moves slightly between cubes, so that
%   comparison alone cannot separate resolution from drift.
%
%   This scans the whole u1 line -- every income share at the occupied (u2, u3)
%   -- in each cube, at three ages. If the ruin boundary sits at the same u1 in
%   every cube, the age-34 jump was drift. If the boundary marches up the axis
%   as the cube is refined, the objective at a fixed state really is turning to
%   ruin under refinement, which is a solution defect and not a property of the
%   model.
%
%   Resumable: one entry per cube, skipped if already present.

if nargin < 1 || isempty(sp)
    sp = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad';
end
if nargin < 2 || isempty(out_dir)
    out_dir = 'C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc/diagnostics';
end
res = fullfile(out_dir, 'ruin_line_by_grid.mat');

DIMS = {[8 8 6], [12 12 8], [16 16 10], [20 20 12]};
TS   = [10 30 45];                      % ages 34, 54, 69
TGT  = [0.1393 0.6549 0.2757;           % 34
        0.0780 0.7365 0.6728;           % 54
        0.0169 0.8924 0.7507];          % 69

G = struct('dim', {}, 'N', {}, 'n', {}, 'sec', {}, 'dir', {}, 't', {}, ...
           'u1', {}, 'i2', {}, 'i3', {}, 'coord23', {});
if isfile(res), L = load(res); G = L.G; end

for i = 1:numel(DIMS)
    if any(arrayfun(@(g) isequal(g.dim, DIMS{i}), G)), continue; end
    sd = fullfile(sp, 'scans_line', sprintf('n%05d', prod(DIMS{i})));
    if isfolder(sd), rmdir(sd, 's'); end
    mkdir(sd);
    fprintf('[%s] cube %s ...\n', datestr(now, 'HH:MM:SS'), mat2str(DIMS{i}));

    p = config.params(); p.is_owner = false;
    p.grid_mode = 'none'; p.polish_ver = 2; p.polish_algo = 'active-set'; p.use_refine = 0;
    p.lambda_lo = 0.0008; p.lambda_hi = 0.44; p.grid_pow = 1.6;
    p.u2_lo = 0.40; p.grid_pow_u2 = 1; p.u3_lo = 0.02; p.u3_hi = 0.98;
    p = utility.build_state_grids(p, DIMS{i}, 5);
    N = [p.N_u1 p.N_u2 p.N_u3];

    nodes = []; i2 = zeros(numel(TS), 1); i3 = zeros(numel(TS), 1); c23 = zeros(numel(TS), 2);
    for a = 1:numel(TS)
        [~, i2(a)] = min(abs(p.u2_grid(:) - TGT(a, 2)));
        [~, i3(a)] = min(abs(p.u3_grid(:) - TGT(a, 3)));
        c23(a, :) = [p.u2_grid(i2(a)) p.u3_grid(i3(a))];
        nodes = [nodes; sub2ind(N, (1:N(1)).', repmat(i2(a), N(1), 1), repmat(i3(a), N(1), 1))]; %#ok<AGROW>
    end
    p.scan = struct('t', TS, 'nodes', unique(nodes), 'c_n', 81, 'pi_n', 61, 'dir', sd);

    [~, mg, sl] = config.income_profile(p);
    pf.mu_growth = mg; pf.sigma_l_log = sl; pf.p_surv = config.survival(p);
    sk = grids.shock_grid(p); an = pension.annuity_price(p, pf, sk);
    tic; solver.solve_lifecycle_lna(p, pf, sk, an); sec = toc;

    G(end+1).dim = DIMS{i}; G(end).N = N; G(end).n = prod(N); G(end).sec = sec;  %#ok<AGROW>
    G(end).dir = sd; G(end).t = TS; G(end).u1 = p.u1_grid(:);
    G(end).i2 = i2; G(end).i3 = i3; G(end).coord23 = c23;
    save(res, 'G', '-v7.3');
    fprintf('   cube %s = %d nodes | %.0f s | %d scans\n', mat2str(N), prod(N), sec, ...
        numel(dir(fullfile(sd, 'scan_*.mat'))));
end
fprintf('done: %d cubes\n', numel(G));
end
