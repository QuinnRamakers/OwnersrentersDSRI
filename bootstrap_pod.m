%% BOOTSTRAP_POD  Reinstall git, clone/pull the repo, and install MATLAB
%   toolboxes -- everything needed to get a fresh/restarted pod back to a
%   working state, run entirely from the MATLAB console (no separate
%   terminal needed).
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

repo_dir = fullfile(out_dir, 'OwnersrentersDSRI');

%% -------------------------------------------------------------------------
%% 1. Install git
%% -------------------------------------------------------------------------
system('sudo apt-get update && sudo apt-get install -y git ca-certificates');

%% -------------------------------------------------------------------------
%% 2. Clone the repo onto the persistent volume (or pull if already there)
%% -------------------------------------------------------------------------
if isfolder(fullfile(repo_dir, '.git'))
    fprintf('Repo already present at %s -- pulling latest main.\n', repo_dir);
    [status, output] = system(sprintf( ...
        'git -C "%s" -c http.extraHeader="Authorization: Bearer %s" pull origin main', ...
        repo_dir, token));
else
    fprintf('Cloning repo to %s\n', repo_dir);
    [status, output] = system(sprintf( ...
        'git -c http.extraHeader="Authorization: Bearer %s" clone https://github.com/QuinnRamakers/OwnersrentersDSRI.git "%s"', ...
        token, repo_dir));
end
disp(output)
if status ~= 0
    error('bootstrap_pod:git', 'git step failed -- see output above.');
end

%% -------------------------------------------------------------------------
%% 3. Install the missing MATLAB toolboxes into the existing MATLAB install
%% -------------------------------------------------------------------------
matlab_root = matlabroot;
fprintf('MATLAB root: %s\n', matlab_root);

system('sudo apt-get install -y wget ca-certificates');

cd /tmp
system('wget -q https://www.mathworks.com/mpm/glnxa64/mpm');
system('chmod +x mpm');

cmd = sprintf(['sudo HOME=%s /tmp/mpm install ' ...
    '--destination=%s --release=R2025a ' ...
    '--products Optimization_Toolbox Parallel_Computing_Toolbox'], ...
    getenv('HOME'), matlab_root);
[status, output] = system(cmd);
disp(output)

system('rm -f /tmp/mpm /tmp/mathworks_root.log');

%% -------------------------------------------------------------------------
cd(repo_dir)
fprintf('Done. Now in %s\n', repo_dir);
