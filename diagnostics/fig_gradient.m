function fig_gradient(sp, outdir)
%FIG_GRADIENT  Why the surface defeats a gradient method.
%
%   The earlier heat map plotted the raw Bellman objective, which the
%   consumption dimension dominates by orders of magnitude, so the whole panel
%   saturated. Everything here is percent of certainty equivalent below the best
%   point at the node, clipped, which puts the structure on a readable scale.
%
%   Three views of the same node:
%     1  the surface over (c, pi) in 3D, so the ridge and the step between the
%        two plateaus are visible as relief rather than as colour
%     2  the profile in pi with its slope underneath: fmincon reads that slope
%        through finite differences, and where it is flat there is nothing to
%        follow and no way to tell which side of the step is higher
%     3  the basins, found by running a local ascent from every starting pi and
%        recording where it stops. The colour blocks are the basins; a solver
%        started anywhere in a block ends at that block's peak, so the seed
%        alone decides the answer.

if nargin<1||isempty(sp)
    sp='C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
end
if nargin<2||isempty(outdir)
    outdir='C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc/diagnostics/factorial_figs/';
end
g=5; ceof=@(v) ((1-g)*v).^(1/(1-g));
sd=[sp 'scans/']; F=dir([sd 'scan_*.mat']); M=numel(F);

% The profile carries upward ripple of about 3e-6 of its own range while the
% real steps are around 3e-3 and the cliffs up to 0.6 -- three orders of
% magnitude of clear separation, so this threshold is not a judgement call.
RIPPLE = 1e-4;

% Pick nodes with genuine multi-basin structure in pi and a seed that starts in
% the wrong basin. Ranking by the seed's shortfall alone picks up nodes whose
% loss is in c, where the pi profile has a single basin and there is nothing to
% illustrate.
nb=zeros(M,1); wrong=false(M,1); loss=zeros(M,1); age=zeros(M,1);
for i=1:M
    S=load([sd F(i).name]);
    pr=ceof(max(S.rhs,[],1));
    [e,~]=basins(pr, RIPPLE);
    ub=unique(e); nb(i)=numel(ub);
    [~,ips]=min(abs(S.pi-S.seed(2)));
    [~,jb]=max(pr);
    wrong(i)=e(ips)~=jb;
    loss(i)=(max(pr)-pr(e(ips)))/max(pr);
    tok=regexp(F(i).name,'scan_t(\d+)','tokens'); age(i)=24+str2double(tok{1}{1});
end
cand=find(nb>=2 & wrong & loss>1e-3);
[~,o]=sort(loss(cand),'descend'); cand=cand(o);
fprintf('nodes with >1 basin in pi: %.1f%%; seed in the wrong one: %.1f%%\n', ...
    100*mean(nb>=2), 100*mean(nb>=2 & wrong));
pick=cand(1); other=cand(age(cand)~=age(cand(1)));
if ~isempty(other), pick=[pick; other(1)]; else, pick=[pick; cand(2)]; end

CLIP=-12;                                   % ignore the ruin cliff below this
f=figure('Position',[20 20 1680 900],'Color','w','Visible','off');
tl=tiledlayout(f,2,3,'Padding','compact','TileSpacing','compact');
for q=1:numel(pick)
    S=load([sd F(pick(q)).name]);
    tok=regexp(F(pick(q)).name,'scan_t(\d+)','tokens'); ag=24+str2double(tok{1}{1});
    CE=ceof(S.rhs); vref=max(CE(:));
    Z=100*(CE/vref-1); Z(~isfinite(Z))=CLIP; Zc=max(Z,CLIP);
    [~,ics]=min(abs(S.c-S.seed(1))); [~,ips]=min(abs(S.pi-S.seed(2)));

    % ---- 1: the surface in 3D
    ax=nexttile(tl); hold(ax,'on');
    surf(ax,S.pi,S.c,Zc,'EdgeColor','none','FaceColor','interp');
    colormap(ax,parula); clim(ax,[CLIP 0]);
    cb=colorbar(ax); cb.Label.String='% CE below best';
    plot3(ax,S.seed(2),S.seed(1),max(Zc(ics,ips),CLIP)+0.4,'o','MarkerSize',10, ...
        'MarkerFaceColor',[1 1 1],'MarkerEdgeColor','k','LineWidth',1.2);
    [~,im]=max(Zc(:)); [ig,jg]=ind2sub(size(Zc),im);
    plot3(ax,S.pi(jg),S.c(ig),Zc(ig,jg)+0.4,'p','MarkerSize',17, ...
        'MarkerFaceColor',[.98 .80 .15],'MarkerEdgeColor','k','LineWidth',1);
    view(ax,-38,42); grid(ax,'on');
    xlabel(ax,'equity share \pi'); ylabel(ax,'consumption share c');
    zlabel(ax,'% CE below best'); zlim(ax,[CLIP 1]);
    title(ax,sprintf('age %d -- the surface, clipped at %d%%',ag,CLIP),'FontWeight','normal');

    % ---- 2: the profile and the slope a gradient method reads
    pr=100*(ceof(max(S.rhs,[],1))/vref-1);
    dpi=gradient(pr(:).', S.pi(:).');
    % The interpolant is piecewise linear, so the profile is a staircase and the
    % raw derivative is a train of spikes at the treads' edges. Plot it on a
    % signed log scale so both the spikes and the flat treads stay legible.
    slog = sign(dpi).*log10(1+abs(dpi));
    lo_pr = max(min(pr),CLIP);
    ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    % plateaus: consecutive points whose value differs by less than a hundredth
    % of a percent. Inside one, a finite difference returns nothing usable.
    flat = [abs(diff(pr))<1e-2, false];
    yl=[lo_pr-0.5 0.5];
    fs=find(flat);
    for b=1:numel(fs)
        patch(ax,[S.pi(fs(b)) S.pi(min(fs(b)+1,end)) S.pi(min(fs(b)+1,end)) S.pi(fs(b))], ...
              [yl(1) yl(1) yl(2) yl(2)],[.85 .55 .20],'FaceAlpha',.16,'EdgeColor','none');
    end
    yyaxis(ax,'left');
    plot(ax,S.pi,pr,'Color',[.1 .1 .1],'LineWidth',2.2);
    ylabel(ax,'% CE below best'); ax.YColor=[.1 .1 .1]; ylim(ax,yl);
    yyaxis(ax,'right');
    plot(ax,S.pi,slog,'Color',[.20 .45 .75],'LineWidth',1.4,'LineStyle','-');
    yline(ax,0,'-','Color',[.5 .5 .5]);
    ylabel(ax,'slope, signed log_{10}'); ax.YColor=[.20 .45 .75];
    xline(ax,S.seed(2),'-','Color',[.45 .45 .45],'LineWidth',2);
    xlabel(ax,'equity share \pi');
    title(ax,sprintf('objective is flat on %.0f%% of \\pi; elsewhere the slope is a step',100*mean(flat)), ...
        'FontWeight','normal');
    if q==1, legend(ax,{'objective','slope (signed log)'}, ...
            'Box','off','Location','southeast','FontSize',7.5); end

    % ---- 3: the basins
    prv=ceof(max(S.rhs,[],1));
    [endi, nrip]=basins(prv, RIPPLE);
    ub=unique(endi); bid=arrayfun(@(e) find(ub==e,1), endi);
    ax=nexttile(tl); hold(ax,'on');
    imagesc(ax,S.pi,[0 1],repmat(bid,2,1)); axis(ax,'xy');
    colormap(ax,lines(max(numel(ub),2))); clim(ax,[0.5 numel(ub)+0.5]);
    for e=ub
        plot(ax,S.pi(e),0.5,'p','MarkerSize',15,'MarkerFaceColor',[.98 .80 .15], ...
            'MarkerEdgeColor','k','LineWidth',.8);
    end
    xline(ax,S.seed(2),'-','Color',[.1 .1 .1],'LineWidth',2.6);
    xlim(ax,[0 1]); ylim(ax,[0 1]); set(ax,'YTick',[]);
    xlabel(ax,'starting \pi');

    title(ax,sprintf('%d basins in \\pi; the seed lands in the one it starts in',numel(ub)), ...
        'FontWeight','normal');
    if q==1
        text(ax,0.02,0.86,'stars = where each basin ends','FontSize',7.5,'Color',[.15 .15 .15]);
        text(ax,0.02,0.70,sprintf('%d ripples below %g of the range filtered out',nrip,RIPPLE), ...
            'FontSize',7.5,'Color',[.15 .15 .15]);
    end
end
sgtitle(f,['What a gradient method is up against. Colour and height are percent of certainty equivalent below the best point at that node, clipped, so the shape is visible instead of the scale. ' ...
  'The middle column shows the slope fmincon estimates; the right column shows that the answer is decided by which basin the seed falls in.'], ...
  'FontWeight','normal','FontSize',10.5,'Interpreter','tex');
exportgraphics(f,[outdir 'S6_gradient_and_basins.png'],'Resolution',140); close(f);
fprintf('S6 written\n');
end

% ------------------------------------------------------------------------
function [endi, nrip] = basins(prv, ripple)
%BASINS  Where a local ascent stops, from every starting point.
%
%   Walks across flat treads rather than stopping on them, and ignores upward
%   wobbles smaller than `ripple` times the profile's range. In this model the
%   ripple sits around 3e-6 of the range and the real steps around 3e-3, so the
%   two do not overlap and the threshold only has to fall between them.
prv = prv(:).'; n = numel(prv);
fin = prv(isfinite(prv));
tol = ripple * (max(fin) - min(fin));
endi = zeros(1, n);
for j = 1:n
    k = j;
    for step = 1:2*n
        kl = k; while kl > 1 && abs(prv(kl-1) - prv(k)) <= tol, kl = kl - 1; end
        kr = k; while kr < n && abs(prv(kr+1) - prv(k)) <= tol, kr = kr + 1; end
        up_r = kr < n && prv(kr+1) > prv(k) + tol;
        up_l = kl > 1 && prv(kl-1) > prv(k) + tol;
        if up_r && (~up_l || prv(kr+1) >= prv(kl-1)), k = kr + 1;
        elseif up_l, k = kl - 1;
        else, break; end
    end
    endi(j) = k;
end
d = diff(prv);
nrip = sum(d > 0 & d <= tol);
end
