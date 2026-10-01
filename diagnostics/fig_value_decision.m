function fig_value_decision(sp, out_dir)
%FIG_VALUE_DECISION  The value map over the decision variables, not the states.
%
%   S22 plots the solved value function over the state grid (u1, u2): smooth,
%   near-planar, well behaved. This plots the object the solver actually has to
%   maximise at a node -- the Bellman right hand side as a function of the two
%   decisions (c, pi) -- as relief, in absolute certainty-equivalent units
%
%       z(c, pi) = ((1-gamma) RHS(c, pi))^(1/(1-gamma))
%
%   so the height is the household's lifetime certainty equivalent per unit of
%   wealth under that pair of choices. Zero means ruin.
%
%   One panel per age, each at the node closest to where households of that age
%   actually sit, so the surfaces shown are the ones the solver meets in the
%   occupied region rather than in an empty corner.

if nargin<1||isempty(sp)
    sp='C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
end
if nargin<2||isempty(out_dir)
    out_dir='C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc/diagnostics';
end
fd=fullfile(out_dir,'factorial_figs');
sd=[sp 'scans_full/']; F=dir([sd 'scan_*.mat']);
if isempty(F), fprintf('no scans_full\n'); return; end
M=load([sp 'landscape_meta.mat'],'N','p'); N=M.N; pg=M.p;
g=5; ceof=@(v) ((1-g)*v).^(1/(1-g));

% occupancy median per age, to pick a representative node
Q=load(fullfile(out_dir,'occupancy_src.mat')); s=Q.s;
lam=s.lambda; sA=s.sA; sH=s.sH;

age=zeros(numel(F),1); kk=zeros(numel(F),1);
for i=1:numel(F)
    tok=regexp(F(i).name,'scan_t(\d+)_k(\d+)','tokens'); tok=tok{1};
    age(i)=24+str2double(tok{1}); kk(i)=str2double(tok{2});
end
ages=sort(unique(age)).';

pick=[]; agp=[];
for a=ages
    t=a-24; tt=min(t,size(lam,2));
    m1=median(lam(:,tt),'omitnan');
    u2v=(sA(:,tt)+sH(:,tt))./max(1-lam(:,tt),1e-12);
    m2=median(u2v,'omitnan');
    u3v=sA(:,tt)./max(sA(:,tt)+sH(:,tt),1e-12);
    m3=median(u3v,'omitnan');
    [~,i1]=min(abs(pg.u1_grid-m1)); [~,i2]=min(abs(pg.u2_grid-m2)); [~,i3]=min(abs(pg.u3_grid-m3));
    ktgt=sub2ind(N,i1,i2,i3);
    j=find(age==a & kk==ktgt,1);
    if isempty(j)                      % that node was not scanned; take the nearest that was
        cand=find(age==a);
        [~,q]=min(abs(kk(cand)-ktgt)); j=cand(q);
    end
    pick(end+1,1)=j; agp(end+1,1)=a;                                       %#ok<AGROW>
end

n=numel(pick); nc=4; nr=ceil(n/nc);
f=figure('Position',[10 10 470*nc 420*nr],'Color','w','Visible','off');
tl=tiledlayout(f,nr,nc,'Padding','compact','TileSpacing','compact');
for q=1:n
    S=load([sd F(pick(q)).name]);
    Z=ceof(S.rhs); Z(~isfinite(Z))=0; Z=max(Z,0);
    ax=nexttile(tl); hold(ax,'on');
    surf(ax,S.pi,S.c,Z,'EdgeColor','none','FaceColor','interp');
    colormap(ax,parula); zmax=max(Z(:));
    clim(ax,[0 zmax]);
    if mod(q,nc)==0 || q==n, cb=colorbar(ax); cb.Label.String='z  (CE per unit wealth)'; end
    [~,im]=max(Z(:)); [ig,jg]=ind2sub(size(Z),im);
    plot3(ax,S.pi(jg),S.c(ig),Z(ig,jg)+0.02*zmax,'p','MarkerSize',16, ...
        'MarkerFaceColor',[.98 .80 .15],'MarkerEdgeColor','k','LineWidth',.9);
    [~,ics]=min(abs(S.c-S.seed(1))); [~,ips]=min(abs(S.pi-S.seed(2)));
    plot3(ax,S.seed(2),S.seed(1),Z(ics,ips)+0.02*zmax,'o','MarkerSize',9, ...
        'MarkerFaceColor',[1 1 1],'MarkerEdgeColor','k','LineWidth',1.1);
    view(ax,-40,36); grid(ax,'on');
    xlabel(ax,'\pi  (equity share)'); ylabel(ax,'c  (consumption share)');
    zlabel(ax,'z'); zlim(ax,[0 zmax*1.06]);
    frac0=100*mean(Z(:)<=0.02*zmax);
    title(ax,{sprintf('age %d',agp(q)), ...
              sprintf('best z = %.3f at c=%.2f, \\pi=%.2f;  %.0f%% of the square is ruin', ...
                      zmax, S.c(ig), S.pi(jg), frac0)},'FontWeight','normal','FontSize',9);
end
sgtitle(f,['The objective over the two DECISIONS, at the node where households of that age actually sit. ' ...
  'Height is the lifetime certainty equivalent per unit of wealth under that (c, \pi); zero is ruin. ' ...
  'Star = best pair, circle = the warm start the solver is given.'], ...
  'FontWeight','normal','FontSize',11,'Interpreter','tex');
exportgraphics(f,fullfile(fd,'S24_value_over_decisions.png'),'Resolution',115); close(f);
fprintf('S24 written (%d ages)\n', n);

fprintf('\n%-6s %10s %8s %8s %10s %10s %10s\n','age','best z','c*','pi*','seed c','seed pi','ruin %%');
for q=1:n
    S=load([sd F(pick(q)).name]);
    Z=ceof(S.rhs); Z(~isfinite(Z))=0; Z=max(Z,0);
    [~,im]=max(Z(:)); [ig,jg]=ind2sub(size(Z),im); zmax=Z(ig,jg);
    fprintf('%-6d %10.4f %8.3f %8.3f %10.3f %10.3f %9.0f%%\n', agp(q), zmax, ...
        S.c(ig), S.pi(jg), S.seed(1), S.seed(2), 100*mean(Z(:)<=0.02*zmax));
end
end
