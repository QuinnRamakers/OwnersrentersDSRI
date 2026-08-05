% WELFARE_DC_VS_NODC  Welfare gain of the DC pension (with free investment
% choice) over the no-DC-account benchmark, as a function of the household's
% INITIAL LIQUID BUFFER X0_frac.
%
%   The default welfare0 metric evaluates V at the zero-liquid-buffer corner
%   (X=0, A=0, H=h_mult*Y, Y). There the mandatory contribution cuts an
%   already near-zero t=0 consumption, and CRRA(gamma=5) marginal utility at
%   near-zero c dominates lifetime value, so the DC pension looks
%   welfare-negative even though it raises consumption at almost every later
%   age -- see the nodc_vs_dcchoice_*.png life-cycle panels. Endowing a modest
%   buffer moves the initial node off the corner; this sweep shows how much
%   the verdict depends on that choice.
%
%   Buffered initial node (buffer b years of income): W0=(b+h_mult+1)*Y0,
%   lam0=1/(b+h_mult+1), sX0=b/(b+h_mult+1), sH0=h_mult/(b+h_mult+1), sA0=0,
%   built by utility.welfare_anchor. Both scenarios share W0 at a given b, so
%   CEV = (Vtilde_DC / Vtilde_noDC)^(1/(1-gamma)) - 1.

% Repo = the checkout this script lives in. which() rather than mfilename():
% mfilename returns the CALLER's name when a script is invoked via run() from
% inside a function (as tests/smoke_fill_fix.m does).
repo = fileparts(which('welfare_dc_vs_nodc'));
if isempty(repo), repo = pwd; end
addpath(repo);

tenures = {'renter', 'owner'};
% Sweep values, unchanged. The two CALIBRATED buffers (config.params: b0 =
% median deposits of under-25 households / age-25 wage; b_alt = the 25-35
% median, upper sensitivity) are merged in per tenure below, read from the
% loaded p so they track the calibration.
buffers = [0 0.25 0.5 1 2 3 5 10];

for i = 1:numel(tenures)
    ten = tenures{i};
    B = load(fullfile(repo, sprintf('combined_%s_nodc.mat', ten)),    'sol','p');
    D = load(fullfile(repo, sprintf('combined_%s_freetau.mat', ten)), 'sol','p');
    p = D.p; gamma = p.gamma;

    % Pre-anchor .mat vintages have no b0/b_alt on their stored p; fall back
    % to the config.params expressions so this still runs on the committed
    % files. On those grids the anchors are not nodes, so the two calibrated
    % rows stay interpolated -- expected until the re-solve.
    if isfield(p, 'b0'),    b0 = p.b0;       else, b0 = 3400 / (31500 * 1.303); end
    if isfield(p, 'b_alt'), balt = p.b_alt;  else, balt = 9800 / (31500 * 1.303); end
    anchors  = [b0, balt];
    buf_ten  = sort(unique([buffers, anchors]));

    % One interpolant build per arm, queried at every buffer at once. Both
    % arms are read on p = D.p's grids (the two files must be same-grid for
    % the CEV to mean anything; utility.welfare_anchor asserts the sizes match).
    [vB, node] = utility.welfare_anchor(p, B.sol.V(:,:,:,1), buf_ten);
    vD         = utility.welfare_anchor(p, D.sol.V(:,:,:,1), buf_ten);
    cev        = (vD ./ vB) .^ (1/(1-gamma)) - 1;

    fprintf('\n=== %s: welfare gain of DC+free-choice over no-DC, by initial liquid buffer ===\n', ten);
    fprintf('  X0(yrs)   lam0    sX0     Vtilde no-DC     Vtilde DC-free    CEV\n');
    for j = 1:numel(buf_ten)
        b = buf_ten(j);
        if     b == anchors(1), tag = '  <- calibrated (b0)';
        elseif b == anchors(2), tag = '  <- sensitivity (b_alt)';
        else,                   tag = '';
        end
        fprintf('  %6.4f  %.4f  %.4f  % .6e   % .6e   %+7.2f%%%s\n', ...
            b, node.lam0(j), node.sX0(j), vB(j), vD(j), 100*cev(j), tag);
    end
end
