function report_b0(b)
%REPORT_B0  The step-7 PDF again, with every solve simulated from other starting savings.
%
%   report_b0(1)      % starting liquid savings of 1 year of gross income at 25
%
%   No solve is repeated: each saved solution is simulated again from b * Y0
%   (restart_sim) and every page of recent_pdf is drawn from those panels into
%   ladder/standard_16x16x10_gh5/grid_design/b<b>/, ending in
%   step7_grid_study_b<b>.pdf there. Needs the same saved solves as recent_pdf.

repo = fileparts(fileparts(fileparts(mfilename('fullpath'))));
cd(repo);
addpath(fullfile(repo, 'diagnostics', 'step07'), fullfile(repo, 'diagnostics', 'grid_design'));
res = fullfile(repo, 'ladder', 'standard_16x16x10_gh5');
gd  = fullfile(res, 'grid_design');
tag = strrep(sprintf('b%g', b), '.', 'p');
out = fullfile(gd, tag);
if ~isfolder(out), mkdir(out); end

% Section 1: step 7 as run against the doubled income axis (figures 1-4)
ruin_figures([], b0=b, out=out, figures=1:4);

% Section 2: figures 1-3 per pair of grids
f = @(n) fullfile(gd, ['owner_' n '.mat']);
cur16 = fullfile(res, '07_housing_owner.mat');
pairs = {
    {f('logwealth_16x16'), f('logwealth_32x32'), cur16, f('uniform_32x32')}, ...
        {'log-wealth grid 16x16', 'log-wealth grid 32x32', 'current grid 16x16', 'current grid 32x32'}, ...
        'log-wealth grid', 'current grid', '_logwealth'
    {f('logwealth_32x32'), f('logwealth_64x48'), f('uniform_32x32'), f('uniform_64x48')}, ...
        {'log-wealth grid 32x32', 'log-wealth grid 64x48', 'current grid 32x32', 'current grid 64x48'}, ...
        'log-wealth grid', 'current grid', '_dense'
    {f('logwealth_64x48'), f('logwealth_128x96'), cur16, f('uniform_64x48')}, ...
        {'log-wealth grid 64x48', 'log-wealth grid 128x96', 'current grid 16x16 (as run)', 'current grid 64x48'}, ...
        'log-wealth grid', 'current grid', '_converged'
    {f('power_32x32'), f('power_64x48'), f('logwealth_32x32'), f('logwealth_128x96')}, ...
        {'power grid 32x32', 'power grid 64x48', 'log-wealth grid 32x32', 'log-wealth grid 128x96 (reference)'}, ...
        'power grid', 'log-wealth grid', '_power'
    };
for i = 1:size(pairs, 1)
    ruin_figures([], files=pairs{i, 1}, names=pairs{i, 2}, main=pairs{i, 3}, alt=pairs{i, 4}, ...
        tag=pairs{i, 5}, out=out, figures=1:3, b0=b);
end

% Sections 3 and 4: every grid against the reference, and the dashboards
To = compare_grids(ref='logwealth_128x96', b0=b, out=out);
Tr = compare_grids(ref='logwealth_128x96', owner=false, b0=b, out=out);
dash = {'owner', 'uniform_16x16'; 'owner', 'power_64x48'; 'owner', 'logwealth_128x96'; ...
        'renter', 'power_64x48'; 'renter', 'logwealth_128x96'};
for i = 1:size(dash, 1)
    if strcmp(dash{i, 2}, 'uniform_16x16')
        r = load(fullfile(res, sprintf('07_housing_%s.mat', dash{i, 1})));
    else
        s = load(fullfile(gd, sprintf('%s_%s.mat', dash{i, 1}, dash{i, 2}))); r = s.r;
    end
    figures.dashboard(restart_sim(r, b), fullfile(out, sprintf('dashboard_%s_%s.png', dash{i, 1}, dash{i, 2})));
end

recent_pdf(figdir=out, diagdir=out, pdf=fullfile(out, sprintf('step7_grid_study_%s.pdf', tag)), ...
    start=sprintf(['The simulations start with liquid savings of %g years of gross income at 25 (the runs in ' ...
    'step7_grid_study.pdf start from 0.079). Only the simulations differ: the solutions are the same.'], b), ...
    owner_lines=gap_lines(To, 'bankrupt household-years', 'floored_pct'), ...
    renter_lines=gap_lines(Tr, 'renters 25-39 at the consumption bound', 'bound_25_39_pct'));
end

% ------------------------------------------------------------------------
function L = gap_lines(T, what, col)
% The cover table: largest equity-share gap to the reference, one more column, solve time.
names = ["uniform_16x16", "uniform_64x48", "logwealth_32x32", "logwealth_64x48", "power_32x32", "power_64x48", ...
         "logwealth_128x96"];
labs  = {'current 16x16 (as run)', 'current 64x48', 'log-wealth 32x32', 'log-wealth 64x48', 'power 2, 32x32', ...
         'power 2, 64x48', 'reference 128x96'};
L = {sprintf('Largest gap to log-wealth 128x96 over ages 26-95 (mean equity share; %s; solve):', what)};
for i = 1:numel(names)
    k = find(T.grid == names(i), 1);
    if isempty(k), continue; end
    L{end+1} = sprintf('  %-24s %5.2f   %6.2f%%   %5.0f s', labs{i}, T.max_dpi(k), T.(col)(k), T.solve_s(k)); %#ok<AGROW>
end
end
