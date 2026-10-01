% Dump the curve behind the interpolation comparison, for plotting.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
p = config.params(); p.is_owner = false;
p = utility.build_state_grids(p, [16 12 10], []);
u2g = p.u2_grid(:); g = p.gamma; omg = 1-g;
net = 1-p.tau_inc; cf = (1-p.delta)*(1-p.kappa(20))*net;
u1 = 0.0419;
m_of = @(u2) (1-u1)*(1 - u2*(1+p.alpha)) + cf*u1;
h = cf*u1*8; w = 12; F = p.phi_floor*u1;
zf = @(m) (max(m,0).^omg + w*(m+h).^omg).^(1/omg);
Vof = @(z) z.^omg/omg;

mn = m_of(u2g); zn = zf(mn); dead = mn <= F; zn(dead) = F;
cliff = fzero(@(x) m_of(x), [0 2]);
uq = linspace(0.86, 0.99, 300).'; uq = uq(m_of(uq) > 0);
zt = zf(m_of(uq));
zA = interp1(u2g, zn, uq, 'linear');
kn = zn(~dead)./mn(~dead);
zE = min(max(interp1(u2g(~dead), kn, uq, 'linear', 'extrap'),0),1) .* m_of(uq);

out = [uq, m_of(uq), zt, zA, zE, ...
       100*abs(Vof(max(zA,realmin))-Vof(zt))./abs(Vof(zt)), ...
       100*abs(Vof(max(zE,realmin))-Vof(zt))./abs(Vof(zt))];
writematrix(out, 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/curve.csv');
writematrix([u2g, mn, zn, double(dead)], 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/nodes.csv');
fprintf('true cliff u2 = %.4f\n', cliff);
% where does the current linear-z interpolant hit zero?
j = find(~dead,1,'last');
fprintf('last free node %.4f (z=%.5f), next node %.4f (z=%.3g)\n', ...
        u2g(j), zn(j), u2g(j+1), zn(j+1));
fprintf('secant reaches ~0 at u2 = %.4f\n', u2g(j+1));
