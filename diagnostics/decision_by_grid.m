function decision_by_grid(sp, out_dir)
%DECISION_BY_GRID  The objective over (c, pi) at one economic state, solved on
%   cubes of different size.
%
%   S24 shows the Bellman right hand side over the two decisions at a single
%   resolution. What the household faces at a given state is not fixed by the
%   model alone: the continuation value entering that objective is an
%   interpolant of the solved value function, so it inherits the cube's
%   resolution. This solves the same model on a ladder of cubes and dumps the
%   (c, pi) surface at the same economic state in each, so the surface can be
%   compared directly across resolutions.
%
%   The state is the occupancy median for that age -- where households of that
%   age actually sit -- located in each cube by nearest node, so the state
%   drifts slightly between cubes. Each panel reports the coordinates it
%   actually used.
%
%   Solver settings match landscape_scan: no sweep, active-set, so the seed in
%   each dump is the raw warm start.
%
%   Resumable: one .mat per cube, skipped if already present.

if nargin<1||isempty(sp)
    sp='C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad';
end
if nargin<2||isempty(out_dir)
    out_dir='C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc/diagnostics';
end
res=fullfile(out_dir,'decision_by_grid.mat');

DIMS={[8 8 6],[12 12 8],[16 16 10],[20 20 12]};
TS=[10 30 45 60];                       % ages 34, 54, 69, 84
% occupancy medians (u1, u2, u3) at those ages, from occupancy_src
TGT=[0.1393 0.6549 0.2757;              % 34
     0.0780 0.7365 0.6728;              % 54
     0.0169 0.8924 0.7507;              % 69
     0.0282 0.9667 0.5408];             % 84

G=struct('dim',{},'N',{},'n',{},'sec',{},'dir',{},'t',{},'node',{},'coord',{});
if isfile(res), L=load(res); G=L.G; end

for i=1:numel(DIMS)
    if any(arrayfun(@(g) isequal(g.dim,DIMS{i}), G)), continue; end
    sd=fullfile(sp,'scans_grid',sprintf('n%05d',prod(DIMS{i})));
    if isfolder(sd), rmdir(sd,'s'); end
    mkdir(sd);
    fprintf('[%s] cube %s ...\n', datestr(now,'HH:MM:SS'), mat2str(DIMS{i}));

    p=config.params(); p.is_owner=false;
    p.grid_mode='none'; p.polish_ver=2; p.polish_algo='active-set'; p.use_refine=0;
    p.lambda_lo=0.0008; p.lambda_hi=0.44; p.grid_pow=1.6;
    p.u2_lo=0.40; p.grid_pow_u2=1; p.u3_lo=0.02; p.u3_hi=0.98;
    p=utility.build_state_grids(p, DIMS{i}, 5);
    N=[p.N_u1 p.N_u2 p.N_u3];

    nodes=zeros(numel(TS),1); coord=zeros(numel(TS),3);
    for a=1:numel(TS)
        [~,i1]=min(abs(p.u1_grid(:)-TGT(a,1)));
        [~,i2]=min(abs(p.u2_grid(:)-TGT(a,2)));
        [~,i3]=min(abs(p.u3_grid(:)-TGT(a,3)));
        nodes(a)=sub2ind(N,i1,i2,i3);
        coord(a,:)=[p.u1_grid(i1) p.u2_grid(i2) p.u3_grid(i3)];
    end
    p.scan=struct('t',TS,'nodes',unique(nodes),'c_n',81,'pi_n',61,'dir',sd);

    [~,mg,sl]=config.income_profile(p);
    pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(p);
    sk=grids.shock_grid(p); an=pension.annuity_price(p,pf,sk);
    tic; solver.solve_lifecycle_lna(p,pf,sk,an); sec=toc;

    G(end+1).dim=DIMS{i}; G(end).N=N; G(end).n=prod(N); G(end).sec=sec;   %#ok<AGROW>
    G(end).dir=sd; G(end).t=TS; G(end).node=nodes; G(end).coord=coord;
    save(res,'G','-v7.3');
    F=dir(fullfile(sd,'scan_*.mat'));
    fprintf('   cube %s = %d nodes | %.0f s | %d scans written\n', mat2str(N), prod(N), sec, numel(F));
end
fprintf('done: %d cubes\n', numel(G));
end
