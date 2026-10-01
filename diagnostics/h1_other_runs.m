function h1_other_runs(src, out_dir)
%H1_OTHER_RUNS  The H1 outcome sheet for the earlier runs that kept full paths.
%
%   Only runs that stored the whole simulate.forward output can be drawn this
%   way: the sheet needs Y, ann_pay, disp_inc, X, A, H, pi and tau_A per
%   household. The 132-cell factorial and the 28-cell lever sweep stored age
%   profiles only and are missing most of those, so they cannot be redrawn
%   without re-solving.
%
%   src      folder holding final_grid_run.mat and owner_fixed.mat
%   out_dir  where factorial_figs lives (default: this folder)

if nargin < 2 || isempty(out_dir), out_dir = fileparts(mfilename('fullpath')); end
fd = fullfile(out_dir,'factorial_figs'); if ~isfolder(fd), mkdir(fd); end
note = 'Pension pot holds 10%% property (REIT). Vertical lines: solid = retirement at 67, dashed = mortgage paid off.';

% --- renter, grid lever -------------------------------------------------
L = load(fullfile(src,'final_grid_run.mat'));
R = struct('tag',{},'out',{});
for i = 1:numel(L.S)
    p = L.S{i}.p;
    R(end+1).tag = sprintf('renter, %s grid', L.S{i}.arm);                 %#ok<AGROW>
    R(end).out   = h1_summary(p, L.S{i}.sim);
    report(R(end).tag, p, L.S{i}.sim);
end
h1_figure(R, fullfile(fd,'H1_grid_renter.png'), ...
          ['renter households -- default vs redesigned wealth grid. ' note], false);
clear L

% --- owner, grid lever and housing lever --------------------------------
L = load(fullfile(src,'owner_fixed.mat'));
G = struct('tag',{},'out',{}); H = struct('tag',{},'out',{});
for i = 1:numel(L.R)
    p = L.R{i}.p; o = h1_summary(p, L.R{i}.sim); t = L.R{i}.tag;
    report(sprintf('owner, %s', t), p, L.R{i}.sim);
    switch t
        case 'default grid',  G(end+1).tag = 'owner, default grid';  G(end).out = o; %#ok<AGROW>
        case 'designed grid', G(end+1).tag = 'owner, designed grid'; G(end).out = o; %#ok<AGROW>
                              H(1).tag = 'owner, housing x1.00';     H(1).out   = o;
        case 'housing cost x0.50', H(2).tag = 'owner, housing x0.50'; H(2).out = o;
        case 'housing cost x0.25', H(3).tag = 'owner, housing x0.25'; H(3).out = o;
    end
end
h1_figure(G, fullfile(fd,'H1_grid_owner.png'), ...
          ['owner households -- default vs redesigned wealth grid. ' note], true);
h1_figure(H, fullfile(fd,'H1_housing_owner.png'), ...
          ['owner households -- effect of cheaper housing (full / half / quarter cost). ' note], true);
fprintf('figures in %s\n', fd);
end

% ------------------------------------------------------------------------
function report(tag, p, s)
%REPORT  Print the configuration each sheet was solved with, so the column
%   headings can be checked against what was actually run.
fprintf('%-28s nodes=%4d dims=[%2d %2d %2d] gh_n=%d paths=%5d lambda=[%.4f %.2f] alpha=%.4f theta=%.4f\n', ...
        tag, p.N_u1*p.N_u2*p.N_u3, p.N_u1, p.N_u2, p.N_u3, p.gh_n, s.N, ...
        p.lambda_grid(1), p.lambda_grid(end), p.alpha, p.theta);
end
