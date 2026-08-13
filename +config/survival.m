function p_surv = survival(p, table_path)
%SURVIVAL  T x 1 vector of one-period survival probabilities.
%   p_surv(t) = Pr(alive at t+1 | alive at t). p_surv(T) = 0.
%
%   Default source (calibration table): CBS StatLine "Levensverwachting;
%   geslacht, leeftijd", one-year death probabilities (Sterftekans, q_x) for
%   the 2021-2026 period, SEXES COMBINED ("Totaal mannen en vrouwen") --
%   CBSunisexmortality21-26.csv in the repo root. p_surv = 1 - q_x. Because
%   the table is unisex, p.sex no longer enters here; it now selects the
%   INCOME profile only (config.income_profile).
%
%   The CBS export is a semicolon-delimited, quoted CSV with Dutch decimal
%   commas, a multi-line header, and age labels like "42 jaar" /
%   "99 jaar of ouder", so it is parsed by regexp rather than readmatrix.
%
%   Passing an .xlsx path keeps the legacy sex-specific reader
%   (Coefficients_probability_survival.xlsx, column p.sex + 1) for
%   reproducing pre-2026-07 runs.
%
%   Coverage: ages age0 .. age0+T-2 must be present in the source; the
%   terminal age age0+T-1 needs no q_x because p_surv(T) is forced to 0.

if nargin < 2 || isempty(table_path)
    table_path = 'CBSunisexmortality21-26.csv';
end

expected_ages = (p.age0 : p.age0 + p.T - 1).';
needed_ages   = expected_ages(1 : end - 1);      % terminal age is forced to p_surv = 0

[~, ~, ext] = fileparts(table_path);

if strcmpi(ext, '.csv')
    [ages_in_file, q_death] = read_cbs_csv(table_path);
    [tf, loc] = ismember(needed_ages, ages_in_file);
    if ~all(tf)
        error('survival:ageMismatch', ...
            'CBS life table %s does not cover ages %d-%d (T=%d, age0=%d); missing e.g. age %d', ...
            table_path, needed_ages(1), needed_ages(end), p.T, p.age0, ...
            needed_ages(find(~tf, 1)));
    end
    p_surv               = zeros(p.T, 1);
    p_surv(1 : end - 1)  = 1 - q_death(loc);
    p_surv(p.T)          = 0;
else
    raw = readmatrix(table_path);
    ages_in_sheet = raw(:, 1);
    [tf, loc] = ismember(expected_ages, ages_in_sheet);
    if ~all(tf)
        error('survival:ageMismatch', ...
            'Survival sheet does not cover ages %d-%d (T=%d, age0=%d)', ...
            expected_ages(1), expected_ages(end), p.T, p.age0);
    end
    p_surv      = raw(loc, p.sex + 1);
    p_surv(p.T) = 0;
end

if any(p_surv(1 : end - 1) <= 0 | p_surv(1 : end - 1) >= 1)
    error('survival:range', 'Survival probabilities outside (0,1) at t = %s', ...
        mat2str(find(p_surv(1:end-1) <= 0 | p_surv(1:end-1) >= 1).'));
end

end


function [ages, q_death] = read_cbs_csv(csv_path)
%READ_CBS_CSV  Ages and one-year death probabilities from a CBS StatLine
%   export. Matches data rows of the form
%       "<age> jaar[ of ouder]";"<period>";"<q with a decimal comma>"
%   and ignores the header/footer lines.

txt   = fileread(csv_path);
lines = regexp(txt, '\r\n|\n|\r', 'split');

ages    = zeros(numel(lines), 1);
q_death = zeros(numel(lines), 1);
n       = 0;
for i = 1:numel(lines)
    tok = regexp(lines{i}, '^"(\d+)\s*jaar[^"]*";"[^"]*";"([0-9]+[,.][0-9]+)"', ...
                 'tokens', 'once');
    if isempty(tok), continue; end
    n          = n + 1;
    ages(n)    = str2double(tok{1});
    q_death(n) = str2double(strrep(tok{2}, ',', '.'));
end
ages    = ages(1:n);
q_death = q_death(1:n);

if n == 0
    error('survival:emptyCsv', 'No data rows parsed from %s', csv_path);
end
% A CBS export covering several periods would repeat each age; refuse to
% guess which period is meant rather than silently taking the first.
if numel(unique(ages)) ~= n
    error('survival:duplicateAges', ...
        ['%s contains repeated ages (%d rows, %d distinct ages) -- it ' ...
         'probably spans more than one period. Filter it to a single ' ...
         'period before use.'], csv_path, n, numel(unique(ages)));
end

end
