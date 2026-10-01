% Where does the kappa scheme move the portfolio rule, and why?
%
% One value function, two interpolants, one backward step. That isolates the
% interpolant from everything else: same V_next, same quadrature, same budget,
% same optimiser. Then bin the resulting pi by distance from the ruin surface.
%
%   If the pi difference is concentrated near m = 0, kappa's effect is
%   cliff-local and the known-answer test needs re-reading.
%   If it is flat in m, kappa changes the objective everywhere, and the
%   candidate reason is that z-mode is multilinear inside a cell while
%   kappa-mode returns a product of two multilinear functions.
%
% The second half measures that directly: local relative risk aversion of the
% reconstructed continuation along liquid wealth, which is what sets pi.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
o = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';
L = load([o 'ab_profiles.mat']);          % S(1) = z-solved, S(2) = kappa-solved
p0 = L.S(1).p;  Vall = L.S(1).V;          % common input: the z-solved V
t  = 20;  Vn = Vall(:,:,:,t+1);
[~, mg, sl] = config.income_profile(p0);
prof.mu_growth = mg; prof.sigma_l_log = sl; prof.p_surv = config.survival(p0);
shk = grids.shock_grid(p0); ann = pension.annuity_price(p0, prof, shk);

q = p0; q.interp_object = 'z';     [Vz, cz, piz] = solver.bellman_step_lna(t, Vn, q, prof, shk, ann);
r = p0; r.interp_object = 'kappa'; [Vk, ck, pik] = solver.bellman_step_lna(t, Vn, r, prof, shk, ann);

% liquid resources at each node of THIS period
net = 1-p0.tau_inc; kap = p0.kappa(min(t,numel(p0.kappa)));
cf  = (1-p0.delta)*(1-kap)*net;  hc = p0.alpha;
[U1,U2,U3] = ndgrid(p0.u1_grid, p0.u2_grid, p0.u3_grid);
M = (1-U1).*(1-U2) + cf*U1 - hc*(U2.*(1-U1).*(1-U3));
ok = M(:) > 0;
dpi = abs(pik(:)-piz(:)); dc = abs(ck(:)-cz(:))./max(cz(:),eps);

fprintf('One backward step at t=%d from a common V_next, %d nodes\n\n', t, numel(M));
fprintf('%-22s %8s %10s %10s %10s\n','distance from ruin','nodes','mean |dpi|','p90 |dpi|','mean |dc|/c');
edges = [0 0.05 0.15 0.35 0.6 inf];
lab = {'m < 0.05 (at it)','0.05-0.15','0.15-0.35','0.35-0.60','m > 0.60 (far)'};
for b = 1:5
    s = ok & M(:) >= edges(b) & M(:) < edges(b+1);
    fprintf('%-22s %8d %10.4f %10.4f %9.2f%%\n', lab{b}, sum(s), ...
        mean(dpi(s)), prctile(dpi(s),90), 100*mean(dc(s)));
end

% ---- local relative risk aversion of the reconstructed continuation ----
% Hold A, H, Y fixed, vary liquid wealth X. RRA = -X V''(X)/V'(X) is what sets
% the myopic equity share mu/(sigma^2 * RRA).
g = p0.gamma; omg = 1-g; inv_omg = 1/omg;
arg = omg*Vn; arg(arg<=0) = NaN; zN = arg.^inv_omg;
zN(isnan(zN)) = min(zN(isfinite(zN)));
ppz = griddedInterpolant({p0.u1_grid,p0.u2_grid,p0.u3_grid}, zN, 'linear','nearest');
kap1 = p0.kappa(min(t+1,numel(p0.kappa))); cf1 = (1-p0.delta)*(1-kap1)*net;
m_of = @(a,b,c) (1-a).*(1-b) + cf1*a - hc*(b.*(1-a).*(1-c));
MN = m_of(U1,U2,U3); FN = max(p0.phi_floor*U1,1e-12);
live = MN > FN & isfinite(zN); KN = ones(size(zN)); KN(live) = zN(live)./MN(live);
khi = max(1,max(KN(live))); KN = min(max(KN,0),khi);
ppk = griddedInterpolant({p0.u1_grid,p0.u2_grid,p0.u3_grid}, KN, 'linear','nearest');

Y = 1; A = 0.6; H = 4;                      % typical mid-life household, in years of income
X = linspace(0.3, 3.0, 4001).';             % liquid wealth, years of income
W = X + A + H + Y;
u1 = Y./W; u2 = (A+H)./(X+A+H); u3 = A/(A+H)*ones(size(X));
zA = ppz(u1,u2,u3);
zB = max(min(max(ppk(u1,u2,u3),0),khi) .* max(m_of(u1,u2,u3),0), max(p0.phi_floor*u1,1e-12));
rra = @(z) local_rra(X, (W.*z).^omg/omg);
[rA, xm] = rra(zA); [rB, ~] = rra(zB);
mer = p0.mu_S_level/(p0.sigma_S_level^2);
fprintf('\nLocal RRA of the continuation along liquid wealth, mid-life state,\n');
fprintf('far from the ruin surface (m = %.2f to %.2f)\n', min(m_of(u1,u2,u3)), max(m_of(u1,u2,u3)));
fprintf('%-14s %10s %10s %14s\n','interpolant','median RRA','IQR','myopic pi');
fprintf('%-14s %10.2f %10.2f %14.2f\n','linear-z',  median(rA), iqr(rA), min(mer/median(rA),1));
fprintf('%-14s %10.2f %10.2f %14.2f\n','kappa',     median(rB), iqr(rB), min(mer/median(rB),1));
fprintf('\nmax |z_kappa - z_z| / z along this line: %.3f%%\n', 100*max(abs(zB-zA)./zA));

f = figure('Position',[100 100 1180 420],'Color','w');
tl = tiledlayout(f,1,2,'Padding','compact','TileSpacing','compact');
ax = nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
plot(ax, X, 100*(zB-zA)./zA, 'Color',[.16 .47 .84],'LineWidth',1.2);
u2n = p0.u2_grid(p0.u2_grid>min(u2) & p0.u2_grid<max(u2));
for k=1:numel(u2n), xline(ax, (A+H)*(1-u2n(k))/u2n(k), ':', 'Color',[.6 .6 .6]); end
title(ax,'kappa minus linear-z, % of z  (dotted = grid nodes)','FontWeight','normal');
xlabel(ax,'liquid wealth, years of income'); ylabel(ax,'%');
ax = nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
plot(ax, xm, rA, 'Color',[.92 .41 .20],'LineWidth',1.2);
plot(ax, xm, rB, 'Color',[.16 .47 .84],'LineWidth',1.2);
yline(ax, g, '--','Color',[.3 .3 .3]);
ylim(ax,[0 3*g]); title(ax,'local relative risk aversion (dashed = gamma)','FontWeight','normal');
xlabel(ax,'liquid wealth, years of income'); legend(ax,{'linear-z','kappa'},'Box','off','Location','northeast');
sgtitle(f,'One V, two interpolants: where they differ and what it does to curvature','FontWeight','normal','FontSize',12);
exportgraphics(f,[o 'fig_curvature.png'],'Resolution',150);

function [r, xm] = local_rra(x, V)
    d1 = diff(V)./diff(x);  xm1 = (x(1:end-1)+x(2:end))/2;
    d2 = diff(d1)./diff(xm1); xm = xm1(1:end-1);
    r  = -xm .* d2 ./ d1(1:end-1);
    r(~isfinite(r)) = NaN;
end
