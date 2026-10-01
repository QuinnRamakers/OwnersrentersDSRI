% Two ways to use the measured ranges: trim the axes only (four numbers, no data
% dependency) versus trim AND lay the interior out by quantile.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear; clc
o = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
L = load([o 'occ_sim.mat']); sim=L.sim; p=L.p;
X=sim.X;A=sim.A;H=sim.H;Y=sim.Y;W=sim.W;T=p.T;tt=3:T-1;
U={Y./W,(A+H)./max(X+A+H,eps),A./max(A+H,eps)};
nm={'u1','u2','u3'};
N=[numel(p.u1_grid) numel(p.u2_grid) numel(p.u3_grid)];
LO=cell(1,3);HI=cell(1,3);
for j=1:3, LO{j}=prctile(U{j}(:,tt),1,1); HI{j}=prctile(U{j}(:,tt),99,1); end
% measured extremes with a margin
B=[0.0020 0.4200; 0.5500 1.0000; 0.0300 0.9600];

G={};nmG={};
nmG{end+1}='current default'; G{end+1}={p.u1_grid,p.u2_grid,p.u3_grid};
% A: trimmed axes, uniform spacing
gA=cell(1,3); for j=1:3, gA{j}=linspace(B(j,1),B(j,2),N(j)).'; end
nmG{end+1}='A trimmed, uniform'; G{end+1}=gA;
% A2: trimmed, u1 clustered low (it falls through life), u2/u3 uniform
gA2=gA; gA2{1}=B(1,1)+(B(1,2)-B(1,1))*linspace(0,1,N(1)).'.^1.6;
nmG{end+1}='A2 trimmed, u1 pow 1.6'; G{end+1}=gA2;
% B: trimmed + quantile interior on u1 and u2, u3 uniform
gB=gA;
for j=1:2
    v=U{j}(:,tt); v=v(isfinite(v));
    qi=prctile(v,linspace(0,100,N(j)-1)); qi=qi(2:end-1);
    sp=B(j,2)-B(j,1);
    qi=B(j,1)+0.02*sp+(qi-min(qi))/max(max(qi)-min(qi),eps)*0.96*sp;
    gB{j}=unique([B(j,1);qi(:);B(j,2)]);
end
nmG{end+1}='B trimmed + quantile'; G{end+1}=gB;

fprintf('%-24s %22s %22s %22s %10s\n','layout','u1 mean/worst/starved','u2','u3','outside');
for k=1:numel(G)
    fprintf('%-24s',nmG{k}); off=0;
    for j=1:3
        g=G{k}{j}; c=arrayfun(@(t) sum(g>=LO{j}(t)&g<=HI{j}(t)),1:numel(tt));
        v=U{j}(:,tt); off=off+sum(v(:)<g(1)-1e-12|v(:)>g(end)+1e-12);
        fprintf('   %5.1f /%3d /%3d      ',mean(c),min(c),sum(c<2));
    end
    fprintf(' %9.4f%%\n',100*off/(3*numel(U{1}(:,tt))));
end
