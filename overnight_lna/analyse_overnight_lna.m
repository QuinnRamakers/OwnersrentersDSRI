function T = analyse_overnight_lna(res_dir)
%ANALYSE_OVERNIGHT_LNA  Read the overnight LNA arms in the order that matters.
%
%   analyse_overnight_lna              % scan utility.output_dir()
%   analyse_overnight_lna('/data')
%   T = analyse_overnight_lna(...)     % also return the per-arm table
%
%   Prints four blocks:
%     [1] RUN VALIDITY   -- what actually got solved, and the size of the
%         region where the solver and the simulator disagree (LW < 0). If that
%         region is large, nothing below carries much weight.
%     [2] DECISION GATE  -- does the value function agree with simulated E[U]
%         on the best arm? At gamma = 5 roughly 60% of E[U] sits in the worst
%         1% of paths, and production leaves that region undefined (solver
%         charges V = -1e15, simulator sets C = 0 and forgives the shortfall).
%         Disagreement here means the ranking is NOT reportable, and the fix is
%         a consumption floor in both, not a finer cube.
%     [3] LIKE-FOR-LIKE  -- the menu's knots sit at [age0, retirement_age,
%         age0+T-2], so knots 2-3 set the RETIREMENT share as well as the
%         glide. Only arms sharing (knot2, knot3) differ in the accumulation
%         glide alone. This block groups them and reports the glide effect
%         WITHIN each group, which is the only clean read of a glide path.
%     [4] FULL RANKING   -- every arm, both metrics.
%
%   Writes overnight_lna_analysis.csv and fig_overnight_lna.png into res_dir.

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
    error('analyse_overnight_lna:none', ...
        ['No ovn_lna_*.mat found (looked in %s). CGM_OUTPUT_DIR is [%s]; if the\n' ...
         'solve ran with it set elsewhere, pass that path explicitly.'], ...
        strjoin(cands(~cellfun(@isempty,cands)),', '), getenv('CGM_OUTPUT_DIR'));
end

n = numel(L);
nm = cell(n,1); k1=nan(n,1); k2=nan(n,1); k3=nan(n,1);
tacc=nan(n,1); tdec=nan(n,1); Vt=nan(n,1); U=nan(n,1); neg=nan(n,1); nsim=nan(n,1);
hh = 'owner';
for k = 1:n
    m = matfile(fullfile(L(k).folder,L(k).name));
    w = m.welfare0; s = m.sim; p = m.p; pr = m.profile; si = m.strat_info;
    g = 1 - p.gamma;
    S    = cumprod([1; pr.p_surv(1:p.T-1)]).';
    disc = (p.beta.^(0:p.T-1)).*S;
    C    = max(s.C, 1e-8);                    % C = 0 is undefined for CRRA
    ts   = strategy.spline_tau(p, w.knot_ages, w.knot_fracs);
    f    = w.knot_fracs;
    nm{k}=si.name; k1(k)=f(1); k2(k)=f(2); k3(k)=f(min(3,numel(f)));
    tacc(k)=mean(ts(1:p.t_ret-1)); tdec(k)=mean(ts(p.t_ret:end));
    Vt(k)=w.Vt0_b0; U(k)=mean((C.^g/g)*disc.');
    neg(k)=100*s.diagnostics.n_negLW/numel(s.C); nsim(k)=size(s.C,1);
    if ~p.is_owner, hh='renter'; end
end
gam = g;
iref = find(strcmp(nm,'spl_000_000_000'),1);
if isempty(iref), [~,iref] = min(tacc+tdec); end
cevV = 100*((Vt/Vt(iref)).^(1/gam)-1);
cevU = 100*((U /U (iref)).^(1/gam)-1);

%% [1] run validity
fprintf('\n================ [1] RUN VALIDITY ================\n');
fprintf('  %d arm(s), %s, N_sim = %d, read from %s\n', n, hh, nsim(1), res_dir);
fprintf('  disputed region (LW < 0, priced -1e15 by the solver and forgiven by\n');
fprintf('  the simulator): min %.2f%%  median %.2f%%  max %.2f%% of household-years\n', ...
    min(neg), median(neg), max(neg));
if max(neg) > 5
    fprintf('  >> WARNING: over 5%% of household-years sit in that region. At gamma=5\n');
    fprintf('     it carries most of the welfare weight, so treat every number below\n');
    fprintf('     as provisional until a consumption floor is added to both sides.\n');
end

%% [2] decision gate
[~,bv]=max(cevV); [~,bu]=max(cevU);
fprintf('\n================ [2] DECISION GATE ================\n');
fprintf('  best by value function : %s\n', nm{bv});
fprintf('  best by simulated E[U] : %s\n', nm{bu});
if strcmp(nm{bv},nm{bu})
    fprintf('  -> AGREE. The ranking survives the solver/simulator gap; proceed.\n');
else
    fprintf('  -> DISAGREE. The ranking is NOT reportable. The two sides price the\n');
    fprintf('     LW < 0 region differently and that region carries most of the\n');
    fprintf('     welfare weight. Next step is a consumption floor applied\n');
    fprintf('     identically in bellman_step_lna and paths_lna, NOT a finer cube.\n');
end

%% [3] like-for-like: glide effect within constant (knot2, knot3)
fprintf('\n================ [3] LIKE-FOR-LIKE GLIDE EFFECT ================\n');
fprintf('  Only arms sharing (knot2, knot3) differ in the accumulation glide alone.\n');
[grp,~,gi] = unique([k2 k3],'rows');
any_group = false;
for j = 1:size(grp,1)
    idx = find(gi==j);
    if numel(idx) < 2, continue; end
    any_group = true;
    [~,so] = sort(k1(idx));  idx = idx(so);
    fprintf('\n  knot2=%.2f knot3=%.2f  (tau_dec = %.2f)\n', grp(j,1), grp(j,2), tdec(idx(1)));
    fprintf('  %-22s %8s %14s %16s\n','strategy','knot1','value function','simulated E[U]');
    for i = idx(:).'
        fprintf('  %-22s %8.2f %+13.2f%% %+15.2f%%\n', nm{i}, k1(i), cevV(i), cevU(i));
    end
    dV = cevV(idx(end))-cevV(idx(1));  dU = cevU(idx(end))-cevU(idx(1));
    fprintf('  glide effect (knot1 %.2f -> %.2f): %+.2f pts by V, %+.2f pts by sim\n', ...
        k1(idx(1)), k1(idx(end)), dV, dU);
    if sign(dV) ~= sign(dU) && abs(dV) > 0.2 && abs(dU) > 0.2
        fprintf('  >> the two metrics disagree on the SIGN of the glide effect here.\n');
    end
end
if ~any_group
    fprintf('  No (knot2,knot3) group has 2+ arms -- every arm differs in the\n');
    fprintf('  retirement share too, so no clean glide comparison is available.\n');
end

%% [4] full ranking
[~,o] = sort(cevV,'descend');
fprintf('\n================ [4] FULL RANKING ================\n');
fprintf('CEV vs %s, at the b0 anchor.\n\n', nm{iref});
fprintf('%-22s %8s %8s %14s %16s %9s\n','strategy','tau_acc','tau_dec','value function','simulated E[U]','%%LW<0');
for k = o(:).'
    fprintf('%-22s %8.2f %8.2f %+13.2f%% %+15.2f%% %8.2f\n', ...
        nm{k}, tacc(k), tdec(k), cevV(k), cevU(k), neg(k));
end

%% outputs
T = table(string(nm),k1,k2,k3,tacc,tdec,Vt,cevV,cevU,neg, ...
    'VariableNames',{'strategy','knot1','knot2','knot3','tau_acc','tau_dec', ...
                     'Vt0_b0','cev_V_pct','cev_sim_pct','pct_LW_neg'});
T = sortrows(T,'cev_V_pct','descend');
csv = fullfile(res_dir,'overnight_lna_analysis.csv'); writetable(T,csv);

f1 = figure('Visible','off','Position',[60 60 1000 430],'Color','w');
subplot(1,2,1); hold on; grid on; box on
for j = 1:size(grp,1)
    idx = find(gi==j); if numel(idx)<2, continue; end
    [~,so]=sort(k1(idx)); idx=idx(so);
    plot(k1(idx),cevV(idx),'-o','LineWidth',2,'MarkerFaceColor','w', ...
        'DisplayName',sprintf('knot2=%.2f knot3=%.2f',grp(j,1),grp(j,2)));
end
yline(0,'k:','HandleVisibility','off');
xlabel('knot1 (equity share at age 25)'); ylabel(sprintf('CEV vs %s (%%)',nm{iref}));
title('value function'); legend('Location','best','FontSize',8);
subplot(1,2,2); hold on; grid on; box on
for j = 1:size(grp,1)
    idx = find(gi==j); if numel(idx)<2, continue; end
    [~,so]=sort(k1(idx)); idx=idx(so);
    plot(k1(idx),cevU(idx),'-s','LineWidth',2,'MarkerFaceColor','w', ...
        'DisplayName',sprintf('knot2=%.2f knot3=%.2f',grp(j,1),grp(j,2)));
end
yline(0,'k:','HandleVisibility','off');
xlabel('knot1 (equity share at age 25)'); ylabel('CEV (%)');
title('simulated E[U]'); legend('Location','best','FontSize',8);
png = fullfile(res_dir,'fig_overnight_lna.png');
exportgraphics(f1,png,'Resolution',140); close(f1);

fprintf('\nCSV: %s\nPNG: %s\n', csv, png);
if nargout == 0, clear T; end
end
