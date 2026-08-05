function compare_overnight_lna(res_dir)
%COMPARE_OVERNIGHT_LNA  Rank the overnight LNA arms two ways.
%
%   compare_overnight_lna              % scan utility.output_dir()
%   compare_overnight_lna('/data')
%
%   For every ovn_lna_*.mat in res_dir, prints CEV against the tau = 0 arm:
%     (a) from the value function at the b0 anchor, and
%     (b) from the SIMULATED consumption paths,
%         U = E[ sum_t beta^(t-1) * S_t * u(C_t) ].
%
%   READ (a) AND (b) TOGETHER. They are not two estimates of one number: where
%   liquid wealth goes negative the solver charges V = -1e15 while the
%   simulator sets C = 0 and forgives the shortfall, so they price the left
%   tail differently -- and at gamma = 5 roughly 60% of E[U] sits in the worst
%   1% of paths. If they agree on the argmax, the ranking is robust to that
%   gap. If they disagree, the tau ranking is NOT decidable from this run and
%   the fix is a consumption floor carried identically by both sides, not a
%   finer grid.
%
%   The %LW<0 column is the size of the disputed region: the larger it is, the
%   less weight either column carries.

if nargin < 1 || isempty(res_dir), res_dir = utility.output_dir(); end
L = dir(fullfile(res_dir,'ovn_lna_*.mat'));
assert(~isempty(L), 'compare_overnight_lna:none', 'No ovn_lna_*.mat in %s', res_dir);

tau=[]; Vt=[]; U=[]; neg=[]; hh={};
for k = 1:numel(L)
    m  = matfile(fullfile(L(k).folder,L(k).name));
    w  = m.welfare0; s = m.sim; p = m.p; pr = m.profile;
    gg = 1-p.gamma;
    S    = cumprod([1; pr.p_surv(1:p.T-1)]).';
    disc = (p.beta.^(0:p.T-1)).*S;
    C    = max(s.C, 1e-8);                 % C = 0 is undefined for CRRA
    tau(end+1) = w.tau_flat;                                     %#ok<AGROW>
    Vt(end+1)  = w.Vt0_b0;                                       %#ok<AGROW>
    U(end+1)   = mean((C.^gg/gg)*disc.');                        %#ok<AGROW>
    neg(end+1) = 100*s.diagnostics.n_negLW/numel(s.C);           %#ok<AGROW>
    if p.is_owner, hh{end+1} = 'owner'; else, hh{end+1} = 'renter'; end   %#ok<AGROW>
end
g = gg;
[tau,o] = sort(tau); Vt=Vt(o); U=U(o); neg=neg(o);
i0 = find(abs(tau) < 1e-9, 1);
assert(~isempty(i0), 'compare_overnight_lna:noref', ...
    'No tau = 0 arm present, so there is nothing to normalise on.');

fprintf('\n===== overnight LNA frontier (%s, %d arms) =====\n', hh{1}, numel(tau));
fprintf('CEV vs the tau = 0 arm, at the b0 anchor.\n\n');
fprintf('%-8s %18s %20s %14s\n','tau','value function','simulated E[U]','%% hh-yrs LW<0');
for k = 1:numel(tau)
    fprintf('%-8.2f %+17.2f%% %+19.2f%% %13.2f\n', tau(k), ...
        100*((Vt(k)/Vt(i0))^(1/g)-1), 100*((U(k)/U(i0))^(1/g)-1), neg(k));
end

[~,bv] = max(arrayfun(@(k) (Vt(k)/Vt(i0))^(1/g), 1:numel(tau)));
[~,bu] = max(arrayfun(@(k) (U(k)/U(i0))^(1/g),  1:numel(tau)));
fprintf('\nbest tau:  value function %.2f  |  simulation %.2f\n', tau(bv), tau(bu));
if tau(bv) == tau(bu)
    fprintf(['-> the two agree on the argmax, so the ranking survives the\n' ...
             '   solver/simulator disagreement about LW < 0.\n']);
else
    fprintf(['-> they DISAGREE. The tau ranking is not decidable from this run:\n' ...
             '   the two sides price the LW < 0 region differently and that region\n' ...
             '   carries most of the welfare weight at gamma = 5. Next step is a\n' ...
             '   consumption floor applied identically in bellman_step_lna and\n' ...
             '   paths_lna -- not a finer cube.\n']);
end
end
