% PLOT_WELFARE_VS_BUFFER  CEV of DC+free-choice over no-DC vs initial liquid
% buffer -- the welfare verdict on the mandatory DC pension flips sign with
% the household's starting liquidity.
% Repo = the checkout this script lives in (which() rather than mfilename():
% mfilename returns the caller's name when run() is used from a function).
repo = fileparts(which('plot_welfare_vs_buffer'));
if isempty(repo), repo = pwd; end
addpath(repo);
tenures = {'renter','owner'};
buffers = linspace(0, 10, 41);
b0 = []; balt = [];
h  = gobjects(1, numel(tenures));

f = figure('Visible','off','Position',[100 100 780 500]); hold on; grid on;
for i = 1:numel(tenures)
    D = load(fullfile(repo, sprintf('combined_%s_freetau.mat', tenures{i})), 'sol','p');
    B = load(fullfile(repo, sprintf('combined_%s_nodc.mat',    tenures{i})), 'sol','p');
    p = D.p; gamma = p.gamma; hm = p.h_mult;
    % Calibrated buffer anchors (config.params). Pre-anchor .mat vintages have
    % no b0/b_alt on their stored p -- fall back to the same expressions.
    if isempty(b0)
        if isfield(p, 'b0'),    b0   = p.b0;      else, b0   = 3400 / (31500 * 1.303); end
        if isfield(p, 'b_alt'), balt = p.b_alt;   else, balt = 9800 / (31500 * 1.303); end
    end
    FvB = mk_interp(B.sol.V(:,:,:,1), p);
    FvD = mk_interp(D.sol.V(:,:,:,1), p);
    cev = zeros(size(buffers));
    for j = 1:numel(buffers)
        b = buffers(j); den = b+hm+1;
        cev(j) = (FvD(1/den,0,hm/den)/FvB(1/den,0,hm/den))^(1/(1-gamma)) - 1;
    end
    h(i) = plot(buffers, 100*cev, '-', 'LineWidth', 1.8);
end
yline(0, ':k', 'LineWidth', 1.2);
% Calibrated buffer and its upper sensitivity (see config.insert_anchor_nodes:
% these are exact grid nodes on re-solved grids, so the CEV read there is a
% solved value rather than a trilinear blend).
xline(b0,   '-',  sprintf('calibrated (b_0 = %.3f)', b0), 'Color', [0.35 0.35 0.35], ...
      'LineWidth', 1.4, 'LabelOrientation', 'horizontal', 'LabelVerticalAlignment', 'top');
xline(balt, '--', sprintf('sensitivity (b = %.3f)', balt), 'Color', [0.35 0.35 0.35], ...
      'LineWidth', 1.4, 'LabelOrientation', 'horizontal', 'LabelVerticalAlignment', 'bottom');
xlabel('initial liquid buffer X_0 (years of income)');
ylabel('welfare gain of DC + free choice vs no DC  (% CEV)');
title('Value of the mandatory DC pension depends on initial liquidity');
legend(h, tenures, 'Location','southeast');   % explicit handles: the y/xlines are not series
saveas(f, fullfile(repo, 'welfare_dc_vs_nodc_by_buffer.png'));
close(f);
fprintf('Saved welfare_dc_vs_nodc_by_buffer.png\n');

function F = mk_interp(V0, p)
    Z = V0;
    if any(isnan(Z(:)))
        [NL,NA,NH]=size(Z); mo=~isnan(Z);
        [Ig,Jg,Kg]=ndgrid(1:NL,1:NA,1:NH);
        Io=Ig(mo);Jo=Jg(mo);Ko=Kg(mo);Vo=Z(mo);
        Ib=Ig(~mo);Jb=Jg(~mo);Kb=Kg(~mo);
        for k=1:numel(Ib)
            d2=(Ib(k)-Io).^2+(Jb(k)-Jo).^2+(Kb(k)-Ko).^2;
            [~,q]=min(d2); Z(Ib(k),Jb(k),Kb(k))=Vo(q);
        end
    end
    F = griddedInterpolant({p.lambda_grid,p.sA_grid,p.sH_grid}, Z, 'linear','nearest');
end
