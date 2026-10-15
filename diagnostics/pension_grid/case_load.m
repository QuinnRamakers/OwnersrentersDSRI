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
end
