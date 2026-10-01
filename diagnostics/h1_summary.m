function o = h1_summary(p, s)
%H1_SUMMARY  Age profiles behind the H1 outcome sheet, from one solved run.
%
%   Medians for levels, means for anything that has to add up: the income
%   statement is rebuilt from its parts and medians are not additive, which
%   left a 2-3% residual when it was tried.
%
%   p is the parameter struct the run was solved with (kappa, theta,
%   m_rate_path and alpha are read from it); s is the simulate.forward output.

K   = 1:size(s.tau_A,2);            % tau_A is one period shorter
med = @(M) median(M,1,'omitnan');

o.ages = s.ages(K);
o.C    = med(s.C(:,K));
o.disp = med(s.disp_inc(:,K));
o.X    = med(s.X(:,K));      o.A = med(s.A(:,K));   o.H = med(s.H(:,K));
o.fin  = med(s.X(:,K) + s.A(:,K));
o.dcshare = med(s.A(:,K) ./ max(s.X(:,K)+s.A(:,K), eps));

% equity and bonds, per household then aggregated, so the four pieces add up
o.eq_liq = med(s.pi(:,K)    .* s.X(:,K));
o.bd_liq = med((1-s.pi(:,K)).* s.X(:,K));
o.eq_dc  = med(s.tau_A(:,K) .* s.A(:,K));
o.bd_dc  = med((1-s.tau_A(:,K)).* s.A(:,K));
o.eq_tot = med(s.pi(:,K).*s.X(:,K) + s.tau_A(:,K).*s.A(:,K));
o.pi_liq = mean(s.pi(:,K),1,'omitnan');
o.tot_eq_sh = mean((s.pi(:,K).*s.X(:,K) + s.tau_A(:,K).*s.A(:,K)) ...
                   ./ max(s.X(:,K)+s.A(:,K),eps), 1, 'omitnan');

% flows
kap = p.kappa(:).'; kap = kap(min(K, numel(kap)));
o.contrib = med(kap .* s.Y(:,K));
o.annuity = med(s.ann_pay(:,K));
if p.is_owner
    hcr = p.theta + [p.m_rate_path(:).' zeros(1, p.T)];
else
    hcr = p.alpha * ones(1, p.T);
end
o.housing = med(hcr(K) .* s.H(:,K));
o.saving  = med(s.LW(:,K) - s.C(:,K));
o.Y       = med(s.Y(:,K));

% the additive versions, for the income statement
o.mY       = mean(s.Y(:,K),1,'omitnan');
o.mcontrib = mean(kap .* s.Y(:,K),1,'omitnan');
o.mannuity = mean(s.ann_pay(:,K),1,'omitnan');
o.mhousing = mean(hcr(K) .* s.H(:,K),1,'omitnan');
o.mdisp    = mean(s.disp_inc(:,K),1,'omitnan');
o.mC       = mean(s.C(:,K),1,'omitnan');
end
