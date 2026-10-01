function cand = grid_design(out_dir, do_report)
%GRID_DESIGN  Place the cube where households actually are.
%
%   Measured occupancy, pooled over 456,000 simulated household-years:
%
%       u1   1-99%  [0.008, 0.210]      axis spans [0.002, 0.42]
%       u2   1-99%  [0.586, 1.000]      axis spans [0.450, 1.000]
%       u3   1-99%  [0.000, 0.865]      axis spans [0.020, 0.980]
%
%   So 45% of the u1 nodes sit above the 99th percentile of where anyone lives,
%   and 30% of the u2 nodes sit below the 1st. The axis bounds were set for
%   safety, and the cost is resolution in the occupied band.
%
%   The metric used to rank designs is not node count but the share of the
%   population falling inside a single cell: if a tenth of the households live
%   between two adjacent nodes, the policy they are assigned is an average over
%   a tenth of the distribution, and refining elsewhere will not fix it.

if nargin<1||isempty(out_dir), out_dir=fileparts(mfilename('fullpath')); end
if nargin<2, do_report=true; end
Q=load(fullfile(out_dir,'occupancy_src.mat')); s=Q.s;
lam=s.lambda; sA=s.sA; sH=s.sH;
u1=lam(:); u2=reshape((sA+sH)./max(1-lam,1e-12),[],1); u3=reshape(sA./max(sA+sH,1e-12),[],1);
ok=isfinite(u1)&isfinite(u2)&isfinite(u3)&u1>0;
U={u1(ok),u2(ok),u3(ok)};

% candidate settings, all at the same node count
cand = struct('name',{},'set',{});
cand(1).name='current';        cand(1).set=struct('lambda_lo',0.0008,'lambda_hi',0.44,'grid_pow',1.6, ...
                                                  'u2_lo',0.40,'grid_pow_u2',1,'u3_lo',0.02,'u3_hi',0.98);
cand(2).name='trimmed bounds'; cand(2).set=struct('lambda_lo',0.0015,'lambda_hi',0.26,'grid_pow',1.6, ...
                                                  'u2_lo',0.55,'grid_pow_u2',1,'u3_lo',0.00,'u3_hi',0.95);
cand(3).name='trimmed + more u1 clustering'; ...
                               cand(3).set=struct('lambda_lo',0.0015,'lambda_hi',0.26,'grid_pow',2.2, ...
                                                  'u2_lo',0.55,'grid_pow_u2',1,'u3_lo',0.00,'u3_hi',0.95);
cand(4).name='logratio';       cand(4).set=struct('lambda_lo',0.0015,'lambda_hi',0.26,'grid_type_space','logratio', ...
                                                  'u2_lo',0.55,'u3_lo',0.00,'u3_hi',0.95);
cand(5).name='trimmed + u2 toward 1 (1.5)'; ...
                               cand(5).set=struct('lambda_lo',0.0015,'lambda_hi',0.26,'grid_pow',2.2, ...
                                                  'u2_lo',0.55,'grid_pow_u2',1.5,'u3_lo',0.00,'u3_hi',0.95);
cand(6).name='trimmed + u2 toward 1 (2.0)'; ...
                               cand(6).set=struct('lambda_lo',0.0015,'lambda_hi',0.26,'grid_pow',2.2, ...
                                                  'u2_lo',0.55,'grid_pow_u2',2.0,'u3_lo',0.00,'u3_hi',0.95);
cand(7).name='trimmed, u2 to 0.62'; ...
                               cand(7).set=struct('lambda_lo',0.0015,'lambda_hi',0.26,'grid_pow',2.2, ...
                                                  'u2_lo',0.62,'grid_pow_u2',1.5,'u3_lo',0.00,'u3_hi',0.95);

if ~do_report, return; end
dims=[16 16 10];
fprintf('occupancy-based grid design, all candidates at dims %s\n\n', mat2str(dims));
fprintf('%-32s %-26s %-26s %-24s\n','design','u1: in-band/worst/top-mass','u2: in-band/worst/top-mass','u3: in-band/worst/top');
for c=1:numel(cand)
    p=config.params(); p.is_owner=false;
    f=fieldnames(cand(c).set);
    for k=1:numel(f)
        if strcmp(f{k},'grid_type_space'), p.grid_space=cand(c).set.(f{k});
        else, p.(f{k})=cand(c).set.(f{k}); end
    end
    try
        p=utility.build_state_grids(p,dims,5);
    catch ME
        fprintf('%-32s  build failed: %s\n', cand(c).name, ME.message); continue;
    end
    G={p.u1_grid(:),p.u2_grid(:),p.u3_grid(:)};
    fprintf('%-32s', cand(c).name);
    for i=1:3
        [frac,worst,topm]=cover(G{i},U{i});
        fprintf(' %6.0f%% /%6.1f%% /%6.1f%%   ', 100*frac, 100*worst, 100*topm);
    end
    fprintf('\n');
end
fprintf(['\nin-band   = share of nodes between the 1st and 99th percentile of occupancy\n' ...
         'worst cell = share of the population inside the single most crowded pair of nodes\n']);
end

% ------------------------------------------------------------------------
function [frac_in, worst_cell, top_mass] = cover(g, x)
%COVER  How well a node vector covers an occupied distribution.
b=[prctile(x,1) prctile(x,99)];
frac_in=mean(g>=b(1) & g<=b(2));
e=[-inf; g(:); inf];
n=histcounts(x, unique(e));
top_mass=n(end)/numel(x);            % mass at or past the last node
worst_cell=max(n(1:end-1))/numel(x);  % worst cell that refinement can actually split
end
