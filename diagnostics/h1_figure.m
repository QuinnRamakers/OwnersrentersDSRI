function ylims = h1_figure(R, fpath, sub, is_own, ylims_in)
%H1_FIGURE  The 5-row outcome sheet, for any set of cases sharing a tenure.
%
%   R     struct array with .tag (column heading) and .out (h1_summary output)
%   fpath where to write the png
%   sub   figure subtitle
%   is_own  true to draw the mortgage-end line as well as retirement
%   ylims_in  optional 10-by-2 of y-limits, one row per panel position, to
%           force. Use it to give separate figures a common scale. The limits
%           actually used are returned, so a first pass can collect them and a
%           second pass apply their union.
%
%   Two panels per case, five rows:
%     1  gross income and wedges        | disposable income, consumption, outflow
%     2  financial wealth               | holdings by asset
%     3  chosen shares and total equity | DC share of financial wealth
%     4  annual flows                   | liquid balance carried forward
%     5  liquid account on its own      | net flow into the liquid account
%
%   Every panel position shares one y-axis across the cases, so the columns
%   compare in levels and not only in shape.

p0   = config.params();
reit = config.reit_effective(p0);
tauS = config.tau_effective(p0);
tau  = p0.tau_inc;
RET  = p0.retirement_age;
MOR  = p0.age0 + p0.N_mort;

nq = numel(R);
f  = figure('Position',[20 20 min(3300, 200+710*nq) 1740],'Color','w','Visible','off');
NC = nq*2;
tl = tiledlayout(f, 5, NC, 'Padding','compact','TileSpacing','compact');
AX = gobjects(nq, 10);
for q = 1:nq
    o = R(q).out; a = o.ages; c0 = (q-1)*2 + 1; pn = 0;
    K = 1:numel(a); rq = reit(K).'; tq = tauS(K).';
    vl = @(ax) marks(ax, RET, MOR, is_own);
    net_wage = (o.mY - o.mcontrib) * (1 - tau);
    inc_tax  = (o.mY - o.mcontrib) * tau;
    net_ann  = o.mannuity * (1 - tau);

    % row 1: gross income and wedges | disposable income and consumption
    ax = nexttile(tl, c0); pn=pn+1; AX(q,pn)=ax; hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    area(ax,a,[net_wage; inc_tax; o.mcontrib].'/1000,'LineStyle','none');
    colororder(ax,[.30 .55 .35; .80 .40 .40; .20 .35 .75]);
    plot(ax,a,o.mY/1000,'Color',[.1 .1 .1],'LineWidth',1.6);
    plot(ax,a,o.mannuity/1000,'Color',[.47 .67 .19],'LineWidth',1.6,'LineStyle','--');
    vl(ax); xlim(ax,[25 95]); ylabel(ax,'EUR000 / yr');
    title(ax,sprintf('%s  --  gross income, and what is taken out of it',R(q).tag),'FontWeight','normal');
    if q==1, legend(ax,{'take-home pay / state pension (AOW)','income tax','pension contribution', ...
                        'gross income','gross pension annuity'}, ...
                    'Box','off','Location','northwest','FontSize',7); end

    ax = nexttile(tl, c0+1); pn=pn+1; AX(q,pn)=ax; hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    area(ax,a,[net_wage; net_ann].'/1000,'LineStyle','none');
    colororder(ax,[.30 .55 .35; .60 .80 .35]);
    plot(ax,a,o.mhousing/1000,'Color',[.85 .33 .10],'LineWidth',1.8);
    plot(ax,a,o.mdisp/1000,'Color',[.1 .1 .1],'LineWidth',2);
    plot(ax,a,o.mC/1000,'Color',[.85 .33 .10],'LineWidth',2,'LineStyle','--');
    plot(ax,a,(o.mC + o.mhousing)/1000,'Color',[.45 .30 .70],'LineWidth',2,'LineStyle',':');
    vl(ax); xlim(ax,[25 95]); ylabel(ax,'EUR000 / yr');
    title(ax,'what there is to spend, and what is spent','FontWeight','normal');
    if q==1, legend(ax,{'take-home pay / state pension','net pension annuity','housing cost', ...
                        'income after tax and housing (disposable)','consumption', ...
                        'consumption + housing (total spending)'}, ...
                    'Box','off','Location','northwest','FontSize',7); end

    % row 2: financial wealth | holdings by asset
    ax = nexttile(tl, c0+NC); pn=pn+1; AX(q,pn)=ax; hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    area(ax,a,[o.A; o.X].'/1000,'LineStyle','none');
    colororder(ax,[.20 .35 .75; .85 .33 .10]);
    vl(ax); xlim(ax,[25 95]); ylabel(ax,'EUR000');
    title(ax,'financial wealth: pension pot and liquid savings','FontWeight','normal');
    if q==1, legend(ax,{'pension pot (DC)','liquid savings'},'Box','off','Location','northwest','FontSize',7); end

    eq_dc = o.eq_dc; re_dc = rq .* o.A; bd_dc = max(o.bd_dc - re_dc, 0);
    ax = nexttile(tl, c0+1+NC); pn=pn+1; AX(q,pn)=ax; hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    area(ax,a,[eq_dc; re_dc; bd_dc; o.eq_liq; o.bd_liq].'/1000,'LineStyle','none');
    colororder(ax,[.20 .35 .75; .45 .30 .70; .68 .78 .93; .85 .33 .10; .97 .78 .68]);
    vl(ax); xlim(ax,[25 95]); ylabel(ax,'EUR000');
    title(ax,'how that wealth is invested','FontWeight','normal');
    if q==1, legend(ax,{'pension: equity','pension: property (REIT)','pension: bonds', ...
                        'liquid: equity','liquid: bonds'}, ...
                    'Box','off','Location','northwest','FontSize',7); end

    % row 3: chosen shares and total exposure | DC share
    ax = nexttile(tl, c0+2*NC); pn=pn+1; AX(q,pn)=ax; hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    plot(ax,a,100*o.pi_liq,'Color',[.85 .33 .10],'LineWidth',2);
    plot(ax,a,100*tq,'Color',[.20 .35 .75],'LineWidth',2);
    plot(ax,a,100*rq,'Color',[.45 .30 .70],'LineWidth',1.6,'LineStyle','-.');
    plot(ax,a,100*o.tot_eq_sh,'Color',[.1 .1 .1],'LineWidth',2.2);
    vl(ax); xlim(ax,[25 95]); ylim(ax,[0 100]); ylabel(ax,'% held in equity');
    title(ax,'how much is held in equity','FontWeight','normal');
    if q==1, legend(ax,{'liquid savings in equity','pension in equity (glide path)', ...
                        'pension in property (REIT)','total, liquid + pension combined'}, ...
                    'Box','off','Location','north','FontSize',7); end

    ax = nexttile(tl, c0+1+2*NC); pn=pn+1; AX(q,pn)=ax; hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    plot(ax,a,100*o.dcshare,'Color',[.20 .35 .75],'LineWidth',1.8,'LineStyle','--');
    vl(ax); xlim(ax,[25 95]); ylim(ax,[0 100]); ylabel(ax,'% of financial wealth');
    title(ax,'share of financial wealth in the pension pot','FontWeight','normal');
    if q==1, legend(ax,{'pension pot as % of financial wealth'},'Box','off','Location','east','FontSize',7); end

    % row 4: flows | liquid balance
    ax = nexttile(tl, c0+3*NC); pn=pn+1; AX(q,pn)=ax; hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    plot(ax,a,o.contrib/1000,'Color',[.20 .35 .75],'LineWidth',1.8);
    plot(ax,a,o.annuity/1000,'Color',[.47 .67 .19],'LineWidth',1.8);
    plot(ax,a,o.housing/1000,'Color',[.85 .33 .10],'LineWidth',1.8);
    vl(ax); xlim(ax,[25 95]); ylabel(ax,'EUR000 / yr');
    title(ax,'money in and out each year','FontWeight','normal');
    if q==1, legend(ax,{'pension contribution (in)','pension annuity (out)','housing cost (out)'}, ...
                    'Box','off','Location','northwest','FontSize',7); end

    ax = nexttile(tl, c0+1+3*NC); pn=pn+1; AX(q,pn)=ax; hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    plot(ax,a,o.saving/1000,'Color',[.3 .3 .3],'LineWidth',1.8);
    plot(ax,a,o.X/1000,'Color',[.85 .33 .10],'LineWidth',1.4,'LineStyle','--');
    vl(ax); xlim(ax,[25 95]); ylabel(ax,'EUR000');
    title(ax,'liquid savings: start vs. end of year','FontWeight','normal');
    if q==1, legend(ax,{'left over after spending (year end)','liquid savings (year start)'}, ...
                    'Box','off','Location','northwest','FontSize',7); end

    % row 5: the liquid account on its own scale, level and net flow. In the
    % row 2 stack it is a band on top of a DC pot an order of magnitude
    % larger, so its shape is unreadable there.
    ax = nexttile(tl, c0+4*NC); pn=pn+1; AX(q,pn)=ax; hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    area(ax,a,o.X/1000,'FaceColor',[.85 .33 .10],'FaceAlpha',.25,'LineStyle','none');
    plot(ax,a,o.X/1000,'Color',[.85 .33 .10],'LineWidth',2);
    vl(ax); xlim(ax,[25 95]); xlabel(ax,'age'); ylabel(ax,'EUR000');
    title(ax,'liquid savings, on their own scale','FontWeight','normal');
    if q==1, legend(ax,{'','liquid savings (median household)'},'Box','off','Location','northwest','FontSize',7); end

    fl = (o.mdisp - o.mC)/1000;        % net income - consumption - housing
    ax = nexttile(tl, c0+1+4*NC); pn=pn+1; AX(q,pn)=ax; hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    area(ax,a,max(fl,0),'FaceColor',[.30 .55 .35],'FaceAlpha',.55,'LineStyle','none');
    area(ax,a,min(fl,0),'FaceColor',[.80 .40 .40],'FaceAlpha',.55,'LineStyle','none');
    plot(ax,a,fl,'Color',[.1 .1 .1],'LineWidth',1.6);
    yline(ax,0,'-','Color',[.5 .5 .5]);
    vl(ax); xlim(ax,[25 95]); xlabel(ax,'age'); ylabel(ax,'EUR000 / yr');
    title(ax,'net saving into liquid savings each year','FontWeight','normal');
    if q==1, legend(ax,{'adding to savings','drawing down','net'},'Box','off', ...
                    'Location','northeast','FontSize',7); end
end
same_scale(AX);
if nargin >= 5 && ~isempty(ylims_in)
    for pn2 = 1:size(AX,2)
        g = AX(:,pn2); g = g(isgraphics(g));
        if ~isempty(g) && all(isfinite(ylims_in(pn2,:))) && diff(ylims_in(pn2,:)) > 0
            set(g, 'YLim', ylims_in(pn2,:));
        end
    end
end
ylims = nan(size(AX,2), 2);
for pn2 = 1:size(AX,2)
    g = AX(:,pn2); g = g(isgraphics(g));
    if ~isempty(g), ylims(pn2,:) = g(1).YLim; end
end
sgtitle(f, sub, 'FontWeight','normal','FontSize',13,'Interpreter','none');
exportgraphics(f, fpath, 'Resolution',130);
close(f);
end

% ------------------------------------------------------------------------
function marks(ax, RET, MOR, is_own)
xline(ax, RET, '-', 'Color',[.35 .35 .35],'LineWidth',1.1,'Alpha',.8);
if is_own, xline(ax, MOR, '--', 'Color',[.55 .55 .55],'LineWidth',1.1,'Alpha',.8); end
end

% ------------------------------------------------------------------------
function same_scale(AX)
%SAME_SCALE  One y-axis per panel position, shared by every case in the figure.
for p = 1:size(AX,2)
    g = AX(:,p); g = g(isgraphics(g));
    if numel(g) < 2, continue; end
    lo = min(arrayfun(@(x) x.YLim(1), g));
    hi = max(arrayfun(@(x) x.YLim(2), g));
    set(g, 'YLim', [lo hi]);
end
end
