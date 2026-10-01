% How each candidate first coordinate behaves across the 66 -> 67 handover,
% evaluated over the whole grid rather than for one representative household.
% Mean shocks, a sweep of saving rates: pure arithmetic on the transition map.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
p = config.params(); p.is_owner = false;
p = utility.build_state_grids(p, [16 12 10], []);
[~, mg, sl] = config.income_profile(p);
prof.mu_growth = mg; prof.sigma_l_log = sl; prof.p_surv = config.survival(p);
shk = grids.shock_grid(p); ann = pension.annuity_price(p, prof, shk);
[muH, ~] = config.h_process(p);
net = 1 - p.tau_inc; t = p.t_ret - 1;          % age 66, last working year

[U1,U2,U3] = ndgrid(p.u1_grid, p.u2_grid, p.u3_grid);
lam = U1(:); sA = U2(:).*(1-U1(:)).*U3(:); sH = U2(:).*(1-U1(:)).*(1-U3(:));
sX  = 1 - lam - sA - sH;

kap = p.kappa(min(t,numel(p.kappa)));
cf66 = (1-p.delta)*(1-kap)*net;  cf67 = (1-p.delta)*net;
m66  = sX + cf66*lam - p.alpha*sH;
u1_66 = lam;

% mean-shock transition into 67
G   = exp(mg(t));                 % Y_67 / Y_66  (the AOW step)
RH  = exp(muH);
tauS = config.tau_effective(p); tS = tauS(min(t,numel(tauS)));
RA  = ((1-tS)*p.Rf + tS*exp(p.mu_S + 0.5*p.sigma_S^2)) / prof.p_surv(t);
RX  = 0.5*(1+p.r) + 0.5*exp(p.mu_S + 0.5*p.sigma_S^2);
fprintf('Y_67/Y_66 = %.3f\n', G);

fprintf('\n%6s %28s %10s %10s %10s\n','c','coordinate','p10','median','p90');
for c = [0.3 0.6 0.9]
    keep = m66 > 0;
    Xn = RX*(1-c)*m66(keep);
    An = RA*(sA(keep) + kap*lam(keep));
    Hn = RH*sH(keep);
    Yn = G*lam(keep);
    Wg = Xn + An + Hn + Yn;                       % W_67 / W_66
    m67  = (Xn + cf67*Yn + net*An/ann(p.t_ret) - p.alpha*Hn) ./ Wg;
    u1n  = Yn ./ Wg;
    ya67 = (Yn + net*An/ann(p.t_ret)) ./ Wg;      % (Y + annuity)/W
    ya66 = u1_66(keep);
    rows = { 'u1 = Y/W (current)',      u1n./u1_66(keep); ...
             '(Y+annuity)/W',            ya67./ya66; ...
             'm  = resource share',      m67./m66(keep) };
    for k = 1:3
        q = prctile(rows{k,2}, [10 50 90]);
        if k==1, fprintf('%6.1f',c); else, fprintf('%6s',''); end
        fprintf(' %28s %10.3f %10.3f %10.3f\n', rows{k,1}, q(1), q(2), q(3));
    end
    fprintf('\n');
end
