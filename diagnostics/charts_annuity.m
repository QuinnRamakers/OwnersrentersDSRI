% Annuity- and human-capital-based normalisations, on the same measurement as
% the other four charts. Reuses occ_sim.mat, no solve.
%
% The idea being tested: u1 = Y/W breaks at 67 because its numerator is the
% CURRENT income flow, and that flow steps down when the wage stops. Two ways to
% fix the numerator:
%   E  add the annuity payout to it, so the numerator is the household's whole
%      income flow rather than the wage alone.
%   F  replace the flow by the STOCK it is worth -- human capital, the present
%      value of everything still to be received. That cannot step at 67: the
%      composition of the stream changes, but its present value does not, since
%      no payment is made at the switch.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
o = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
L = load([o 'occ_sim.mat']); sim=L.sim; p=L.p;
X=sim.X;A=sim.A;H=sim.H;Y=sim.Y;W=sim.W;T=p.T;net=1-p.tau_inc;
[~,mg,sl]=config.income_profile(p);
prof.mu_growth=mg;prof.sigma_l_log=sl;prof.p_surv=config.survival(p);
ann=pension.annuity_price(p,prof,grids.shock_grid(p));
surv=config.survival(p);
cf=zeros(1,T);af=zeros(1,T);
for t=1:T
  if t>=p.t_ret, cf(t)=(1-p.delta)*net; af(t)=net/ann(t);
  else, cf(t)=(1-p.delta)*(1-p.kappa(min(t,numel(p.kappa))))*net; end
end
M = X + cf.*Y + af.*A - p.alpha.*H;
ANNF = af.*A;                                   % net annuity flow, euros

% Human-capital factor phi_t: PV of the remaining income stream per unit of
% CURRENT income. Deterministic (mean growth, survival-weighted, discounted at
% the risk-free rate) -- a state-independent multiplier, so HK = phi_t * Y_t and
% the chart stays a relabelling of the same three states.
phi = zeros(1,T); Rf = 1+p.r;
for t = 1:T
    acc = 0; rel = 1; s_acc = 1;
    for s = t:T-1
        rel = rel * exp(mg(s));                 % E[Y_{s+1}]/Y_t
        s_acc = s_acc * surv(s);
        acc = acc + s_acc * rel / Rf^(s-t+1);
    end
    phi(t) = acc;
end
fprintf('human-capital factor phi: age 25 %.1f, 45 %.1f, 66 %.2f, 67 %.2f, 80 %.2f\n', ...
        phi(1), phi(21), phi(42), phi(43), phi(56));
HK = phi .* Y;  OM = X + A + H + HK;

sq=@(v) v./(1+v); tt=3:T-1; ages=sim.ages;
C={};
C{end+1}={'A  current: Y/W',                 Y./W,                (A+H)./max(X+A+H,eps), A./max(A+H,eps)};
C{end+1}={'E  (Y + annuity)/W',              (Y+ANNF)./W,         (A+H)./max(X+A+H,eps), A./max(A+H,eps)};
C{end+1}={'F  human capital HK/(HK+wealth)', HK./OM,              (A+H)./max(X+A+H,eps), A./max(A+H,eps)};
C{end+1}={'G  HK share + resource share',    HK./OM,              sq(max(M,0)./max(X+A+H,eps)), A./max(A+H,eps)};

fprintf('\nSweep factor (union over ages 27+ / median per-age width). Lower is better.\n');
fprintf('%-38s %8s %8s %8s %10s\n','chart','axis 1','axis 2','axis 3','product');
for k=1:numel(C)
  s=zeros(1,3);
  for j=1:3
    V=C{k}{j+1}; lo=prctile(V(:,tt),1,1); hi=prctile(V(:,tt),99,1);
    s(j)=(max(hi)-min(lo))/median(hi-lo);
  end
  fprintf('%-38s %8.1f %8.1f %8.1f %10.1f\n',C{k}{1},s(1),s(2),s(3),prod(s));
end

fprintf('\nThe 67/66 step on axis 1, measured household by household (median, and 10-90%%)\n');
fprintf('%-38s %10s %18s\n','chart','median','10-90%');
for k=1:numel(C)
  V=C{k}{2}; r = V(:,p.t_ret)./V(:,p.t_ret-1); r=r(isfinite(r));
  q=prctile(r,[10 50 90]);
  fprintf('%-38s %10.3f   %6.3f - %-6.3f\n',C{k}{1},q(2),q(1),q(3));
end

fprintf('\nNodes inside the 1-99%% band on axis 1, 16 nodes placed at measured quantiles\n');
fprintf('%-38s %14s %10s %14s\n','chart','mean','worst','starved ages');
for k=1:numel(C)
  V=C{k}{2}; lo=prctile(V(:,tt),1,1); hi=prctile(V(:,tt),99,1);
  v=V(:,tt); v=v(isfinite(v)); g=unique(prctile(v,linspace(0.5,99.5,16)).');
  cnt=arrayfun(@(t) sum(g>=lo(t)&g<=hi(t)),1:numel(tt));
  fprintf('%-38s %14.1f %10d %14d\n',C{k}{1},mean(cnt),min(cnt),sum(cnt<2));
end

f=figure('Position',[100 100 1180 400],'Color','w');
tl=tiledlayout(f,1,numel(C),'Padding','compact','TileSpacing','compact');
for k=1:numel(C)
  V=C{k}{2}; lo=prctile(V(:,tt),1,1); hi=prctile(V(:,tt),99,1);
  ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.1;
  fill(ax,[ages(tt) fliplr(ages(tt))],[lo fliplr(hi)],[.16 .47 .84],'FaceAlpha',.2,'EdgeColor','none');
  plot(ax,ages(tt),median(V(:,tt),1),'Color',[.16 .47 .84],'LineWidth',1.5);
  v=V(:,tt); v=v(isfinite(v)); g=unique(prctile(v,linspace(0.5,99.5,16)).');
  for i=1:numel(g), yline(ax,g(i),'-','Color',[.75 .4 .2 .5],'LineWidth',.6); end
  xline(ax,67,':','Color',[.3 .3 .3],'LineWidth',1);
  xlim(ax,[27 99]); title(ax,C{k}{1},'FontWeight','normal','FontSize',10); xlabel(ax,'age');
end
sgtitle(f,'First coordinate: occupied band (blue) against 16 quantile-placed nodes (orange)','FontWeight','normal','FontSize',12);
exportgraphics(f,[o 'fig_charts_annuity.png'],'Resolution',150);
disp('figure written');
