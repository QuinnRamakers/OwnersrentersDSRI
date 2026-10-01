% Where do the households actually live, and where are the nodes?
%
% One production-default solve, one simulation, then pure measurement. For each
% candidate chart the same two questions:
%   (1) per age, what range does the population occupy on each axis?
%   (2) a fixed tensor grid must cover the UNION of those ranges over the life
%       cycle, so how much bigger is the union than any single age needs?
% Call that the sweep factor. A sweep of 1 means one grid fits every age. A
% sweep of 10 means nine tenths of the nodes are idle at any given age.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
o = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
p = config.params(); p.is_owner = false;
p.grid_mode = 'none'; p.polish_ver = 2; p.use_refine = false;
p = utility.build_state_grids(p, [14 14 10], 3);
[~, mg, sl] = config.income_profile(p);
prof.mu_growth = mg; prof.sigma_l_log = sl; prof.p_surv = config.survival(p);
shk = grids.shock_grid(p); ann = pension.annuity_price(p, prof, shk);
sol = solver.solve_lifecycle_lna(p, prof, shk, ann);
sim = simulate.forward(p, prof, sol, ann, 6000, 20260511, p.b0);
save([o 'occ_sim.mat'],'sim','p','-v7.3');

X = sim.X; A = sim.A; H = sim.H; Y = sim.Y; W = sim.W; T = p.T;
net = 1-p.tau_inc;
cf = zeros(1,T); hc = p.alpha*ones(1,T); af = zeros(1,T);
for t = 1:T
    if t >= p.t_ret, cf(t) = (1-p.delta)*net; af(t) = net/ann(t);
    else, cf(t) = (1-p.delta)*(1-p.kappa(min(t,numel(p.kappa))))*net; end
end
M = X + cf.*Y + af.*A - hc.*H;              % liquid resources, euros
sq = @(v) v ./ (1 + v);                      % [0,inf) -> [0,1)

% charts: name, three axes as N x T matrices, already on the axis the grid
% would be uniform in
C = {};
C{end+1} = {'A  current (Y/W, illiq share, DC share)', Y./W, (A+H)./max(X+A+H,eps), A./max(A+H,eps)};
C{end+1} = {'B  resource share (m/W, Y/W, DC share)',  M./W, Y./W,                  A./max(A+H,eps)};
C{end+1} = {'C  income-normalised (X/Y, A/Y, H/Y)',    sq(X./Y), sq(A./Y),          sq(H./Y)};
C{end+1} = {'D  resources/income (m/Y, A/Y, H/Y)',     sq(max(M,0)./Y), sq(A./Y),   sq(H./Y)};

ages = sim.ages; keep = 1:T-1;
fprintf('Renter, production default, 6000 paths, %d nodes\n\n', numel(p.u1_grid)*numel(p.u2_grid)*numel(p.u3_grid));
fprintf('%-42s %6s %8s %8s %8s\n','chart / axis','sweep','union','worst age','band@worst');
Res = struct([]);
for k = 1:numel(C)
    nm = C{k}{1};
    for j = 1:3
        V = C{k}{j+1}; if isscalar(V), V = V*ones(size(X)); end
        lo = prctile(V(:,keep), 1, 1); hi = prctile(V(:,keep), 99, 1);
        wid = hi - lo;
        uni = max(hi) - min(lo);
        sweep = uni / median(wid);
        [~, iw] = min(wid);
        if j==1, fprintf('%-42s', nm); else, fprintf('%-42s', ''); end
        fprintf(' %6.1f %8.3f %8d %8.4f\n', sweep, uni, ages(keep(iw)), wid(iw));
        Res(k).sweep(j) = sweep; Res(k).lo{j} = lo; Res(k).hi{j} = hi;
        Res(k).uni(j) = uni; Res(k).minwid(j) = wid(iw);
    end
    Res(k).name = nm;
    fprintf('%-42s %6.1f  <- product over the three axes\n\n','', prod(Res(k).sweep));
end

% nodes inside the occupied band, by age, on the CURRENT grid
gs = {p.u1_grid, p.u2_grid, p.u3_grid};
fprintf('Nodes inside the 1-99%% band, current grid (axis sizes %d/%d/%d)\n', ...
        numel(gs{1}), numel(gs{2}), numel(gs{3}));
fprintf('%6s %8s %8s %8s\n','age','u1','u2','u3');
for a = [25 30 40 50 60 66 67 70 80 90]
    t = a - p.age0 + 1; fprintf('%6d', a);
    for j = 1:3
        lo = Res(1).lo{j}(t); hi = Res(1).hi{j}(t);
        fprintf(' %8d', sum(gs{j} >= lo & gs{j} <= hi));
    end
    fprintf('\n');
end
save([o 'grid_occupancy.mat'],'Res','ages','keep');
