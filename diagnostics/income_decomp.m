function income_decomp(out_dir)
%INCOME_DECOMP  Full income statement by age, from outcomes.mat. No re-solve.
%
%   The simulator's identity is
%       LW_t  = X_t + disp_t,
%       disp_t = (1-delta)(1-kappa_t)(1-tau_inc) Y_t          net wage or AOW
%              + (1-tau_inc) * A_t / a_t                      net annuity
%              - hc_t * H_t                                   housing cost
%   and every rate in it is deterministic, so it can be rebuilt from the stored
%   medians of Y, A and H exactly rather than approximately. The rebuilt
%   disposable income is checked against the stored one and the residual is
%   printed; anything above rounding means this decomposition is wrong.
%
%   Two panels per case:
%     1  gross income and the wedges taken out of it -- DC contribution,
%        income tax -- plus the gross annuity once it starts
%     2  what is left and what happens to it: disposable income built up from
%        its parts, against consumption

if nargin < 1 || isempty(out_dir), out_dir = fileparts(mfilename('fullpath')); end
L = load(fullfile(out_dir,'outcomes.mat')); R = L.R;
p0 = config.params(); tau = p0.tau_inc; RET = p0.retirement_age; MOR = p0.age0 + p0.N_mort;
fd = fullfile(out_dir,'factorial_figs'); if ~isfolder(fd), mkdir(fd); end

fprintf('%-16s %14s %14s\n','case','max |resid|','as %% of disp');
for ten = {'renter','owner'}
    idx = find(contains({R.tag}, ten{1})); if isempty(idx), continue; end
    is_own = strcmp(ten{1},'owner');
    f = figure('Position',[30 30 1500 760],'Color','w','Visible','off');
    tl = tiledlayout(f, 2, numel(idx)*2, 'Padding','compact','TileSpacing','compact');
    NC = numel(idx)*2;
    for q = 1:numel(idx)
        o = R(idx(q)).out; a = o.ages; c0 = (q-1)*2 + 1;
        net_wage = (o.mY - o.mcontrib) * (1 - tau);
        inc_tax  = (o.mY - o.mcontrib) * tau;
        net_ann  = o.mannuity * (1 - tau);
        ann_tax  = o.mannuity * tau;
        rebuilt  = net_wage + net_ann - o.mhousing;
        resid    = max(abs(rebuilt - o.mdisp));
        fprintf('%-16s %14.4g %13.4f%%\n', R(idx(q)).tag, resid, 100*resid/max(o.mdisp));

        % 1: gross income and the wedges out of it
        ax = nexttile(tl, c0); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
        area(ax, a, [net_wage; inc_tax; o.contrib].'/1000, 'LineStyle','none');
        colororder(ax, [.30 .55 .35; .80 .40 .40; .20 .35 .75]);
        plot(ax, a, o.mY/1000, 'Color',[.1 .1 .1],'LineWidth',1.6);
        plot(ax, a, o.mannuity/1000, 'Color',[.47 .67 .19],'LineWidth',1.6,'LineStyle','--');
        marks(ax, RET, MOR, is_own); xlim(ax,[25 95]); ylabel(ax,'EUR000 / yr');
        title(ax, sprintf('%s  --  gross income and wedges', R(idx(q)).tag),'FontWeight','normal');
        if q==1, legend(ax,{'net wage / AOW','income tax','DC contribution', ...
                            'gross Y','gross annuity'},'Box','off','Location','northwest','FontSize',8); end

        % 2: disposable income and what happens to it
        ax = nexttile(tl, c0+NC); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
        area(ax, a, [net_wage; net_ann].'/1000, 'LineStyle','none');
        colororder(ax, [.30 .55 .35; .47 .67 .19]);
        plot(ax, a, -o.mhousing/1000, 'Color',[.85 .33 .10],'LineWidth',1.8);
        plot(ax, a, o.mdisp/1000, 'Color',[.1 .1 .1],'LineWidth',2);
        plot(ax, a, o.mC/1000, 'Color',[.85 .33 .10],'LineWidth',2,'LineStyle','--');
        yline(ax, 0, '-', 'Color',[.6 .6 .6]);
        marks(ax, RET, MOR, is_own); xlim(ax,[25 95]);
        xlabel(ax,'age'); ylabel(ax,'EUR000 / yr');
        title(ax,'disposable income and consumption','FontWeight','normal');
        if q==1, legend(ax,{'net wage / AOW','net annuity','housing cost (shown negative)', ...
                            'disposable income','consumption'},'Box','off','Location','northwest','FontSize',8); end
    end
    sgtitle(f, sprintf('%s -- income decomposition. Solid line = retirement, dashed = mortgage ends', ten{1}), ...
            'FontWeight','normal','FontSize',13);
    exportgraphics(f, fullfile(fd, sprintf('H2_income_%s.png', ten{1})),'Resolution',140);
    close(f);
end
fprintf('figures in %s\n', fd);
end

function marks(ax, RET, MOR, is_own)
xline(ax, RET, '-', 'Color',[.35 .35 .35],'LineWidth',1.1,'Alpha',.8);
if is_own, xline(ax, MOR, '--', 'Color',[.55 .55 .55],'LineWidth',1.1,'Alpha',.8); end
end
