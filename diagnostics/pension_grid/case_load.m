function r = case_load(step, arm, name)
%CASE_LOAD  A saved solve of the grid study; [] when it is not there.
%
%   r = case_load(12, 'owner', 'pow2_32x32')
%   r = case_load(12, 'owner', 'standard')     % the ladder's own result
%
%   'standard' is the step as ladder.run saved it at standard numerics
%   (uniform 16x16, the same calibration as uniform_16x16).

num = ladder.numerics('standard');
S = ladder.steps();
k = ladder.index(step, S);
if strcmp(name, 'standard')
    file = ladder.result_file(num, k, S(k).name, ['nohousing_' arm]);
else
    file = fullfile(num.dir, 'pension_grid', sprintf('%s_%s_%s_%s.mat', ...
        ladder.number(k, S, true), S(k).name, arm, name));
end
if ~isfile(file), r = []; return; end
r = load(file);
r.case_name = name;
% The equity share of liquid saving, aggregated over households (1 x T):
% stocks held over liquid saving. Households that save nothing carry no weight.
w = warning('off', 'all');
s = figures.panel_data(r).sim;
warning(w);
sav = max(s.LW - s.C, 0);
r.piw = sum(s.pi .* sav, 1) ./ max(sum(sav, 1), realmin);
r.piw(sum(sav, 1) < 0.01 * sum(s.Y, 1)) = NaN;           % ages where saving is under 1% of income
end
