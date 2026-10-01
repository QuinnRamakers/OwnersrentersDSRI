addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
o = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
L = load([o 'occ_sim.mat']); sim=L.sim; p=L.p;
X=sim.X;A=sim.A;H=sim.H;Y=sim.Y;W=sim.W;T=p.T;net=1-p.tau_inc;
[~,mg,sl]=config.income_profile(p);
prof.mu_growth=mg;prof.sigma_l_log=sl;prof.p_surv=config.survival(p);
ann=pension.annuity_price(p,prof,grids.shock_grid(p));
cf=zeros(1,T);af=zeros(1,T);
for t=1:T
  if t>=p.t_ret, cf(t)=(1-p.delta)*net; af(t)=net/ann(t);
  else, cf(t)=(1-p.delta)*(1-p.kappa(min(t,numel(p.kappa))))*net; end
end
M=X+cf.*Y+af.*A-p.alpha.*H; sq=@(v) v./(1+v); tt=3:T-1;
C={}; C{end+1}={'A  current: (Y/W, illiquid share, DC share)',Y./W,(A+H)./max(X+A+H,eps),A./max(A+H,eps)};
C{end+1}={'B  resource share: (m/W, Y/W, DC share)',M./W,Y./W,A./max(A+H,eps)};
C{end+1}={'C  income-normalised (CGM style): (X/Y, A/Y, H/Y)',sq(X./Y),sq(A./Y),sq(H./Y)};
C{end+1}={'D  resources over income: (m/Y, A/Y, H/Y)',sq(max(M,0)./Y),sq(A./Y),sq(H./Y)};
fprintf('Sweep factor = width of the union over ages 27+ / median per-age width.\n');
fprintf('1 means one grid fits every age. 10 means 9/10 of the nodes idle at any age.\n\n');
fprintf('%-50s %7s %7s %7s %9s\n','chart','axis 1','axis 2','axis 3','product');
for k=1:numel(C)
  s=zeros(1,3);
  for j=1:3
    V=C{k}{j+1}; lo=prctile(V(:,tt),1,1); hi=prctile(V(:,tt),99,1);
    s(j)=(max(hi)-min(lo))/median(hi-lo);
  end
  fprintf('%-50s %7.1f %7.1f %7.1f %9.1f\n',C{k}{1},s(1),s(2),s(3),prod(s));
end
