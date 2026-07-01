function ub = bequest(W, chi, gamma)
%BEQUEST  U^B(W) = chi * W^(1-gamma)/(1-gamma); 0 when chi=0.

if chi == 0
    ub = zeros(size(W));
    return
end

ub = -inf(size(W));
mask = W > 0;

if abs(gamma - 1) < 1e-12
    ub(mask) = chi .* log(W(mask));
else
    ub(mask) = chi .* W(mask).^(1 - gamma) ./ (1 - gamma);
end
end
