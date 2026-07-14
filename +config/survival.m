function p_surv = survival(p, xlsx_path)
%SURVIVAL  T x 1 vector of one-period survival probabilities.
%   p_surv(t) = Pr(alive at t+1 | alive at t). p_surv(T) = 0.

if nargin < 2
    xlsx_path = 'Coefficients_probability_survival.xlsx';
end

raw = readmatrix(xlsx_path);

ages_in_sheet = raw(:, 1);
expected_ages = (p.age0 : p.age0 + p.T - 1).';
[tf, loc] = ismember(expected_ages, ages_in_sheet);
if ~all(tf)
    error('survival:ageMismatch', ...
        'Survival sheet does not cover ages %d-%d (T=%d, age0=%d)', ...
        expected_ages(1), expected_ages(end), p.T, p.age0);
end

p_surv      = raw(loc, p.sex + 1);
p_surv(p.T) = 0;

end
