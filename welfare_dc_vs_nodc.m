% WELFARE_DC_VS_NODC  Welfare gain of the DC pension (with free investment
% choice) over the no-DC-account benchmark, as a function of the household's
% INITIAL LIQUID BUFFER X0_frac.
%
%   The default welfare0 metric evaluates V at the initial state
%   (X=0, A=0, H=h_mult*Y, Y) -- a ZERO-liquid-buffer corner. With kappa=0.2
%   the mandatory DC contribution cuts already-near-zero t=0 consumption, and
%   CRRA(gamma=5) marginal utility at near-zero c dominates the lifetime
%   value, so at that corner the DC pension looks welfare-NEGATIVE even
%   though it raises consumption at almost every later age (see the
%   nodc_vs_dcchoice_*.png life-cycle panels). Endowing a modest liquid
%   buffer moves the initial node off the corner; this sweep shows how the
%   welfare verdict depends on it.
%
%   Buffered initial node (buffer b years of income): W0=(b+h_mult+1)*Y0,
%   lam0=1/(b+h_mult+1), sX0=b/W0frac, sH0=h_mult/(b+h_mult+1), sA0=0.
%   Both scenarios share W0 at a given b, so
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
    p = D.p; gamma = p.gamma; hm = p.h_mult;

    % Pre-anchor .mat vintages have no b0/b_alt on their stored p; fall back
    % to the config.params expressions so this still runs on the committed
    % files. On those grids the anchors are not nodes, so the two calibrated
    % rows stay interpolated -- expected until the re-solve.
    if isfield(p, 'b0'),    b0 = p.b0;       else, b0 = 3400 / (31500 * 1.303); end
    if isfield(p, 'b_alt'), balt = p.b_alt;  else, balt = 9800 / (31500 * 1.303); end
    anchors  = [b0, balt];
    buf_ten  = sort(unique([buffers, anchors]));

    FvB = mk_interp(B.sol.V(:,:,:,1), p);
    FvD = mk_interp(D.sol.V(:,:,:,1), p);

    fprintf('\n=== %s: welfare gain of DC+free-choice over no-DC, by initial liquid buffer ===\n', ten);
    fprintf('  X0(yrs)   lam0    sX0     Vtilde no-DC     Vtilde DC-free    CEV\n');
    for b = buf_ten
        den  = b + hm + 1;
        lam0 = 1/den; sX0 = b/den; sH0 = hm/den;
        vB = FvB(lam0, 0, sH0);
        vD = FvD(lam0, 0, sH0);
        cev = (vD/vB)^(1/(1-gamma)) - 1;
        if     b == anchors(1), tag = '  <- calibrated (b0)';
        elseif b == anchors(2), tag = '  <- sensitivity (b_alt)';
        else,                   tag = '';
        end
        fprintf('  %6.4f  %.4f  %.4f  % .6e   % .6e   %+7.2f%%%s\n', ...
            b, lam0, sX0, vB, vD, 100*cev, tag);
    end
end

function F = mk_interp(V0, p)
    Z = V0;
    if any(isnan(Z(:)))
        [NL,NA,NH] = size(Z); mo = ~isnan(Z);
        [Ig,Jg,Kg] = ndgrid(1:NL,1:NA,1:NH);
        Io=Ig(mo); Jo=Jg(mo); Ko=Kg(mo); Vo=Z(mo);
        Ib=Ig(~mo); Jb=Jg(~mo); Kb=Kg(~mo);
        for k=1:numel(Ib)
            d2=(Ib(k)-Io).^2+(Jb(k)-Jo).^2+(Kb(k)-Ko).^2;
            [~,q]=min(d2); Z(Ib(k),Jb(k),Kb(k))=Vo(q);
        end
    end
    F = griddedInterpolant({p.lambda_grid,p.sA_grid,p.sH_grid}, Z, 'linear','nearest');
end
