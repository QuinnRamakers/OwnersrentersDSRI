% Part 2: if the chart is not the problem, what spacing is right?
% Reuses occ_sim.mat, no solve. Age 25-26 are excluded throughout: every
% household enters at one state, so the occupied band is zero-width there by
% construction and any per-age statistic including it is meaningless.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
o = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
L = load([o 'occ_sim.mat']); sim = L.sim; p = L.p;
X=sim.X; A=sim.A; H=sim.H; Y=sim.Y; W=sim.W; T=p.T; net=1-p.tau_inc;
[~, mg, sl] = config.income_profile(p);
prof.mu_growth=mg; prof.sigma_l_log=sl; prof.p_surv=config.survival(p);
ann = pension.annuity_price(p, prof, grids.shock_grid(p));
cf=zeros(1,T); af=zeros(1,T); hc=p.alpha;
for t=1:T
    if t>=p.t_ret, cf(t)=(1-p.delta)*net; af(t)=net/ann(t);
    else, cf(t)=(1-p.delta)*(1-p.kappa(min(t,numel(p.kappa))))*net; end
end
M = X + cf.*Y + af.*A - hc.*H;
U = {Y./W, (A+H)./max(X+A+H,eps), A./max(A+H,eps)};
nmx = {'u1 = Y/W','u2 = illiquid share','u3 = DC share'};
tt = 3:T-1; ages = sim.ages;

% --- where they need to be ---
LO=cell(1,3); HI=cell(1,3);
for j=1:3
    LO{j}=prctile(U{j}(:,tt),1,1); HI{j}=prctile(U{j}(:,tt),99,1);
end
fprintf('Occupied 1-99%% band by age (current chart)\n%6s %18s %18s %18s\n','age',nmx{:});
for a=[27 35 45 55 65 66 67 70 80 90]
    t=find(ages(tt)==a); fprintf('%6d',a);
    for j=1:3, fprintf('   %6.3f - %-6.3f', LO{j}(t), HI{j}(t)); end
    fprintf('\n');
end

% --- candidate placements, same node counts ---
N = [numel(p.u1_grid) numel(p.u2_grid) numel(p.u3_grid)];
G = {};
G{end+1} = {'current (production default)', p.u1_grid, p.u2_grid, p.u3_grid};
q = p; q.lambda_hi=0.42; q.grid_pow=2; q.grid_pow_u2=1; q.u2_lo=0.60;
q = utility.build_state_grids(q, [14 14 10], 3);
G{end+1} = {'HANDOVER settings', q.u1_grid, q.u2_grid, q.u3_grid};
% quantile placement: nodes at equal quantiles of the POOLED lifetime occupancy
qp = cell(1,3);
for j=1:3
    v = U{j}(:,tt); v = v(isfinite(v));
    qp{j} = unique(prctile(v, linspace(0.5, 99.5, N(j))).');
end
G{end+1} = {'quantile-placed (measured)', qp{1}, qp{2}, qp{3}};
% quantile placement with the welfare anchors spliced back on
r = p; r.u1_grid=qp{1}; r.u2_grid=qp{2}; r.u3_grid=qp{3};
r.N_u1=numel(qp{1}); r.N_u2=numel(qp{2}); r.N_u3=numel(qp{3});
r = config.insert_anchor_nodes(r);
G{end+1} = {'quantile + anchors', r.u1_grid, r.u2_grid, r.u3_grid};

fprintf('\nNodes inside the 1-99%% band. "worst" is the leanest age 27+.\n');
fprintf('%-30s %24s %24s %24s\n','placement','u1  mean / worst','u2  mean / worst','u3  mean / worst');
for k=1:numel(G)
    fprintf('%-30s', G{k}{1});
    for j=1:3
        g = G{k}{j+1};
        cnt = arrayfun(@(t) sum(g>=LO{j}(t) & g<=HI{j}(t)), 1:numel(tt));
        fprintf(' %14.1f / %-7d', mean(cnt), min(cnt));
    end
    fprintf('\n');
end
fprintf('\nAges with fewer than 2 nodes on an axis (the starved years)\n');
fprintf('%-30s %10s %10s %10s\n','placement','u1','u2','u3');
for k=1:numel(G)
    fprintf('%-30s', G{k}{1});
    for j=1:3
        g = G{k}{j+1};
        cnt = arrayfun(@(t) sum(g>=LO{j}(t) & g<=HI{j}(t)), 1:numel(tt));
        fprintf(' %9d ', sum(cnt<2));
    end
    fprintf('\n');
end

f=figure('Position',[100 100 1180 760],'Color','w');
tl=tiledlayout(f,3,2,'Padding','compact','TileSpacing','compact');
show = [1 3];
for j=1:3
  for kk=1:2
    k=show(kk); ax=nexttile(tl); hold(ax,'on');
    fill(ax,[ages(tt) fliplr(ages(tt))],[LO{j} fliplr(HI{j})],[.16 .47 .84], ...
         'FaceAlpha',.18,'EdgeColor','none');
    plot(ax,ages(tt),median(U{j}(:,tt),1),'Color',[.16 .47 .84],'LineWidth',1.4);
    g=G{k}{j+1}; for i=1:numel(g), yline(ax,g(i),'-','Color',[.75 .4 .2 .55],'LineWidth',.6); end
    xline(ax,67,':','Color',[.4 .4 .4]); xlim(ax,[27 99]); ylabel(ax,nmx{j});
    if j==1, title(ax,G{k}{1},'FontWeight','normal'); end
    if j==3, xlabel(ax,'age'); end
    grid(ax,'on'); ax.GridAlpha=.1;
  end
end
sgtitle(f,'Blue band = where 98% of households are. Orange lines = grid nodes.','FontWeight','normal','FontSize',12);
exportgraphics(f,[o 'fig_spacing.png'],'Resolution',150);
disp('figure written');
