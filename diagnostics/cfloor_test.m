% Is early-life consumption the household's answer, or the search bound's?
% The bound is c >= 0.01/LW_W, i.e. "consume at least 1% of total wealth". At the
% finer grid the solved consumption share sits ON it in every entry-buffer arm.
% If that is causal, lowering the coefficient must lower consumption at 25 and
% leave ages 40+ alone. If consumption at 25 barely moves, the bound is merely
% coincident and the story is wrong.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
o='C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
R={};
for cff = [0.01 0.001 0.0001]
    p=config.params(); p.is_owner=false;
    p.grid_mode='none'; p.polish_ver=2; p.use_refine=false; p.c_floor_frac=cff;
    p.lambda_lo=0.0008; p.lambda_hi=0.44; p.grid_pow=1.6;
    p.u2_lo=0.45; p.grid_pow_u2=1; p.u3_lo=0.03; p.u3_hi=0.96;
    p=utility.build_state_grids(p,[18 18 12],3);
    [~,mg,sl]=config.income_profile(p);
    pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(p);
    sk=grids.shock_grid(p); an=pension.annuity_price(p,pf,sk);
    tic; sol=solver.solve_lifecycle_lna(p,pf,sk,an); el=toc;
    sm=simulate.forward(p,pf,sol,an,4000,20260511,p.b0);
    r.cff=cff; r.C=median(sm.C,1,'omitnan'); r.pi=mean(sm.pi,1,'omitnan');
    r.cfr=median(sm.c_frac(:,1)); r.ages=sm.ages;
    F=p.phi_floor*sm.Y(:,1:size(sm.C,2)); r.fl=100*mean(mean(sm.LW(:,1:size(F,2))<=F,1));
    R{end+1}=r;
    fprintf('c_floor_frac=%-8.4g %4.0fs  C25=%7.0f  C40=%7.0f  C70=%7.0f  c-share@25=%.4f  floored %.2f%%\n', ...
        cff, el, r.C(1), r.C(16), r.C(46), r.cfr, r.fl);
end
save([o 'cfloor_test.mat'],'R');
fprintf('\nchange relative to the production bound\n%-16s %10s %10s %10s\n','c_floor_frac','C25','C40','C70');
for k=1:numel(R)
    fprintf('%-16.4g %9.1f%% %9.1f%% %9.1f%%\n', R{k}.cff, ...
        100*(R{k}.C(1)/R{1}.C(1)-1), 100*(R{k}.C(16)/R{1}.C(16)-1), 100*(R{k}.C(46)/R{1}.C(46)-1));
end
