% For the renter, H is a rent index with no resale or bequest value. How much of
% W is it, and what is left if you take it out?
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
o='C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
L=load([o 'occ_sim.mat']); sim=L.sim; p=L.p;
X=sim.X;A=sim.A;H=sim.H;Y=sim.Y;W=sim.W;
fprintf('%6s %10s %10s %10s %12s %12s\n','age','H/W','(X+A)/W','Y/W','(X+A)/Y med','(X+A)/Y p1');
for a=[27 35 45 55 66 67 80 90]
    t=a-p.age0+1;
    fprintf('%6d %10.3f %10.3f %10.3f %12.3f %12.3f\n', a, ...
        median(H(:,t)./W(:,t)), median((X(:,t)+A(:,t))./W(:,t)), median(Y(:,t)./W(:,t)), ...
        median((X(:,t)+A(:,t))./Y(:,t)), prctile((X(:,t)+A(:,t))./Y(:,t),1));
end
tt=3:75;
fprintf('\nshare of household-years with (X+A) < 0.5 years of income: %.2f%%\n', ...
    100*mean(reshape((X(:,tt)+A(:,tt))./Y(:,tt)<0.5,[],1)));
fprintf('min (X+A)/Y over all households and ages: %.4f\n', min(min((X(:,tt)+A(:,tt))./Y(:,tt))));
