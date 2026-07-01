function [logY, mu_growth, sigma_l_log] = income_profile(p)
%INCOME_PROFILE  Deterministic log-income path and growth/shock vectors.
%
%   logY        T x 1   log income at each life period
%   mu_growth   (T-1)x1 deterministic log-income growth t -> t+1
%   sigma_l_log (T-1)x1 std dev of log-income shock at each transition
%                       (zero for t >= retirement)
%
%   Post-retirement income is the FIRST-PILLAR (AOW) only:
%       y_R = p.replacement * Y_{T_R - 1}
%   The DC second pillar is added separately in the Bellman / simulation,
%   so p.replacement should be calibrated as the AOW-only replacement
%   rate (Dutch context: ~0.30-0.40 of modal gross income), NOT the total
%   target replacement rate.

T     = p.T;
t_ret = p.t_ret;
ages  = (p.age0 : p.age0 + T - 1).';

work_idx  = 1 : (t_ret - 1);
work_ages = ages(work_idx);
a = p.income_coef;
logY_work = a(1) ...
          + a(2) .* work_ages ...
          + a(3) .* (work_ages.^2) / 100 ...
          + a(4) .* (work_ages.^3) / 1e4;

logY = nan(T, 1);
logY(work_idx) = logY_work;

logY(t_ret) = logY(t_ret - 1) + log(p.replacement);
for t = (t_ret + 1) : T
    logY(t) = logY(t - 1);
end

mu_growth                = diff(logY);
sigma_l_log              = p.sigma_l_log * ones(T - 1, 1);
% The retirement transition step (t_ret-1 -> t_ret) is DETERMINISTIC: AOW is
% replacement * Y_{t_ret-1} with no shock. Simulator implements it that way;
% solver must agree, so we zero out sigma here as well as in retirement itself.
sigma_l_log(t_ret - 1 : end) = 0;

end
