% Two follow-ups to the designed grid.
%  v2   u2_lo = 0.45 instead of 0.55. On the designed grid the policies moved and
%       u2 reached 0.4884, below my floor -- the occupancy I designed against was
%       the default grid's, and it is endogenous. Five lookups were silently
%       nearest-extrapolated. Fix the floor and confirm it closes.
%  iso  the designed grid with u2 NOT trimmed, to test whether the early-life
%       regression comes from the denser u2 axis resolving more of the cliff
%       region -- the known "refining anything makes early life worse" effect --
%       rather than from the u1 or u3 trims.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
o = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
    function r = go(p, dims, tag)
        p = utility.build_state_grids(p, dims, 3);
        [~,mg,sl]=config.income_profile(p);
        pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(p);
        sk=grids.shock_grid(p); an=pension.annuity_price(p,pf,sk);
        tic; s=solver.solve_lifecycle_lna(p,pf,sk,an); el=toc;
        sm=simulate.forward(p,pf,s,an,4000,20260511,p.b0);
        d2=@(v) 100*mean(abs(diff(v,2)))/mean(abs(v));
        r.tag=tag; r.n=numel(p.u1_grid)*numel(p.u2_grid)*numel(p.u3_grid);
        r.C=median(sm.C,1,'omitnan'); r.pi=mean(sm.pi,1,'omitnan'); r.ages=sm.ages;
        r.rough_mid=d2(r.pi(16:40)); r.rough_ret=d2(r.pi(41:60));
        r.off=sm.diagnostics.n_offgrid_u1+sm.diagnostics.n_offgrid_u2;
        u2=(sm.A+sm.H)./max(sm.X+sm.A+sm.H,eps); r.u2min=min(min(u2(:,3:end-1)));
        fprintf('%-14s n=%5d %4.0fs C25=%6.0f C45=%6.0f pi25=%.2f |d2pi| mid %.2f%% ret %.2f%% off %d minu2 %.4f\n', ...
            tag, r.n, el, r.C(1), r.C(21), r.pi(1), r.rough_mid, r.rough_ret, r.off, r.u2min);
    end
base = @() setfield(setfield(setfield(setfield(config.params(),'is_owner',false), ...
        'grid_mode','none'),'polish_ver',2),'use_refine',false);
des = @(u2lo) setfield(setfield(setfield(setfield(setfield(setfield(base(), ...
        'lambda_hi',0.42),'grid_pow',1.6),'u2_lo',u2lo),'grid_pow_u2',1), ...
        'u3_lo',0.03),'u3_hi',0.96);

dims={[10 10 8],[14 14 10],[18 18 12]};
V=cell(1,3); for k=1:3, V{k}=go(des(0.45),dims{k},'v2 u2lo .45'); end
fprintf('\n');
I2 = go(des(0.00), dims{2}, 'iso u2 untrim');
D0 = go(base(),   dims{2}, 'default');
save([o 'grid_ladder3.mat'],'V','I2','D0');

gap=@(a,b,i) 100*mean(abs(b(i)-a(i))./max(abs(a(i)),eps));
fprintf('\nv2 drift: 25-39 %.1f%% then %.1f%% | 40-69 %.1f%% then %.1f%% | 70+ %.1f%% then %.1f%%\n', ...
    gap(V{1}.C,V{2}.C,1:15), gap(V{2}.C,V{3}.C,1:15), ...
    gap(V{1}.C,V{2}.C,16:45), gap(V{2}.C,V{3}.C,16:45), ...
    gap(V{1}.C,V{2}.C,46:75), gap(V{2}.C,V{3}.C,46:75));
fprintf('\nisolating the early-life regression at 2560 nodes\n');
fprintf('%-18s %10s %10s %10s %10s\n','grid','C25','pi25','|d2pi|ret','off');
for r = {D0, I2, V{2}}
    x=r{1}; fprintf('%-18s %10.0f %10.2f %9.2f%% %10d\n', x.tag, x.C(1), x.pi(1), x.rough_ret, x.off);
end
