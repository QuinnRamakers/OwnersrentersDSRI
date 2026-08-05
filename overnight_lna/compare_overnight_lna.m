function T = compare_overnight_lna(res_dir)
%COMPARE_OVERNIGHT_LNA  Rank the overnight LNA strategies two ways.
%
%   compare_overnight_lna              % scan utility.output_dir()
%   compare_overnight_lna('/data')
%   T = compare_overnight_lna(...)     % also return the table
%
%   For every ovn_lna_*.mat, prints CEV against the all-bond reference arm
%   (spl_000_000_000 if present, else the lowest-equity arm solved):
%     (a) from the value function at the b0 anchor, and
%     (b) from the SIMULATED consumption paths,
%         U = E[ sum_t beta^(t-1) * S_t * u(C_t) ].
%
%   READ (a) AND (b) TOGETHER. They are not two estimates of one number. Where
%   liquid wealth goes negative the solver charges V = -1e15 while
%   simulate.paths_lna sets C = 0 and forgives the shortfall, so the two price
%   the left tail differently -- and at gamma = 5 roughly 60% of E[U] sits in
%   the worst 1% of paths. Agreement on the top arm means the ranking survives
%   that gap. Disagreement means it is not decidable without a consumption
%   floor carried identically by both sides; a finer cube will not fix it.
%
%   tau_acc / tau_dec are the mean equity share over accumulation and over
%   retirement. The menu's knots sit at [age0, retirement_age, age0+T-2], so
%   knots 2-3 move BOTH -- two entries can differ far more in decumulation than
%   in glide. Compare arms at equal tau_dec before calling anything a
%   glide-path result.

% Look in res_dir, then the other places a run plausibly wrote to. The usual
% cause of "no files" is CGM_OUTPUT_DIR set for the solve shell but not this one.
if nargin < 1 || isempty(res_dir)
    cands = {utility.output_dir(), getenv('CGM_OUTPUT_DIR'), pwd, '/data'};
else
    cands = {char(res_dir)};
end
res_dir = ''; L = [];
for k = 1:numel(cands)
    d = cands{k};
    if isempty(d) || ~isfolder(d), continue; end
    hit = dir(fullfile(d,'ovn_lna_*.mat'));
    if ~isempty(hit), res_dir = d; L = hit; break; end
end
if isempty(L)
    tried = strjoin(cellfun(@(d) sprintf('  %s', d), ...
        cands(~cellfun(@isempty,cands)), 'UniformOutput', false), newline);
    error('compare_overnight_lna:none', ...
        ['No ovn_lna_*.mat found. Looked in:\n%s\n\n' ...
         'CGM_OUTPUT_DIR is currently [%s]. If the solve ran with it set to a\n' ...
         'mounted volume, pass that path explicitly:\n' ...
         '    compare_overnight_lna(''/data'')\n' ...
         'If it was unset for the solve too, results went to the job''s working\n' ...
         'folder -- check overnight_lna_log.txt for where that was.'], ...
        tried, getenv('CGM_OUTPUT_DIR'));
end
fprintf('reading %d arm(s) from %s\n', numel(L), res_dir);

n = numel(L);
[nm, Vt, U, neg, tacc, tdec] = deal(cell(n,1), nan(n,1), nan(n,1), nan(n,1), nan(n,1), nan(n,1));
hh = 'owner';
for k = 1:n
    m  = matfile(fullfile(L(k).folder,L(k).name));
    w  = m.welfare0; s = m.sim; p = m.p; pr = m.profile; si = m.strat_info;
    g  = 1 - p.gamma;
    S    = cumprod([1; pr.p_surv(1:p.T-1)]).';
    disc = (p.beta.^(0:p.T-1)).*S;
    C    = max(s.C, 1e-8);                    % C = 0 is undefined for CRRA
    ts   = strategy.spline_tau(p, w.knot_ages, w.knot_fracs);
    nm{k}   = si.name;
    tacc(k) = mean(ts(1 : p.t_ret-1));
    tdec(k) = mean(ts(p.t_ret : end));
    Vt(k)   = w.Vt0_b0;
    U(k)    = mean((C.^g/g)*disc.');
    neg(k)  = 100*s.diagnostics.n_negLW/numel(s.C);
    if ~p.is_owner, hh = 'renter'; end
end
gam = g;

% Reference = the all-bond arm if it was solved, else the lowest-equity one.
iref = find(strcmp(nm,'spl_000_000_000'), 1);
if isempty(iref), [~,iref] = min(tacc + tdec); end
cevV = 100*((Vt/Vt(iref)).^(1/gam) - 1);
cevU = 100*((U /U (iref)).^(1/gam) - 1);

[~,o] = sort(cevV,'descend');
fprintf('\n===== overnight LNA, %s, %d strategies =====\n', hh, n);
fprintf('CEV vs %s, at the b0 anchor.\n\n', nm{iref});
fprintf('%-22s %8s %8s %14s %16s %10s\n', ...
    'strategy','tau_acc','tau_dec','value function','simulated E[U]','%%LW<0');
for k = o(:).'
    fprintf('%-22s %8.2f %8.2f %+13.2f%% %+15.2f%% %9.2f\n', ...
        nm{k}, tacc(k), tdec(k), cevV(k), cevU(k), neg(k));
end

[~,bv] = max(cevV);  [~,bu] = max(cevU);
fprintf('\nbest: value function %s  |  simulation %s\n', nm{bv}, nm{bu});
if strcmp(nm{bv}, nm{bu})
    fprintf(['-> the two agree, so the ranking survives the solver/simulator\n' ...
             '   disagreement about LW < 0.\n']);
else
    fprintf(['-> they DISAGREE, so this ranking is not decidable. The two sides\n' ...
             '   price the LW < 0 region differently and that region carries most\n' ...
             '   of the welfare weight at gamma = 5. Fix is a consumption floor in\n' ...
             '   both bellman_step_lna and paths_lna -- not a finer cube.\n']);
end
if numel(unique(round(tdec,4))) > 1
    fprintf(['\nNOTE: tau_dec varies across these arms, so the ranking mixes glide\n' ...
             '      shape with the retirement equity share. Compare within a\n' ...
             '      constant tau_dec group before calling it a glide-path result.\n']);
end

T = table(string(nm), tacc, tdec, Vt, cevV, cevU, neg, ...
    'VariableNames', {'strategy','tau_acc','tau_dec','Vt0_b0','cev_V_pct','cev_sim_pct','pct_LW_neg'});
T = sortrows(T,'cev_V_pct','descend');
writetable(T, fullfile(res_dir,'overnight_lna_ranking.csv'));
fprintf('\nCSV: %s\n', fullfile(res_dir,'overnight_lna_ranking.csv'));
if nargout == 0, clear T; end
end
