function p_surv = survival(p, table_path)
%Code to calculate survivial probabilities from a CBS lifetable

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
%reading the mortality data

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

if numel(unique(ages)) ~= n
    error('survival:duplicateAges', ...
        ['%s contains repeated ages (%d rows, %d distinct ages) -- it ' ...
         'probably spans more than one period. Filter it to a single ' ...
         'period before use.'], csv_path, n, numel(unique(ages)));
end

end
