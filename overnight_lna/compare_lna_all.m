function T = compare_lna_all(res_dir)
%COMPARE_LNA_ALL  Splines vs the two benchmarks (free DC choice, no pension),
% all on the LNA coordinate system, at the b0 anchor.
%
%   compare_lna_all
%   compare_lna_all('/data')
%
%   Reference is NO PENSION when it is present, so the numbers read as "what
%   is a DC pension worth", the same convention as welfare_by_wealth. The
%   capture ratio then says how much of the free-choice gain a fixed glide
%   keeps. If nodc is missing, the all-bond spline is used instead.
%
%   Both metrics are shown for every arm: the value function at the anchor, and
%   E[sum beta^(t-1) S_t u(C_t)] from the simulated paths. Where they disagree
%   the ranking is not reportable -- the solver charges V = -1e15 when LW <= 0
%   while the simulator sets C = 0 and forgives the shortfall, and at gamma = 5
%   most of the welfare weight sits in exactly that region.
%
%   The free arm comes from ovnf.*, an unvalidated grid-only port (no polish on
%   the tau axis), so treat its value as a LOWER BOUND on true free choice.

if nargin < 1 || isempty(res_dir)
    cands = {utility.output_dir(), getenv('CGM_OUTPUT_DIR'), pwd, '/data'};
else
    cands = {char(res_dir)};
end
res_dir=''; L=[];
for k=1:numel(cands)
    d=cands{k}; if isempty(d)||~isfolder(d), continue; end
    hit=dir(fullfile(d,'ovn_lna_*.mat'));
    if ~isempty(hit), res_dir=d; L=hit; break; end
end
if isempty(L)
    error('compare_lna_all:none','No ovn_lna_*.mat found (CGM_OUTPUT_DIR=[%s]).', ...
        getenv('CGM_OUTPUT_DIR'));
end

n=numel(L); nm=cell(n,1); kind=cell(n,1);
tacc=nan(n,1); tdec=nan(n,1); Vt=nan(n,1); U=nan(n,1); neg=nan(n,1);
for k=1:n
    m=matfile(fullfile(L(k).folder,L(k).name));
    w=m.welfare0; s=m.sim; p=m.p; pr=m.profile; si=m.strat_info;
    g=1-p.gamma;
    S=cumprod([1;pr.p_surv(1:p.T-1)]).'; disc=(p.beta.^(0:p.T-1)).*S;
    C=max(s.C,1e-8);
    nm{k}=si.name; kind{k}=si.type;
    if any(isnan(w.knot_fracs))
        % benchmark arm: read the realised share off the simulation
        tacc(k)=mean(mean(s.tau_A(:,1:p.t_ret-1),1,'omitnan'));
        tdec(k)=mean(mean(s.tau_A(:,p.t_ret:end),1,'omitnan'));
    else
        ts=strategy.spline_tau(p,w.knot_ages,w.knot_fracs);
        tacc(k)=mean(ts(1:p.t_ret-1)); tdec(k)=mean(ts(p.t_ret:end));
    end
    Vt(k)=w.Vt0_b0; U(k)=mean((C.^g/g)*disc.');
    neg(k)=100*s.diagnostics.n_negLW/numel(s.C);
end
gam=g;

iref = find(strcmp(nm,'nodc'),1);
if isempty(iref), iref = find(strcmp(nm,'spl_000_000_000'),1); end
if isempty(iref), [~,iref]=min(tacc+tdec); end
cevV = 100*((Vt/Vt(iref)).^(1/gam)-1);
cevU = 100*((U /U (iref)).^(1/gam)-1);

isb  = ismember(nm,{'free','nodc'});
[~,o]= sort(cevV,'descend');
fprintf('\n===== LNA: splines vs benchmarks, CEV vs %s, at b0 =====\n', nm{iref});
fprintf('%-22s %-10s %8s %8s %14s %16s %9s\n', ...
    'arm','kind','tau_acc','tau_dec','value function','simulated E[U]','%%LW<0');
for k=o(:).'
    tag=''; if isb(k), tag='  <-- benchmark'; end
    fprintf('%-22s %-10s %8.2f %8.2f %+13.2f%% %+15.2f%% %8.2f%s\n', ...
        nm{k}, strrep(kind{k},'lna_',''), tacc(k), tdec(k), cevV(k), cevU(k), neg(k), tag);
end

ifree = find(strcmp(nm,'free'),1);
ispl  = find(~isb);
if ~isempty(ifree) && ~isempty(ispl)
    [bestV,ib] = max(cevV(ispl));  bs = ispl(ib);
    fprintf('\nbest spline: %s  (%+.2f%%)   free choice: %+.2f%%\n', ...
        nm{bs}, bestV, cevV(ifree));
    if abs(cevV(ifree)) > 1e-12
        fprintf('capture ratio (best spline / free choice): %.1f%%\n', 100*bestV/cevV(ifree));
    end
    fprintf('gap to free choice: %+.2f CEV points\n', bestV - cevV(ifree));
    fprintf(['(free is an ovnf grid-only port -- a lower bound -- so the true\n' ...
             ' gap is at least this large.)\n']);
end

[~,bv]=max(cevV); [~,bu]=max(cevU);
fprintf('\nbest overall: value function %s | simulation %s\n', nm{bv}, nm{bu});
if ~strcmp(nm{bv},nm{bu})
    fprintf(['-> DISAGREE, so this ranking is not reportable. Fix is a consumption\n' ...
             '   floor applied identically in the solver and the simulator.\n']);
end

T=table(string(nm),string(kind),tacc,tdec,Vt,cevV,cevU,neg, ...
    'VariableNames',{'arm','kind','tau_acc','tau_dec','Vt0_b0','cev_V_pct','cev_sim_pct','pct_LW_neg'});
T=sortrows(T,'cev_V_pct','descend');
csv=fullfile(res_dir,'lna_all_ranking.csv'); writetable(T,csv);
fprintf('\nCSV: %s\n',csv);
if nargout==0, clear T; end
end
