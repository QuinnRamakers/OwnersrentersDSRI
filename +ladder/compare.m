function compare(step, numerics, opts)
%COMPARE  What one ladder step changed: overlay it on the step before.
%
%   ladder.compare(k)                      % step k against k-1
%   ladder.compare('pension', 'quick')
%   ladder.compare(k, 'standard', against=1)  % against another step
%
%   One step dashboard per arm (figures.step_dashboard: both steps with their
%   10th-90th percentile bands, and the parameters that differ), saved next to
%   the results as compare_JJ_KK_<arm>.png, and a table of the main quantities
%   at a few ages. A step with a renter and an owner arm also gets
%   owner_renter_KK.png, the two arms on one page. Levels are in multiples of
%   entry income when the income units differ. Each arm is compared with the
%   same tenure of the other step where it has one, and with its single
%   no-housing arm otherwise.

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
    t  = tenure{1};
    tp = matching_arm(t, prev);
    rs = {prev.(tp), cur.(t)};
    labels = {sprintf('%d %s (%s)', j, S(j).name, tp), sprintf('%d %s (%s)', k, S(k).name, t)};
    file = fullfile(num.dir, sprintf('compare_%02d_%02d_%s.png', j, k, t));
    figures.step_dashboard(rs{1}, rs{2}, labels, sprintf('Step %d, %s: %s against step %d', ...
        k, S(k).label, t, j), file, changes = changed(rs{1}.p, rs{2}.p));
    print_table(rs, labels);
end
arms = fieldnames(cur);
o = arms(endsWith(arms, 'owner')); n = arms(endsWith(arms, 'renter'));
if isscalar(o) && isscalar(n)
    figures.step_dashboard(cur.(n{1}), cur.(o{1}), {sprintf('%d %s (%s)', k, S(k).name, n{1}), ...
        sprintf('%d %s (%s)', k, S(k).name, o{1})}, sprintf('Step %d, %s: renter and owner', k, S(k).label), ...
        fullfile(num.dir, sprintf('owner_renter_%02d.png', k)), ...
        colours = [0.45 0.20 0.55; 0.20 0.60 0.30], changes = changed(cur.(n{1}).p, cur.(o{1}).p));
end
end

function L = changed(pa, pb)
% The primitives that differ between two calibrations, as 'name: a -> b'.
L = {};
for f = fieldnames(config.params(false)).'
    a = []; b = [];
    if isfield(pa, f{1}), a = pa.(f{1}); end
    if isfield(pb, f{1}), b = pb.(f{1}); end
    if ~isequaln(a, b)
        L{end+1} = sprintf('%s: %s -> %s', f{1}, val(a), val(b)); %#ok<AGROW>
    end
end
if ~isequal(pa.is_owner, pb.is_owner) && pa.h_mult == 0 && pb.h_mult == 0
    L{end+1} = '(without housing, is_owner only selects the renter or owner income cubic and shock std)';
end
end

function s = val(v)
if ischar(v) || isstring(v), s = char(v); else, s = mat2str(v, 6); end
end

function tp = matching_arm(t, prev)
% The arm of prev to set against arm t: the same label, then the same tenure
% with or without housing, then the single no-housing arm, then the first.
side = erase(t, 'nohousing_');
for c = {t, ['nohousing_' side], side, 'nohousing'}
    if isfield(prev, c{1}), tp = c{1}; return; end
end
tp = fieldnames(prev); tp = tp{1};
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
