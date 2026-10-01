function objective_surface()
%OBJECTIVE_SURFACE  Plot the actual per-node Bellman objective RHS(c,pi) and the
%   value function, at fixed grid nodes, to SEE the flatness in pi. Reconstructs
%   the same RHS solver.bellman_step_lna maximises, and validates it against the
%   solver's stored V and policy at the node.
scratch = 'C:\Users\Quinn\AppData\Local\Temp\claude\C--Users-Quinn-Desktop-claudecodetest\09022b31-1999-4844-b935-dc5896ea19a1\scratchpad';
repo = 'C:\Users\Quinn\Desktop\claudecodetest\OwnersrentersDSRI-rentproc';
addpath(repo);
d = load(fullfile(scratch,'renter_snapshot.mat'));
p = d.p; sol = d.sol; sh = d.shocks; prof = d.profile; ann = d.ann_price;
gamma = p.gamma; omg = 1 - gamma;

% shocks / tax constants
R_S = sh.joint.R_S(:); R_H = sh.joint.R_H(:); R_RE = sh.joint.R_REIT(:);
epsY = sh.joint.eps_Y_unit(:); w = sh.joint.w(:);
tau_inc=p.tau_inc; net=1-tau_inc; tb=p.tau_cg_bond; ts=p.tau_cg_stock; tw=p.tau_wealth;
Rf_at=(1+p.r*(1-tb))*(1-tw); R_S_at=(R_S - ts.*max(R_S-1,0)).*(1-tw);
tauP = config.tau_effective(p); reP = config.reit_effective(p);

% choose a retiree node (u2 high = on the cliff) and a mid-life node
nodes = [3 9 5, 45;     % [i1 i2 i3, t]  retiree age 69, u2~0.89
         3 8 3, 20];    % accumulator age 44
labs = {'retiree age 69','accumulator age 44'};

fig = figure('Position',[30 30 1600 820],'Color','w');
tl = tiledlayout(fig,2,3,'Padding','compact','TileSpacing','compact');
title(tl,'Actual Bellman objective RHS(c,\pi) and value surface at fixed grid nodes','FontWeight','bold');

for r = 1:size(nodes,1)
    i1=nodes(r,1); i2=nodes(r,2); i3=nodes(r,3); t=nodes(r,4);
    u1=p.u1_grid(i1); u2=p.u2_grid(i2); u3=p.u3_grid(i3);
    lam=u1; sA=u2*(1-u1)*u3; sH=u2*(1-u1)*(1-u3); sX=1-lam-sA-sH;
    is_ret = t>=p.t_ret;
    kap = p.kappa(min(t,numel(p.kappa)));
    hcr = p.alpha;                      % renter
    ann_t = ann(t); pt=prof.p_surv(t); beta_eff=p.beta*pt;
    if is_ret
        cf=(1-p.delta)*net; LW=sX+cf*lam+net*sA/ann_t-hcr*sH; Apre=sA*(1-1/ann_t);
    else
        cf=(1-p.delta)*(1-kap)*net; LW=sX+cf*lam-hcr*sH; Apre=sA+kap*lam;
    end
    G=exp(prof.mu_growth(t)+prof.sigma_l_log(t).*epsY);
    Ynext=G*lam; Hnext=sH*R_H;
    R_A=((1-tauP(t)-reP(t))*p.Rf + tauP(t).*R_S + reP(t).*R_RE)/pt; Anext=R_A*Apre;

    % z-transform of continuation
    Vn=sol.V(:,:,:,t+1); arg=omg*Vn; arg(arg<=0)=NaN; z=arg.^(1/omg);
    z(isnan(z))=min(z(isfinite(z))); ppz=griddedInterpolant({p.u1_grid,p.u2_grid,p.u3_grid},z,'linear','nearest');

    cg=linspace(max(1e-3,0.01/max(LW,1e-6)),1-1e-6,120); pg=linspace(0,1,120);
    RHS=nan(numel(cg),numel(pg));
    for a=1:numel(cg)
        for b=1:numel(pg)
            RX=(1-pg(b))*Rf_at+pg(b).*R_S_at; Xn=RX*((1-cg(a))*LW);
            denAH=Anext+Hnext; Wg=Xn+denAH+Ynext;
            u1n=max(min(Ynext./Wg,1),0); u2n=max(min(denAH./max(Xn+denAH,1e-12),1),0); u3n=max(min(Anext./max(denAH,1e-12),1),0);
            zn=ppz(u1n,u2n,u3n); Vv=(Wg.*zn).^omg/omg;
            RHS(a,b)=(cg(a)*LW)^omg/omg + beta_eff*sum(w.*Vv);
        end
    end
    [Vmax,li]=max(RHS(:)); [ia,ib]=ind2sub(size(RHS),li);
    fprintf('%-18s node(%d,%d,%d) t=%d: reconstructed max=%.4g at c=%.3f pi=%.3f | solver V=%.4g c*=%.3f pi*=%.3f\n', ...
        labs{r}, i1,i2,i3,t, Vmax, cg(ia), pg(ib), sol.V(i1,i2,i3,t), sol.c_pol(i1,i2,i3,t), sol.pi_pol(i1,i2,i3,t));

    % (col1) heatmap RHS(c,pi)
    nexttile((r-1)*3+1); imagesc(pg,cg,RHS); set(gca,'YDir','normal'); colorbar; hold on;
    plot(pg(ib),cg(ia),'w+','MarkerSize',10,'LineWidth',1.5);
    xlabel('\pi'); ylabel('c'); title(sprintf('%s: RHS(c,\\pi)',labs{r}));

    % (col2) RHS vs pi at optimal c, as % CE loss
    slice=RHS(ia,:); CE=((omg*slice).^(1/omg)); CEloss=100*(1-CE/max(CE));
    nexttile((r-1)*3+2); plot(pg,CEloss,'-','LineWidth',1.8); grid on;
    xlabel('\pi'); ylabel('CE loss vs best (%)'); title(sprintf('%s: cost of moving \\pi (c=c*)',labs{r}));
    yl=ylim; text(0.05,0.9*yl(2)+0.1*yl(1),sprintf('flat band <0.1%%: \\pi\\in[%.2f,%.2f]', ...
        pg(find(CEloss<0.1,1,'first')), pg(find(CEloss<0.1,1,'last'))),'FontSize',8);

    % (col3) value function vs u2 at this (u1,u3), several ages (the cliff)
    nexttile((r-1)*3+3); hold on; grid on;
    for tt=[t t+8 t+16]
        if tt<=p.T, plot(p.u2_grid, squeeze(sol.V(i1,:,i3,tt)),'-o','MarkerSize',3,'DisplayName',sprintf('age %d',p.age0+tt-1)); end
    end
    xlabel('u2 (illiquid share)'); ylabel('V'); title(sprintf('%s: value vs u2',labs{r})); legend('Location','best','FontSize',7);
end
exportgraphics(fig, fullfile(scratch,'fig_objective_surface.png'),'Resolution',130);
fprintf('wrote fig_objective_surface.png\n');
end
