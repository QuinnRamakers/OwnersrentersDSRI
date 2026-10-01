% If the liquid equity share is a residual -- what is left after the DC fund
% takes its position -- then ranking grids on ITS roughness is partly ranking
% them on the volatility of a difference. Redo the grid comparison on TOTAL
% exposure and see whether the verdict survives.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
o='C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
A=load([o 'final_grid_run.mat']); B=load([o 'owner_fixed.mat']);
d2=@(v) 100*mean(abs(diff(v,2)))/mean(abs(v));
    function [rp, rt] = rough(sim, lo, hi)
        K=1:size(sim.tau_A,2);
        X=sim.X(:,K); Ap=sim.A(:,K);
        pil=mean(sim.pi(:,K),1,'omitnan');
        tot=mean((sim.pi(:,K).*X + sim.tau_A(:,K).*Ap)./max(X+Ap,eps),1,'omitnan');
        i=(lo:hi)-sim.ages(1)+1;
        f=@(v) 100*mean(abs(diff(v,2)))/mean(abs(v));
        rp=f(pil(i)); rt=f(tot(i));
    end
sets={A.S{1}.sim,'renter default grid'; A.S{2}.sim,'renter designed grid'; ...
      B.R{1}.sim,'owner default grid';  B.R{2}.sim,'owner designed grid'};
fprintf('%-26s %14s %14s %14s %14s\n','','pi 65-84','TOTAL 65-84','pi 40-64','TOTAL 40-64');
for k=1:size(sets,1)
    [p1,t1]=rough(sets{k,1},65,84); [p2,t2]=rough(sets{k,1},40,64);
    fprintf('%-26s %13.2f%% %13.2f%% %13.2f%% %13.2f%%\n', sets{k,2}, p1,t1,p2,t2);
end
