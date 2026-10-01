function convergence_causes(out_dir)
%CONVERGENCE_CAUSES  Two candidate causes of the resolution dependence, tested.
%
%   What is established so far. At the nodes households actually occupy the
%   objective is benign: the warm start is already close to the optimum and
%   none of the (c, pi) square is ruin. The badly behaved surfaces -- cliffs,
%   competing basins, large ruin plains -- sit in the sparsely visited part of
%   the cube. They reach the occupied region only through the interpolated
%   continuation value. That gives two candidate causes:
%
%     RUIN     the ruin region carries z = 0, so any interpolation stencil that
%              straddles its boundary drags the continuation value down by an
%              amount that depends on where the boundary falls relative to the
%              nodes, which changes with every refinement. Raising the
%              consumption floor makes ruin finite instead of catastrophic and
%              should damp that if it is the mechanism.
%
%     PLACEMENT 45% of the u1 nodes and 30% of the u2 nodes sit outside the
%              1-99 percentile of occupancy. Trimming the axes to the occupied
%              range buys resolution where it matters at no extra cost, and
%              should improve convergence if the problem is simply too few
%              nodes in the occupied band.
%
%   Both arms are run on the same three cubes, against the baseline ladder
%   already in grid_convergence.mat, and compared on simulated paths, which are
%   the only thing comparable across grids.
%
%   Resumable: each solve saved as it finishes.

if nargin<1||isempty(out_dir), out_dir=fileparts(mfilename('fullpath')); end
res=fullfile(out_dir,'convergence_causes.mat');
DIMS={[12 12 8],[16 16 10],[20 20 12]};
TS=[10 30 50];

BASE=struct('lambda_lo',0.0008,'lambda_hi',0.44,'grid_pow',1.6, ...
            'u2_lo',0.40,'grid_pow_u2',1,'u3_lo',0.02,'u3_hi',0.98,'phi_floor',[]);
ARMS=struct('name',{},'set',{});
ARMS(1).name='floor raised';      ARMS(1).set=setf(BASE,'phi_floor',0.02);
ARMS(2).name='trimmed to occupancy'; ...
    ARMS(2).set=setf(setf(setf(setf(BASE,'lambda_hi',0.26),'u2_lo',0.55),'grid_pow',2.2),'u3_hi',0.95);
ARMS(3).name='trimmed + floor';   ...
    ARMS(3).set=setf(setf(setf(setf(setf(BASE,'lambda_hi',0.26),'u2_lo',0.55),'grid_pow',2.2),'u3_hi',0.95),'phi_floor',0.02);

R=struct('arm',{},'dim',{},'n',{},'sec',{},'sim',{},'pol',{},'ruin',{});
if isfile(res), L=load(res); R=L.R; end
for i=1:numel(DIMS)
    for j=1:numel(ARMS)
        if any(arrayfun(@(r) isequal(r.dim,DIMS{i}) && strcmp(r.arm,ARMS(j).name), R)), continue; end
        fprintf('[%s] %s at %s ...\n', datestr(now,'HH:MM:SS'), ARMS(j).name, mat2str(DIMS{i}));
        try
            tic; o=run_one(DIMS{i}, ARMS(j).set, TS); sec=toc;
            R(end+1).arm=ARMS(j).name; R(end).dim=DIMS{i}; R(end).n=prod(DIMS{i}); %#ok<AGROW>
            R(end).sec=sec; R(end).sim=o.sim; R(end).pol=o.pol; R(end).ruin=o.ruin;
            save(res,'R','-v7.3');
            fprintf('   %.0f s | pi@80=%.3f C@34=%.0f ruin nodes=%.1f%%\n', sec, ...
                o.sim.pi_liq(o.sim.ages==80), o.sim.C(o.sim.ages==34), 100*o.ruin.frac_mid);
        catch ME
            fprintf('   FAILED: %s\n', ME.message);
        end
    end
end
report(R, out_dir);
end

% ------------------------------------------------------------------------
function s = setf(s, f, v), s.(f)=v; end

% ------------------------------------------------------------------------
function o = run_one(dim, set, ts)
p=config.params(); p.is_owner=false;
p.grid_mode='none'; p.polish_ver=2; p.polish_algo='active-set';
p.use_refine=true; p.refine_stage='pre';
p.refine_pi_global=true; p.refine_c_global=true;
f=fieldnames(set);
for k=1:numel(f)
    if isempty(set.(f{k})), continue; end
    p.(f{k})=set.(f{k});
end
p=utility.build_state_grids(p,dim,5);
[~,mg,sl]=config.income_profile(p);
pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(p);
shk=grids.shock_grid(p); an=pension.annuity_price(p,pf,shk);
sol=solver.solve_lifecycle_lna(p,pf,shk,an);

g=p.gamma; ceof=@(v) ((1-g)*v).^(1/(1-g));
i3=round(p.N_u3/2);
o.pol.u1=p.u1_grid(:); o.pol.u2=p.u2_grid(:); o.pol.t=ts;
for a=1:numel(ts)
    o.pol.pi{a}=squeeze(sol.pi_pol(:,:,i3,ts(a)));
    o.pol.c{a} =squeeze(sol.c_pol (:,:,i3,ts(a)));
    o.pol.z{a} =ceof(squeeze(sol.V(:,:,i3,ts(a))));
end
% ruin diagnostic: nodes whose certainty equivalent is a small fraction of the
% best at that age, i.e. states the household cannot recover from
Z=ceof(sol.V); o.ruin.byage=nan(1,size(Z,4));
for t=1:size(Z,4)
    zz=Z(:,:,:,t); zz=zz(isfinite(zz));
    if isempty(zz), continue; end
    o.ruin.byage(t)=mean(zz < 0.05*max(zz));
end
o.ruin.frac_mid=o.ruin.byage(30);
s=simulate.forward(p,pf,sol,an,6000,20260511,p.b0);
o.sim=h1_summary(p,s);
end

% ------------------------------------------------------------------------
function report(R, out_dir)
if isempty(R), fprintf('nothing solved\n'); return; end
B=load(fullfile(out_dir,'grid_convergence.mat')); RB=B.R;
b5=find([RB.gh]==5); [~,ob]=sort([RB(b5).n]); b5=b5(ob);
ref=RB(b5(end));                                  % 8064-node baseline
fprintf('\n=== convergence against the 8064-node baseline ===\n');
fprintf('%-24s %-14s %10s %12s %12s %12s\n','arm','cube','sec','RMS dpi acc','RMS dpi ret','RMS dC/C');
arms=[{'baseline'} unique({R.arm},'stable')];
for a=1:numel(arms)
    for i=1:numel(b5)
        if strcmp(arms{a},'baseline')
            k=b5(i); s=RB(k).sim; d=RB(k).dim; sec=RB(k).sec;
            if RB(k).n>5000, continue; end
        else
            k=find(strcmp({R.arm},arms{a}) & arrayfun(@(r) isequal(r.dim,RB(b5(i)).dim), R),1);
            if isempty(k), continue; end
            s=R(k).sim; d=R(k).dim; sec=R(k).sec;
        end
        acc=s.ages<=55; ret=s.ages>=67;
        dpi=s.pi_liq-ref.sim.pi_liq; dC=(s.C-ref.sim.C)./max(ref.sim.C,eps);
        fprintf('%-24s %-14s %10.0f %12.4f %12.4f %12.4f\n', arms{a}, mat2str(d), sec, ...
            sqrt(mean(dpi(acc).^2)), sqrt(mean(dpi(ret).^2)), sqrt(mean(dC.^2)));
    end
end
fprintf('\n=== ruin share of the cube, by arm (age 54) ===\n');
for k=1:numel(R)
    fprintf('%-24s %-14s %8.1f%%\n', R(k).arm, mat2str(R(k).dim), 100*R(k).ruin.frac_mid);
end
end
