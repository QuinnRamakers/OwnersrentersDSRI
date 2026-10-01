% Robustness of the scheme ordering to the surrogate's free parameters and to
% node placement. Only the m -> 0 asymptote (z -> m, forced by CRRA) is fixed.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear; clc
p = config.params(); p.is_owner = false;
g = p.gamma; omg = 1-g; net = 1-p.tau_inc;
cf = (1-p.delta)*(1-p.kappa(20))*net;
zfun = @(m,h,w) (max(m,0).^omg + w*(m+h).^omg).^(1/omg);
Vof  = @(z) z.^omg/omg;

names = {'A linear-z (current)','B makima-z','C linear-log z', ...
         'D linear-z+exact cliff','E linear-kappa','F makima-kappa'};
agg = zeros(6,0); rows = {};
for N2 = [12 20 32]
  for gp = [1 2]
    for w_cont = [4 12 40]
      for hmul = [3 8 20]
        q = p; q.N_u2 = N2; q.grid_pow_u2 = gp;
        q = utility.build_state_grids(q, [16 N2 10], []);
        u2g = q.u2_grid(:);
        u1 = 0.0419;
        m_of = @(u2) (1-u1)*(1 - u2*(1+p.alpha)) + cf*u1;
        h = cf*u1*hmul; F = p.phi_floor*u1;
        mn = m_of(u2g); zn = zfun(mn,h,w_cont); dead = mn<=0; zn(dead)=F;
        last = find(~dead,1,'last');
        uq = linspace(u2g(max(last-2,1)), min(1,u2g(last)+0.5*(u2g(end)-u2g(end-1))), 400).';
        uq = uq(m_of(uq)>0);
        Vt = Vof(zfun(m_of(uq),h,w_cont));
        cliff = fzero(@(x) m_of(x),[0 2]);
        kn = zn(~dead)./mn(~dead);
        v = {interp1(u2g,zn,uq,'linear'), ...
             max(interp1(u2g,zn,uq,'makima'),min(zn)), ...
             exp(interp1(u2g,log(max(zn,realmin)),uq,'linear')), ...
             interp1([u2g(~dead);cliff],[zn(~dead);0],uq,'linear',0), ...
             min(max(interp1(u2g(~dead),kn,uq,'linear','extrap'),0),1).*m_of(uq), ...
             min(max(interp1(u2g(~dead),kn,uq,'makima','extrap'),0),1).*m_of(uq)};
        col = zeros(6,1);
        for k=1:6, e=abs(Vof(max(v{k},realmin))-Vt)./abs(Vt); col(k)=100*prctile(e,99); end
        agg(:,end+1) = col; rows{end+1} = sprintf('N2=%d pow=%d w=%g h=%gx',N2,gp,w_cont,hmul);
      end
    end
  end
end
fprintf('p99 |dV|/V over %d surrogate/grid configurations\n\n', size(agg,2));
fprintf('%-24s %12s %12s %12s\n','scheme','median','worst','best');
for k=1:6
    fprintf('%-24s %11.2f%% %11.2f%% %11.3f%%\n', names{k}, median(agg(k,:)), max(agg(k,:)), min(agg(k,:)));
end
fprintf('\nfraction of configurations where F beats A: %.0f%%\n', 100*mean(agg(6,:)<agg(1,:)));
fprintf('fraction where E beats A:                  %.0f%%\n', 100*mean(agg(5,:)<agg(1,:)));
fprintf('median ratio A/F: %.1fx\n', median(agg(1,:)./agg(6,:)));
