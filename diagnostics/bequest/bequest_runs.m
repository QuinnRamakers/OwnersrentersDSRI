function rs = bequest_runs(step, arm, bs, opts)
%BEQUEST_RUNS  One rung of the bequest test: a ladder step at several b.
%
%   rs = bequest_runs(1, 'renter', [0 1 2.5 5])
%   rs = bequest_runs(18, 'owner', [0 2.5], base = 'pow3_16x16_lim')
%
%   Solves the step with chi = b^gamma for each b (the case_params suffix
%   _beqb<10 b>; b = 0 is the step itself) with solve_cases, one at a time,
%   on the production grid placement unless base names another. Then draws
%   into opts.out one comparison page in the bequest view (figures.compare,
%   black = the first b) and a dashboard per run, and prints per run the
%   solve time, model.checks, and consumption, liquid saving, the equity
%   share and the bequest at a few ages. Needs diagnostics/pension_grid on
%   the path.

arguments
    step
    arm (1,:) char
    bs (1,:) double
    opts.base (1,:) char = 'pow3_32x16_lim_u3n40_qn4_as_nc11'
    opts.out (1,:) char = fullfile(utility.output_dir(), 'bequest')
end
assert(numel(bs) >= 2 && numel(bs) <= 6, 'bequest_runs:n', 'two to six values of b');
if ~isfolder(opts.out), mkdir(opts.out); end
names = cell(1, numel(bs));
for i = 1:numel(bs)
    names{i} = opts.base;
    if bs(i) > 0, names{i} = sprintf('%s_beqb%d', opts.base, round(10 * bs(i))); end
end
solve_cases(string(step) + ":" + arm + ":" + string(names));

S = ladder.steps(); k = ladder.index(step, S);
tag = sprintf('%s_%s_%s', ladder.number(k, S, true), S(k).name, arm);
rs = cellfun(@(nm) case_load(step, arm, nm), names, 'UniformOutput', false);
labels = arrayfun(@(b, r) sprintf('b = %g (chi %.3g)', b, r{1}.p.chi), bs, rs, 'UniformOutput', false);
ttl = sprintf('Step %s (%s), %s: the bequest motive at b = chi^(1/gamma) = %s, gamma %g', ...
    ladder.number(k, S), S(k).label, arm, strjoin(arrayfun(@(b) sprintf('%g', b), bs, 'UniformOutput', false), ', '), ...
    rs{1}.p.gamma);
figures.compare(rs, labels, ttl, fullfile(opts.out, [tag '_bequest.png']), view = 'bequest');
for i = 1:numel(rs)
    figures.dashboard(rs{i}, fullfile(opts.out, sprintf('%s_%s.png', tag, names{i})));
end

ages = [30 45 60 66 75 85 95];
fprintf('\n%s, base %s, solved one at a time\n', tag, opts.base);
fprintf('%-8s %-10s %-16s %8s  %-10s %8s %8s %8s\n', 'b', 'chi', 'grid points', 'solve min', 'search', ...
    'bound%', 'offgrid', 'entry');
for i = 1:numel(rs)
    p = rs{i}.p; c = rs{i}.checks;
    fprintf('%-8g %-10.4g %-16s %8.1f  %-10s %8.2f %8d %8.4f\n', bs(i), p.chi, ...
        sprintf('%dx%dx%dx%d', p.N_u1, p.N_u2, p.N_u3, numel(p.q_grid)), rs{i}.timing.solve_sec / 60, ...
        p.fmincon_algorithm, 100 * c.c_bound_25_39, sum(c.offgrid), c.ce_entry);
end
t = ages - rs{1}.p.age0 + 1;
fprintf('\nMeans by age (%s; consumption over all households, the rest over those not bankrupt)\n', ...
    rs{1}.summary.units);
fprintf('%-8s %-10s%s\n', 'b', 'series', sprintf('%10d', ages));
for i = 1:numel(rs)
    s = rs{i}.summary; d = figures.panel_data(rs{i});
    fprintf('%-8g %-10s%s\n', bs(i), 'C', sprintf('%10.0f', s.C.mean(t)));
    fprintf('%-8s %-10s%s\n', '', 'X', sprintf('%10.0f', s.X.mean(t)));
    fprintf('%-8s %-10s%s\n', '', 'pi', sprintf('%10.2f', s.pi(t)));
    fprintf('%-8s %-10s%s\n', '', 'bequest', sprintf('%10.0f', mean(d.bequest(:, t), 1, 'omitnan')));
    [~, ~, mu, med] = figures.bequest_at_death(d);
    [~, fl] = model.floor_kind(rs{i}.p);
    fprintf('%-8s bequest at death: mean %.0f, median %.0f; at 100: mean %.0f; %s at 85 %.1f%%\n', '', ...
        mu, med, mean(d.bequest(:, end), 'omitnan'), fl, 100 * s.floored(85 - rs{i}.p.age0 + 1));
end
end
