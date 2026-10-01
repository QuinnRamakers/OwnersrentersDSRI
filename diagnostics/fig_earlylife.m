function fig_earlylife(sp, outdir)
%FIG_EARLYLIFE  The same search problem in the accumulation phase.
%
%   Early life is where the shortfall is expensive: the production solve gives
%   up a median 1.8% of certainty equivalent at age 25 against 0.02% at 69. This
%   plots, for each early age, the profile in pi after consumption is optimised
%   out, where every method stops, and the refinement's own trajectory, so the
%   mechanism can be compared with the retirement figures.
%
%   Reads scans_full, which covers ages 25 to 94.

if nargin<1||isempty(sp)
    sp='C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
end
if nargin<2||isempty(outdir)
    outdir='C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc/diagnostics/factorial_figs/';
end
g=5; ceof=@(v) ((1-g)*v).^(1/(1-g));
sd=[sp 'scans_full/']; F=dir([sd 'scan_*.mat']); M=numel(F);
if M==0, fprintf('no scans_full yet\n'); return; end
RIPPLE=1e-4;

nb=zeros(M,1); wrong=false(M,1); loss=zeros(M,1); age=zeros(M,1); gain=zeros(M,1);
for i=1:M
    S=load([sd F(i).name]);
    pr=ceof(max(S.rhs,[],1)); pm=max(pr);
    e=local_basins(pr,RIPPLE); nb(i)=numel(unique(e));
    [~,ips]=min(abs(S.pi-S.seed(2))); [~,ics]=min(abs(S.c-S.seed(1)));
    [~,jb]=max(pr);
    wrong(i)=e(ips)~=jb;
    sv=ceof(S.rhs(ics,ips));
    loss(i)=(pm-sv)/pm;
    if isfield(S,'refine'), gain(i)=(ceof(S.refine(4).best(3))-sv)/pm; end
    tok=regexp(F(i).name,'scan_t(\d+)','tokens'); age(i)=24+str2double(tok{1}{1});
end
early = age<=54;
fprintf('EARLY LIFE (ages 25-54), %d node-ages\n', nnz(early));
fprintf('  more than one basin in pi : %5.1f%%   (retirement: %5.1f%%)\n', ...
    100*mean(nb(early)>=2), 100*mean(nb(~early)>=2));
fprintf('  seed in the wrong basin   : %5.1f%%   (retirement: %5.1f%%)\n', ...
    100*mean(nb(early)>=2 & wrong(early)), 100*mean(nb(~early)>=2 & wrong(~early)));
fprintf('  seed more than 1%% CE down : %5.1f%%   (retirement: %5.1f%%)\n', ...
    100*mean(loss(early)>0.01), 100*mean(loss(~early)>0.01));
fprintf('\n%-5s %8s %10s %12s %12s\n','age','basins','wrong seed','seed loss med','refine gain med');
for a=sort(unique(age)).'
    k=age==a;
    fprintf('%-5d %7.1f%% %9.1f%% %11.3f%% %11.3f%%\n', a, 100*mean(nb(k)>=2), ...
        100*mean(nb(k)>=2 & wrong(k)), 100*median(loss(k)), 100*median(gain(k)));
end

% one node per early age, hardest first
ages=sort(unique(age(early))).'; pick=[]; ag=[];
for a=ages
    ib=find(age==a & nb>=2 & wrong & loss>1e-3);
    if isempty(ib), ib=find(age==a & loss>1e-3); end
    if isempty(ib), continue; end
    [~,o]=sort(loss(ib),'descend');
    pick(end+1,1)=ib(o(1)); ag(end+1,1)=a;                                %#ok<AGROW>
end
if isempty(pick), fprintf('no early-life traps found\n'); return; end

mk={'o','s','^','d','v'};
mcol=[0.85 0.33 0.10; 0.55 0.40 0.10; 0.60 0.25 0.65; 0.95 0.62 0.20; 0.15 0.45 0.75];
n=numel(pick);
f=figure('Position',[10 10 1640 420*n],'Color','w','Visible','off');
tl=tiledlayout(f,n,2,'Padding','compact','TileSpacing','compact');
for q=1:n
    S=load([sd F(pick(q)).name]);
    pr=ceof(max(S.rhs,[],1)); vref=max([pr, ceof(S.land(isfinite(S.land(:,3)),3)).']);
    if isfield(S,'refine'), vref=max([vref, arrayfun(@(r) ceof(S.refine(r).best(3)),1:4)]); end
    y=100*(pr/vref-1);
    [~,ics]=min(abs(S.c-S.seed(1))); [~,ips]=min(abs(S.pi-S.seed(2)));
    ys=100*(ceof(S.rhs(ics,ips))/vref-1);

    % --- left: the profile, the seed, and where each method stops
    ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    plot(ax,S.pi,y,'Color',[.1 .1 .1],'LineWidth',2.2);
    xline(ax,S.seed(2),'-','Color',[.45 .45 .45],'LineWidth',2.2);
    [~,jg]=max(y);
    plot(ax,S.pi(jg),y(jg),'p','MarkerSize',18,'MarkerFaceColor',[.98 .80 .15], ...
        'MarkerEdgeColor','k','LineWidth',.9);
    plot(ax,S.seed(2),ys,'o','MarkerSize',11,'MarkerFaceColor',[.93 .93 .93], ...
        'MarkerEdgeColor',[.2 .2 .2],'LineWidth',1.2);
    for m=1:size(S.land,1)
        if isfinite(S.land(m,1))
            ya=100*(ceof(S.land(m,3))/vref-1);
            plot(ax,S.land(m,2),ya,mk{m},'MarkerSize',9,'MarkerFaceColor',mcol(m,:), ...
                'MarkerEdgeColor','k','LineWidth',.7);
        end
    end
    lo=min([y(:); ys]); rg=max(-lo,1e-9);
    ylim(ax,[lo-0.1*rg, 0.1*rg]); xlim(ax,[0 1]);
    ylabel(ax,{'% CE below','the best \pi'});
    if q==n, xlabel(ax,'equity share \pi'); end
    title(ax,sprintf('age %d -- %d basins; seed at \\pi=%.2f costs %.2g%% CE', ...
        ag(q), nb(pick(q)), S.seed(2), abs(ys)),'FontWeight','normal');
    if q==1
        legend(ax,[{'objective (c optimised out)','seed \pi','global optimum','value at the seed'}, S.methods], ...
            'Box','off','Location','southoutside','NumColumns',3,'FontSize',7.5);
    end

    % --- right: what the refinement does from that same seed
    ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    if isfield(S,'refine')
        vals=[ceof(S.rhs(ics,ips)), arrayfun(@(r) ceof(S.refine(r).best(3)),1:4)];
        vy=100*(vals/vref-1);
        b=bar(ax,0:4,vy,0.6,'FaceColor','flat','EdgeColor',[.3 .3 .3]);
        cr=[0.6 0.6 0.6; 0.85 0.33 0.10; 0.20 0.45 0.75; 0.30 0.65 0.45; 0.55 0.25 0.65];
        for r=1:5, b.CData(r,:)=cr(r,:); end
        yline(ax,0,'-','Color',[.2 .2 .2],'LineWidth',1.2);
        set(ax,'XTick',0:4,'XTickLabel',{'seed','round 1','round 2','round 3','round 4'});
        ylabel(ax,{'% CE below','the best found'});
        title(ax,sprintf('round 1 closes %.2g of the %.2g pp gap; rounds 2-4 add %.2g', ...
            abs(vy(1))-abs(vy(2)), abs(vy(1)), abs(vy(2))-abs(vy(5))),'FontWeight','normal');
        text(ax,0.5,vy(2),sprintf('  \\pi: %.2f \\rightarrow %.2f', S.seed(2), S.refine(1).best(2)), ...
            'FontSize',8,'VerticalAlignment','bottom');
    end
end
sgtitle(f,['The accumulation phase. Left: the objective in \pi after optimising consumption out, with the warm start and where each method stops. ' ...
  'Right: the refinement''s own trajectory from the same seed -- round 1 is the global sweep, rounds 2 to 4 only polish.'], ...
  'FontWeight','normal','FontSize',11,'Interpreter','tex');
exportgraphics(f,[outdir 'S8_early_life_search.png'],'Resolution',130); close(f);
fprintf('\nS8 written: %d early ages\n', n);
end

% ------------------------------------------------------------------------
function endi = local_basins(prv, ripple)
prv=prv(:).'; n=numel(prv); fin=prv(isfinite(prv));
tol=ripple*(max(fin)-min(fin)); endi=zeros(1,n);
for j=1:n
    k=j;
    for step=1:2*n
        kl=k; while kl>1 && abs(prv(kl-1)-prv(k))<=tol, kl=kl-1; end
        kr=k; while kr<n && abs(prv(kr+1)-prv(k))<=tol, kr=kr+1; end
        up_r = kr<n && prv(kr+1)>prv(k)+tol;
        up_l = kl>1 && prv(kl-1)>prv(k)+tol;
        if up_r && (~up_l || prv(kr+1)>=prv(kl-1)), k=kr+1;
        elseif up_l, k=kl-1;
        else, break; end
    end
    endi(j)=k;
end
end
