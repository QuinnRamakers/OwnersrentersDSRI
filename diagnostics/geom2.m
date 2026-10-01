% Where the ruin surface sits relative to the u2 nodes, and how small LW gets.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear; clc
p = config.params(); p.is_owner = false;
p = utility.build_state_grids(p, [16 12 10], []);
net = 1 - p.tau_inc; u2g = p.u2_grid(:); u1g = p.u1_grid(:);

t = 20; kap = p.kappa(min(t,numel(p.kappa))); cf = (1-p.delta)*(1-kap)*net;
fprintf('working t=%d: cf = %.4f, alpha = %.3f\n\n', t, cf, p.alpha);
fprintf('%8s %10s %10s %12s %10s\n','u1','u2* cliff','gap/cell','min LW>0','at u2');
for i = 1:numel(u1g)
    u1 = u1g(i);
    % u3 = 0 (renter, no DC): LW = (1-u1)(1 - u2(1+alpha)) + cf*u1
    u2star = (1 + cf*u1/(1-u1)) / (1+p.alpha);
    LW = (1-u1)*(1 - u2g*(1+p.alpha)) + cf*u1;
    pos = LW(LW>0);
    if u2star <= 1
        j = find(u2g < u2star, 1, 'last');
        cellw = u2g(min(j+1,end)) - u2g(j);
        gap = (u2star - u2g(j))/max(cellw,eps);
    else
        gap = NaN;
    end
    [mn, k] = min(pos);
    fprintf('%8.4f %10.4f %10.2f %12.3e %10.4f\n', u1, u2star, gap, mn, u2g(find(LW>0,1,'last')));
end

fprintf('\n--- how nonlinear is u2 -> LW, and where do nodes land in LW ---\n');
u1 = u1g(2);
LW = (1-u1)*(1 - u2g*(1+p.alpha)) + cf*u1;
fprintf('u1=%.4f  LW at each u2 node:\n', u1);
disp([u2g.'; LW.']);
