function p_surv = survival(p, xlsx_path)
%SURVIVAL  T x 1 vector of one-period survival probabilities.
%   p_surv(t) = Pr(alive at t+1 | alive at t). p_surv(T) = 0.

if nargin < 2
    xlsx_path = 'Coefficients_probability_survival.xlsx';
end

raw = readmatrix(xlsx_path);

ages_in_sheet = raw(:, 1);
expected_ages = (p.age0 : p.age0 + p.T - 1).';
if numel(ages_in_sheet) ~= p.T || any(ages_in_sheet ~= expected_ages)
    error('survival:ageMismatch', ...
        'Survival sheet ages do not match (T=%d, age0=%d)', p.T, p.age0);
end

p_surv      = raw(:, p.sex + 1);
p_surv(p.T) = 0;

end
