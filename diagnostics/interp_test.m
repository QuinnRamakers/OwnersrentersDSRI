% Manufactured-solution test of interpolation schemes for the CE function z.
% No solve. The true z has the CRRA boundary behaviour that the model forces:
%   as liquid resources m -> 0 the household consumes m, u(m) -> -inf dominates
%   the (finite) continuation, so z -> m with slope 1.
% Surrogate:  z(m) = ( m^(1-g) + w*(m+h)^(1-g) )^(1/(1-g)),  h = human capital/W.
% Exact at both ends, smooth in between, and it is the SHAPE that the schemes
% are being asked to reproduce.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear; clc
p = config.params(); p.is_owner = false;
p = utility.build_state_grids(p, [16 12 10], []);
u2g = p.u2_grid(:); g = p.gamma; omg = 1-g;
net = 1-p.tau_inc; t = 20; kap = p.kappa(min(t,numel(p.kappa)));
cf = (1-p.delta)*(1-kap)*net;

zfun = @(m,h,w) (max(m,0).^omg + w*(m+h).^omg).^(1/omg);
Vof  = @(z) z.^omg/omg;

u1_list = [0.0419 0.0817 0.1216];
w_cont  = 12;            % continuation weight (beta * survival * horizon)
fprintf('%-8s %-26s %10s %10s %10s\n','u1','scheme','med |dV|/V','p90','p99');
for u1 = u1_list
    m_of_u2 = @(u2) (1-u1)*(1 - u2*(1+p.alpha)) + cf*u1;   % exact, affine
    h  = cf*u1*8;                                           % human capital per unit W
    F  = p.phi_floor*u1;                                    % floored CE at a dead node

    m_nodes = m_of_u2(u2g);
    z_nodes = zfun(m_nodes,h,w_cont);
    dead    = m_nodes <= 0;
    z_nodes(dead) = F;                                      % what the solver stores there

    % evaluation points: the occupied top of the axis, above the last live node
    lo = u2g(find(~dead,1,'last')) - 3*(u2g(end)-u2g(end-1));
    hi = min(1, u2g(find(~dead,1,'last')) + 0.5*(u2g(end)-u2g(end-1)));
    uq = linspace(lo, hi, 400).'; uq = uq(m_of_u2(uq) > 0);
    z_true = zfun(m_of_u2(uq),h,w_cont);  V_true = Vof(z_true);

    nm = {}; vl = {};
    nm{end+1}='A linear-z (current)';      vl{end+1}=interp1(u2g, z_nodes, uq, 'linear');
    nm{end+1}='B makima-z';                vl{end+1}=max(interp1(u2g, z_nodes, uq, 'makima'), min(z_nodes));
    nm{end+1}='C linear-log z';            vl{end+1}=exp(interp1(u2g, log(max(z_nodes,realmin)), uq, 'linear'));
    u2_cliff = fzero(@(x) m_of_u2(x), [0 2]);
    uD = [u2g(~dead); u2_cliff]; zD = [z_nodes(~dead); 0];
    nm{end+1}='D linear-z + exact cliff';  vl{end+1}=interp1(uD, zD, uq, 'linear', 0);
    kap_nodes = z_nodes(~dead)./m_nodes(~dead);
    nm{end+1}='E linear-kappa x exact m';  vl{end+1}=interp1(u2g(~dead), kap_nodes, uq, 'linear', 'extrap') .* m_of_u2(uq);
    nm{end+1}='F makima-kappa x exact m';  vl{end+1}=interp1(u2g(~dead), kap_nodes, uq, 'makima', 'extrap') .* m_of_u2(uq);

    for k = 1:numel(nm)
        V = Vof(max(vl{k}, realmin));
        e = abs(V - V_true)./abs(V_true);
        if k==1, fprintf('%-8.4f', u1); else, fprintf('%-8s',''); end
        fprintf(' %-26s %9.2f%% %9.2f%% %9.2f%%\n', nm{k}, 100*median(e), ...
                100*prctile(e,90), 100*prctile(e,99));
    end
    fprintf('\n');
end
