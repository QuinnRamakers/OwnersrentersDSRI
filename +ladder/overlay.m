function overlay(steps, numerics, opts)
%OVERLAY  Several saved ladder steps on one page per arm.
%
%   ladder.overlay([6 9 10 11 12])                  % standard numerics
%   ladder.overlay({'corr_SL', 'dc_bonds'}, 'quick')
%   ladder.overlay(steps, 'standard', view='pension', name='dc_fund')
%
%   figures.compare with the first step as the black reference and up to five
%   more in colour, saved as overlay_<name>_<arm>.png next to the results. The
%   arms are those of the last step; each is matched to the same tenure in the
%   other steps (ladder.matching_arm). name defaults to the step numbers;
%   view is passed to figures.compare.

arguments
    steps
    numerics (1,:) char = 'standard'
    opts.view (1,:) char = 'default'
    opts.name (1,:) char = ''
end

S = ladder.steps();
if isnumeric(steps), steps = num2cell(steps); end
k = cellfun(@(s) ladder.index(s, S), steps);
num = ladder.numerics(numerics);
R = arrayfun(@(j) ladder.load(j, numerics), k, 'UniformOutput', false);
name = opts.name;
if isempty(name), name = strjoin(arrayfun(@(j) sprintf('%02d', j), k, 'UniformOutput', false), '_'); end

for arm = fieldnames(R{end}).'
    a = arm{1};
    rs = cell(1, numel(k)); labels = cell(1, numel(k));
    for i = 1:numel(k)
        ta = ladder.matching_arm(a, R{i});
        rs{i} = R{i}.(ta);
        labels{i} = sprintf('%d %s: %s', k(i), S(k(i)).name, S(k(i)).label);
    end
    file = fullfile(num.dir, sprintf('overlay_%s_%s.png', name, a));
    figures.compare(rs, labels, sprintf('Steps %s: %s', strjoin(arrayfun(@num2str, k, ...
        'UniformOutput', false), ', '), a), file, view = opts.view);
    fprintf('Wrote %s\n', file);
end
end
