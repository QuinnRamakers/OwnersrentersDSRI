%% BOOTSTRAP_POD  Fetch the repo code (ephemeral) and install MATLAB
%   toolboxes (persistent) -- everything needed to get a fresh/restarted
%   pod back to a working state, run entirely from the MATLAB console (no
%   separate terminal needed, and no git/apt-get required).
%
%   Design: only the MATLAB install goes on the persistent volume
%   ($CGM_OUTPUT_DIR/matlab) -- it's the slow, multi-GB part, so it should
%   only ever be installed once per PVC. The repo itself is ~300KB of .m
%   files with no tracked binaries, so it's fetched fresh into ephemeral
%   storage (/tmp) on every run via a plain tarball download -- faster than
%   `apt-get install git` (which pulls git's whole dependency chain) and
%   keeps the PV free of a redundant code checkout.
%
%   Before running, set the two required environment variables:
%       setenv('CGM_OUTPUT_DIR', '/Solutionstorage')   % PVC mount path
%       setenv('GITHUB_TOKEN',   '<your PAT>')         % repo-read scope
%
%   Usage:
%       bootstrap_pod

out_dir = getenv('CGM_OUTPUT_DIR');
token   = getenv('GITHUB_TOKEN');
assert(~isempty(out_dir), 'Set CGM_OUTPUT_DIR first, e.g. setenv(''CGM_OUTPUT_DIR'',''/Solutionstorage'')');
assert(~isempty(token),   'Set GITHUB_TOKEN first, e.g. setenv(''GITHUB_TOKEN'',''<your PAT>'')');

repo_dir = fullfile(tempdir, 'OwnersrentersDSRI');   % ephemeral -- not on the PV

%% -------------------------------------------------------------------------
%% 1. Fetch the repo code as a tarball (no git, no apt-get needed)
%% -------------------------------------------------------------------------
if isfolder(repo_dir), rmdir(repo_dir, 's'); end
mkdir(repo_dir);

tarball = fullfile(tempdir, 'repo.tar.gz');
[status, output] = system(sprintf( ...
    ['wget -q --header="Authorization: Bearer %s" ' ...
     '--header="Accept: application/vnd.github+json" ' ...
     '-O "%s" https://api.github.com/repos/QuinnRamakers/OwnersrentersDSRI/tarball/main'], ...
    token, tarball));
if status ~= 0
    disp(output)
    error('bootstrap_pod:download', 'Tarball download failed -- see output above.');
end

[status, output] = system(sprintf('tar -xzf "%s" -C "%s" --strip-components=1', tarball, repo_dir));
disp(output)
if status ~= 0
    error('bootstrap_pod:extract', 'Tarball extraction failed -- see output above.');
end
delete(tarball);
fprintf('Code ready at %s (ephemeral -- re-fetched on every pod start)\n', repo_dir);

%% -------------------------------------------------------------------------
%% 2. Install the missing MATLAB toolboxes into the existing MATLAB install
%%    (persisted on the PV -- only does real work the first time)
%% -------------------------------------------------------------------------
matlab_root = matlabroot;
fprintf('MATLAB root: %s\n', matlab_root);

cd(tempdir)
system('wget -q https://www.mathworks.com/mpm/glnxa64/mpm');
system('chmod +x mpm');

cmd = sprintf(['sudo HOME=%s ./mpm install ' ...
    '--destination=%s --release=R2025a ' ...
    '--products Optimization_Toolbox Parallel_Computing_Toolbox'], ...
    getenv('HOME'), matlab_root);
[status, output] = system(cmd);
disp(output)

delete(fullfile(tempdir, 'mpm'));

%% -------------------------------------------------------------------------
cd(repo_dir)
fprintf('Done. Now in %s\n', repo_dir);
