function dest = keep_superseded(file)
%KEEP_SUPERSEDED  Move a saved result aside before it is saved over.
%
%   dest = utility.keep_superseded(file)
%
%   If file exists, moves it into a folder superseded/ next to it, named with
%   its save time (<name>_yyyyMMdd_HHmmss.mat), and returns the new path;
%   returns '' if there is no file. Call it just before saving over a result,
%   so a re-solve at another calibration never loses the earlier solve. A
%   listing of the result folder itself does not see the moved files.

dest = '';
if ~isfile(file), return; end
d = dir(file);
[folder, stem, ext] = fileparts(file);
old = fullfile(folder, 'superseded');
if ~isfolder(old), mkdir(old); end
stamp = char(datetime(d.datenum, 'ConvertFrom', 'datenum'), 'yyyyMMdd_HHmmss');
dest = fullfile(old, [stem '_' stamp ext]);
movefile(file, dest);
end
