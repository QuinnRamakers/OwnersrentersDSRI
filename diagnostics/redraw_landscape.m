function redraw_landscape(sp, outdir)
%REDRAW_LANDSCAPE  The pi problem the solver actually faces.
%
%   A (c, pi) heat map is useless here: consumption dominates the objective by
%   orders of magnitude, so every panel saturates. The object that matters is
%   the profile after optimising consumption out,
%
%       prof(pi) = max_c  rhs(c, pi),
%
%   which is the one-dimensional problem left in pi. Plotted as percent of
%   certainty equivalent below the best pi at that node, so the vertical scale
%   is the welfare actually at stake.

if nargin<1||isempty(sp), sp='C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/'; end
if nargin<2||isempty(outdir), outdir='C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc/diagnostics/factorial_figs/'; end
g=5; ceof=@(v) ((1-g)*v).^(1/(1-g));
sd=[sp 'scans/']; F=dir([sd 'scan_*.mat']); M=numel(F);

% ---- pass 1: profile statistics for every scanned node
npk=zeros(M,1); rngp=zeros(M,1); solv_loss=zeros(M,1); age=zeros(M,1);
for i=1:M
    S=load([sd F(i).name]);
    pr=ceof(max(S.rhs,[],1));  pr=pr/max(pr);
    ok=isfinite(pr) & pr>0.5;                       % ignore the ruin cliff
    npk(i)=count_peaks(pr, 1e-6);
    rngp(i)=1-min(pr(ok));
    [~,ip]=min(abs(S.pi-S.solver_opt(2)));
    solv_loss(i)=1-pr(ip);
    tok=regexp(F(i).name,'scan_t(\d+)','tokens'); age(i)=24+str2double(tok{1}{1});
end

% genuine traps: more than one peak in the pi profile, solver on the wrong one,
% and the welfare at stake big enough to matter but not the degenerate cliff
% one trap per age band, so the figure is not three copies of the oldest age
cand = find(npk>=2 & solv_loss>2e-4 & solv_loss<0.25);
pick = []; bands = {[69 74],[79 84],[89 94]};
for b = 1:numel(bands)
    ib = cand(age(cand)>=bands{b}(1) & age(cand)<=bands{b}(2));
    if isempty(ib), continue; end
    [~,o] = sort(solv_loss(ib),'descend');
    pick(end+1,1) = ib(o(1));                                              %#ok<AGROW>
end
tie  = find(rngp<1e-6); if isempty(tie), tie=find(rngp<1e-4); end
pick = [pick; tie(1)];
lab  = [repmat({'solver on the wrong peak'},1,numel(pick)-1), {'\pi worth nothing here'}];
fprintf('traps available: %d of %d node-ages\n', numel(cand), M);

mk={'o','s','^','d','v'};
mcol=[0.85 0.33 0.10; 0.55 0.40 0.10; 0.60 0.25 0.65; 0.95 0.62 0.20; 0.15 0.45 0.75];
f=figure('Position',[20 20 1560 780],'Color','w','Visible','off');
tl=tiledlayout(f,2,2,'Padding','compact','TileSpacing','compact');
for q=1:numel(pick)
    S=load([sd F(pick(q)).name]);
    tok=regexp(F(pick(q)).name,'scan_t(\d+)','tokens'); ag=24+str2double(tok{1}{1});
    pr=ceof(max(S.rhs,[],1)); vref=max([pr, ceof(S.land(isfinite(S.land(:,3)),3)).']); y=100*(pr/vref-1);
    ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    rg=max(y)-min(y(isfinite(y)));
    area(ax,S.pi,y,'FaceColor',[.20 .35 .75],'FaceAlpha',.10,'LineStyle','none', ...
        'BaseValue',min(y(isfinite(y)))-0.1*max(rg,1e-9));
    plot(ax,S.pi,y,'Color',[.1 .1 .1],'LineWidth',2.2);
    xline(ax,S.seed(2),'-','Color',[.45 .45 .45],'LineWidth',2.4);
    [~,jg]=max(y); plot(ax,S.pi(jg),y(jg),'p','MarkerSize',20, ...
        'MarkerFaceColor',[.98 .80 .15],'MarkerEdgeColor','k','LineWidth',.8);
    % Each method is drawn at the value it actually attains, at its own c, not
    % at the envelope. The envelope is the best c at that pi, so a method that
    % ends with a worse c sits below the curve. Plotting them on the curve made
    % it look as though solvers had moved downhill, which they do not.
    [~,ics]=min(abs(S.c-S.seed(1))); [~,ips]=min(abs(S.pi-S.seed(2)));
    ys = 100*(ceof(S.rhs(ics,ips))/vref-1);
    plot(ax,S.seed(2),ys,'o','MarkerSize',11,'MarkerFaceColor',[.93 .93 .93], ...
        'MarkerEdgeColor',[.2 .2 .2],'LineWidth',1.2);
    for m=1:size(S.land,1)
        if isfinite(S.land(m,2))
            ya = 100*(ceof(S.land(m,3))/vref-1);
            plot(ax,[S.seed(2) S.land(m,2)],[ys ya],'-','Color',[mcol(m,:) 0.35],'LineWidth',1);
            plot(ax,S.land(m,2),ya,mk{m},'MarkerSize',10, ...
                'MarkerFaceColor',mcol(m,:),'MarkerEdgeColor','k','LineWidth',.8);
        end
    end
    xlim(ax,[0 1]);
    if rg<1e-9, ylim(ax,[-1 0.15]); else, ylim(ax,[min(y(isfinite(y)))-0.12*rg, 0.12*rg]); end
    xlabel(ax,'equity share \pi  (fraction of liquid savings held in equity)');
    ylabel(ax,{'% certainty equivalent below','the best \pi  (0 = optimal)'});
    [~,jstar]=max(y); [~,jseed]=min(abs(S.pi-S.seed(2)));
    title(ax,{sprintf('age %d  --  %s', ag, lab{q}), ...
              sprintf('best \\pi = %.2f, warm start at \\pi = %.2f, costing %.2g%% CE', ...
                      S.pi(jstar), S.seed(2), abs(y(jseed)))}, ...
          'FontWeight','normal');
    if q==1
        lgl = [{'','best attainable at each \pi (c optimised)','seed \pi','global optimum','value at the seed''s own c'}];
        for m=1:numel(S.methods), lgl=[lgl {''} S.methods(m)]; end       %#ok<AGROW>
        lg = legend(ax, lgl, 'Box','off','FontSize',8.5,'NumColumns',4);
        lg.Layout.Tile = 'south';
    end
end
sgtitle(f,['The problem in \pi. The curve is the best value attainable at each \pi once c is optimised; each solver is drawn at the value it actually reaches, with its own c, so markers sit on or below the curve and every method improves on its seed. ' ...
  'The curve has separated peaks with a cliff between them, and the methods settle on a joint (c,\pi) optimum well below the best one. Bottom right: a node where \pi is worth nothing.'], ...
  'FontWeight','normal','FontSize',10.5,'Interpreter','tex');
exportgraphics(f,[outdir 'S3_objective_landscape.png'],'Resolution',140); close(f);

fprintf('\nprofile statistics over %d node-ages\n', M);
fprintf('  multi-peaked in pi          : %5.1f%%\n', 100*mean(npk>=2));
fprintf('  solver loses >0.1%% CE in pi : %5.1f%%\n', 100*mean(solv_loss>1e-3));
fprintf('  solver loses >1%% CE in pi   : %5.1f%%\n', 100*mean(solv_loss>1e-2));
fprintf('  pi worth <0.01%% CE (a tie)  : %5.1f%%\n', 100*mean(rngp<1e-4));
fprintf('  multi-peaked among losers   : %5.1f%%   among the rest: %5.1f%%\n', ...
    100*mean(npk(solv_loss>1e-3)>=2), 100*mean(npk(solv_loss<=1e-3)>=2));
save([sp 'profile_stats.mat'],'npk','rngp','solv_loss','age');
end

% ------------------------------------------------------------------------
function n = count_peaks(v, tol)
%COUNT_PEAKS  Local maxima separated from the neighbouring trough by more than
%   tol, so numerical wobble is not counted as structure.
v = v(isfinite(v)); n = 0;
if numel(v) < 3, return; end
for i = 2:numel(v)-1
    if v(i) >= v(i-1) && v(i) >= v(i+1)
        l = min(v(1:i-1)); r = min(v(i+1:end));
        if (v(i)-max(l,r)) > tol, n = n + 1; end
    end
end
if v(1)   - min(v) > tol && v(1)   > v(2),       n = n + 1; end
if v(end) - min(v) > tol && v(end) > v(end-1),   n = n + 1; end
end
