function [ages, growth_men, growth_women] = income_table_bkv()
%INCOME_TABLE_BKV  Semi-parametric age-effect estimates on log full-time
%   wages, selection-corrected, from Been, Knoef & Vethaak (2026, JBES
%   44(1):215-226), Online Appendix Tables D.1 (men) / D.2 (women),
%   "Full-time, Selection" columns. Verbatim transcription -- no
%   fitting, no smoothing.
%
%   Values are log-wage growth relative to the OMITTED REFERENCE AGE,
%   24 (growth(24) = 0 by construction; age 25 already has its own
%   nonzero coefficient -- do not mistake age 25 for the baseline).
%
%   Source data: administrative IPO/payroll panel, Netherlands,
%   2001-2014, ages 24-64, first-difference estimator with an ordered
%   panel-data sample-selection correction (J=5 labor-supply categories).

ages = (24:64).';

growth_men = [0.00, 0.06, 0.11, 0.17, 0.22, 0.27, 0.32, 0.36, 0.40, 0.43, ...
              0.46, 0.48, 0.51, 0.53, 0.55, 0.57, 0.59, 0.60, 0.62, 0.63, ...
              0.65, 0.65, 0.66, 0.67, 0.68, 0.68, 0.69, 0.70, 0.70, 0.70, ...
              0.71, 0.71, 0.70, 0.70, 0.70, 0.69, 0.66, 0.63, 0.58, 0.53, 0.50].';

growth_women = [0.00, 0.05, 0.11, 0.16, 0.21, 0.25, 0.28, 0.32, 0.36, 0.38, ...
                0.41, 0.43, 0.45, 0.46, 0.47, 0.48, 0.49, 0.51, 0.52, 0.53, ...
                0.54, 0.55, 0.57, 0.57, 0.58, 0.59, 0.59, 0.60, 0.60, 0.60, ...
                0.59, 0.58, 0.58, 0.56, 0.56, 0.54, 0.52, 0.50, 0.50, 0.45, 0.42].';

assert(numel(ages) == 41 && numel(growth_men) == 41 && numel(growth_women) == 41, ...
    'income_table_bkv:length', 'Expected 41 entries (ages 24-64).');

end
