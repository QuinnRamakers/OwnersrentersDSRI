function a_t = annuity_price(p, profile, shocks)
%ANNUITY_PRICE  Backward recursion for the unit-annuity price a_t.
%
%   Chosen so that, paired with the account dynamics
%       A_{t+1} = R^A_with * (A_t - h^A(A_t)),  h^A(A_t) = A_t / a_t,
%   and the with-credit individual return
%       R^A_with = ((1-tau)*Rf + tau*R^S) / p_t
%   the expected per-period payout E[h^A_t] is constant in t (level-mean):
%       a_t = 1 + p_t * a_{t+1} / E[R^A_no_credit_{t+1}]
%   The survival weight p_t applies to a_{t+1}; the denominator uses E[R]
%   (not E[1/R]) to keep expected payouts level rather than drifting.
%
%   Boundary: a(T) = 1 (last period alive: pays 1 unit, no future).
%
%   The equity share comes from config.tau_effective, NOT p.tau_S directly,
%   so the price always reflects the share the fund actually runs in
%   retirement (p.tau_decum). a_t falls as that share rises -- a higher-return
%   fund sustains a bigger level payout -- so a mismatch here is not cosmetic:
%   pricing a 50%-equity decumulation fund off a 0% path understates the
%   payout by ~20%. With p.tau_decum unset this is p.tau_S exactly, and every
%   pre-existing result is reproduced bit-for-bit.
%
%   Only a(t) for t >= t_ret is ever read (the retired branch of
%   bellman_step / simulate.paths), and the recursion is backward, so a(t_ret)
%   depends solely on the DECUMULATION share. The accumulation glide -- and
%   any per-state tau the solver picks under choose_tau_S, which is an
%   accumulation-only choice -- never influences a number anyone uses.

T   = p.T;
a_t = zeros(T, 1);
a_t(T) = 1;

R_S = shocks.R_S(:).';     % 1 x n_S
w_S = shocks.w_S(:).';     % 1 x n_S

tau_path = config.tau_effective(p);

for t = T-1 : -1 : 1
    tau           = tau_path(t);
    p_t           = profile.p_surv(t);
    R_A_no_credit = (1 - tau) * p.Rf + tau * R_S;
    E_R           = sum(w_S .* R_A_no_credit);   % E[R^A_no_credit]
    % E[R^A_with] = E[R_no] / p_t  =>  1/E[R_with] = p_t / E[R_no]
    a_t(t) = 1 + p_t * a_t(t+1) / E_R;
end

end
