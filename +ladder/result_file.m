function f = result_file(num, k, name, tenure)
%RESULT_FILE  Where a ladder arm is saved: NN_<name>_<tenure>.mat, NN the step's
%   number (ladder.number) for the step at position k.
f = fullfile(num.dir, sprintf('%s_%s_%s.mat', ladder.number(k, [], true), name, tenure));
end
