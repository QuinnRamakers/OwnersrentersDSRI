function G = policy_gaps(r, ref, bands)
%POLICY_GAPS  One solve's policies read at the reference's households, by age band.
%
%   G = policy_gaps(r, ref)
%   G = policy_gaps(r, ref, {[25 39], [40 54], [55 66], [67 89], [90 95]})
%
%   The panel gaps of case_gaps mix two things: the policy error at an age,
%   and the different wealth households bring to that age from earlier years
%   (owners' policies before 40 are not converged on any grid). Here both
%   solutions' policies are read at the same states, those of the reference's
%   simulated households at each age, so only the first is left. Consumption
%   is the consumption share times liquid resources, with the floor, as in
%   simulate.paths_lna. Fields, each 1 x the number of bands (default 26-39,
%   40-66, 67-95):
%     C    largest |mean consumption / the reference's - 1|
%     pi   largest |difference| in the mean liquid equity share
%   and the gaps at every age as C_age and pi_age (1 x T, ages in ages).
%   policy_gaps(ref, ref) is zero: the reference's own policies at its own
%   households are its panel.

if nargin < 3, bands = {[26 39], [40 66], [67 95]}; end
s = figures.panel_data(ref).sim;
p = r.p;
T = p.T;
[N, T0] = size(s.Y);
assert(T0 == T, 'policy_gaps:T', 'the two solutions have different horizons.');

q_grid = p.q_grid(:);
iq1    = find(q_grid == 1);
q_dep  = numel(q_grid) > 1 & flipud(cummax(flipud(double(p.q_live(:))))) > 0;
C = zeros(N, T); P = zeros(N, T);
for t = 1:T
    [g1, g2] = utility.grid_at(p, t);
    sAH = s.sA(:, t) + s.sH(:, t);
    u1 = min(max(s.lambda(:, t), g1(1)), g1(end));
    u2 = min(max(sAH ./ max(1 - s.lambda(:, t), 1e-12), g2(1)), g2(end));
    u3 = min(max(s.sA(:, t) ./ max(sAH, 1e-12), 0), 1);
    if q_dep(t)
        ax = {g1, g2, p.u3_grid, q_grid};
        q  = min(max(s.q(:, t), q_grid(1)), q_grid(end));
        Fc = griddedInterpolant(ax, r.sol.c_pol(:,:,:,:,t), 'linear', 'nearest');
        Fp = griddedInterpolant(ax, r.sol.pi_pol(:,:,:,:,t), 'linear', 'nearest');
        cf = Fc(u1, u2, u3, q); pf = Fp(u1, u2, u3, q);
    else
        ax = {g1, g2, p.u3_grid};
        Fc = griddedInterpolant(ax, r.sol.c_pol(:,:,:,iq1,t), 'linear', 'nearest');
        Fp = griddedInterpolant(ax, r.sol.pi_pol(:,:,:,iq1,t), 'linear', 'nearest');
        cf = Fc(u1, u2, u3); pf = Fp(u1, u2, u3);
    end
    LW = s.LW(:, t);
    F  = p.phi_floor * s.Y(:, t);
    c  = max(min(cf, 1), 0) .* max(LW, 0);
    c(LW < F) = F(LW < F);
    C(:, t) = c;
    P(:, t) = max(min(pf, 1), 0);
end

a  = s.ages(:).';
dC = abs(mean(C, 1) ./ mean(s.C, 1) - 1);
dP = abs(mean(P, 1) - mean(s.pi, 1));
nb = numel(bands);
G = struct('C', zeros(1, nb), 'pi', zeros(1, nb), 'ages', a, 'C_age', dC, 'pi_age', dP);
for b = 1:nb
    w = a >= bands{b}(1) & a <= bands{b}(2);
    G.C(b) = max(dC(w)); G.pi(b) = max(dP(w));
end
end
