function compare(step, numerics, opts)
%COMPARE  What one ladder step changed: overlay it on the step before.
%
%   ladder.compare(k)                      % step k against k-1
%   ladder.compare('pension', 'quick')
%   ladder.compare(k, 'standard', against=1)  % against another step
%
%   One figure per tenure, saved next to the results, and a table of the
%   main quantities at a few ages. Levels are in multiples of entry income, so
%   steps that change the income units (the CGM core uses CGM's) still line
%   up. A step without housing is compared with both tenures of a step with it.

arguments
    step
    numerics (1,:) char = 'standard'
    opts.against = []
end

S = ladder.steps();
k = ladder.index(step, S);
if isempty(opts.against), j = max(k - 1, 1); else, j = ladder.index(opts.against, S); end
cur  = ladder.load(k, numerics);
prev = ladder.load(j, numerics);
num  = ladder.numerics(numerics);

for tenure = fieldnames(cur).'
    t = tenure{1};
    if isfield(prev, t), tp = t; else, tp = 'nohousing'; end
    if ~isfield(prev, tp), tp = fieldnames(prev); tp = tp{1}; end
    rs = {prev.(tp), cur.(t)};
    labels = {sprintf('%d %s (%s)', j, S(j).name, tp), sprintf('%d %s (%s)', k, S(k).name, t)};
    file = fullfile(num.dir, sprintf('compare_%02d_%02d_%s.png', j, k, t));
    figures.compare(rs, labels, sprintf('Step %d, %s: %s', k, S(k).label, t), file);
    print_table(rs, labels);
end
end

function print_table(rs, labels)
fprintf('\n%-28s %6s %9s %9s %9s %7s %7s %8s\n', '', 'age', 'C/Y0', 'NW/Y0', 'DC/Y0', 'pi', 'equity', 'floored');
for i = 1:numel(rs)
    s = rs{i}.summary; a = s.ages;
    for age = [25 35 45 55 66 75 85]
        m = a == age;
        if ~any(m), continue; end
        fprintf('%-28s %6d %9.2f %9.2f %9.2f %7.2f %7.2f %7.1f%%\n', labels{i}, age, ...
            s.C.p50(m) / s.Y0, s.net_worth.mean(m) / s.Y0, s.A.mean(m) / s.Y0, ...
            s.pi(m), s.equity_share(m), 100 * s.floored(m));
    end
end
for i = 1:numel(rs)
    c = rs{i}.checks;
    fprintf('%-28s entry value = constant %.3g x Y0; c-bound 25-39 %.0f%%; off-grid %d\n', ...
        labels{i}, c.ce_entry, 100 * c.c_bound_25_39, sum(c.offgrid));
end
end
