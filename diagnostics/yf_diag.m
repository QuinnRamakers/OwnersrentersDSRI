% Is the yf/yw disagreement a bug, or is linear-in-x simply a different
% interpolant from linear-in-lambda on the same nodes?
% At the NODES the two must agree exactly. Between them they need not.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear; clc
a = config.params(); a.is_owner=false; a = utility.build_state_grids(a,[14 14 10],3);
g  = a.u1_grid; gx = g./(1-g);
z  = 0.3 + 0.5*g.^0.7;                       % any smooth positive test function
fa = griddedInterpolant(g,  z, 'linear','nearest');
fx = griddedInterpolant(gx, z, 'linear','nearest');
fprintf('at the nodes:      max |fa(lam_i) - fx(x_i)| = %.3g\n', ...
        max(abs(fa(g) - fx(gx))));
lamq = linspace(g(1), g(end), 4001).';
e = abs(fa(lamq) - fx(lamq./(1-lamq)))./abs(fa(lamq));
fprintf('between nodes:     median %.2f%%   p99 %.2f%%   max %.2f%%\n', ...
        100*median(e), 100*prctile(e,99), 100*max(e));
[~,i] = max(e);
fprintf('worst at lam = %.4f, between nodes %.4f and %.4f\n', lamq(i), ...
        max(g(g<=lamq(i))), min(g(g>=lamq(i))));
fprintf('\ncell widths in lambda: %.4f (uniform)\n', g(3)-g(2));
fprintf('same cells in x:       %.4f ... %.4f (stretched %.1fx across the axis)\n', ...
        gx(3)-gx(2), gx(end)-gx(end-1), (gx(end)-gx(end-1))/(gx(3)-gx(2)));
