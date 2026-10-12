function P = step07_paths()
%STEP07_PATHS  Folders used by the step-7 diagnosis scripts.
%   repo  the repository root
%   res   saved ladder results at standard numerics
%   out   where the diagnosis figures go
%   data  where solve_cases saves its results
P.repo = fileparts(fileparts(fileparts(mfilename('fullpath'))));
P.res  = fullfile(P.repo, 'ladder', 'standard_16x16x10_gh5');
P.out  = fullfile(P.res, 'diagnosis');
P.data = fullfile(P.out, 'data');
end
