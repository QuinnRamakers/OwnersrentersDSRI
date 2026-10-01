function f = result_file(num, k, name, tenure)
%RESULT_FILE  Where a ladder arm is saved.
f = fullfile(num.dir, sprintf('%02d_%s_%s.mat', k, name, tenure));
end
