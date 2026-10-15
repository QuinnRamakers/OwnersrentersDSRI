function nodes = grid_rule(rule, N1, N2, p)
%GRID_RULE  Candidate (u1, u2) node vectors for the step-7 grid study.
%
%   nodes = grid_rule('logwealth', N1, N2, p)
%
%   Returns a struct for p.grid_nodes with fields u1 and u2 (the entry anchors
%   are added later by utility.build_state_grids), or [] for 'uniform', which
%   leaves the placement to p.grid_dims as now.
%
%   'logwealth'
%     u1  Points equally spaced in a stretched log of wealth over income,
%         w = 1/u1 - 1, between the current ends u1 = lambda_hi and lambda_lo
%         (w = 0.67 to 4,999 with housing). The density is three times higher
%         for w between 2 and 60, where young owners' value falls by several
%         orders of magnitude, than below 2 or in the tail above 60, which
%         retired owners reach as the house outgrows the pension.
%     u2  Half the points equally spaced in u2 on [0, 0.9]; the other half
%         equally spaced in the log of savings over house value, s = (1-u2)/u2,
%         from s = 0.11 down to 0.0005; then u2 = 1. The bankrupt corner lies
%         at s below the housing-cost rate (0.056 before 55, 0.015 after).
%
%   'edge'
%     The bankruptcy edge, where savings plus income just cover the housing
%     bill k*H, is s = k - u1 (1 + k) in these coordinates (k = maintenance
%     plus the mortgage annuity rate before 55, maintenance after). Starts
%     from 'logwealth' and moves the u1 node nearest each corner of the edge
%     (u2 = 1, u1 = k/(1+k): wealth 17.9 and 66.7 years of income) onto it.
%     Each u2 node of the log-s cluster then moves to the nearest value the
%     edge takes on a u1 node, when one lies within a factor 1.5 in s, so the
%     edge passes through grid points on those rows.

switch rule
    case 'uniform'
        nodes = [];
    case {'power', 'power3'}
        % The existing primitives grid_pow and grid_pow_u2 (2, or 3 for power3),
        % written out as nodes: u1 bunched toward its bottom, u2 toward 1.
        q = 2 + strcmp(rule, 'power3');
        [lo, hi] = u1_ends(p);
        nodes = struct('u1', lo + (hi - lo) * linspace(0, 1, N1).' .^ q, ...
                       'u2', 1 - (1 - linspace(0, 1, N2).') .^ q);
    case 'edge'
        th = p.theta; rm = p.r_m; n = p.N_mort;
        ks = [th + rm * (1 + rm)^n / ((1 + rm)^n - 1), th];        % before 55, after
        nodes = grid_rule('logwealth', N1, N2, p);
        u1 = nodes.u1;
        for c = ks ./ (1 + ks - p.phi_floor)
            [~, j] = min(abs(log(u1) - log(c))); u1(j) = c;
        end
        cand = [];                                                 % s on the edge at each u1 node
        for k = ks
            cand = [cand; k - u1(u1 < k / (1 + k)) * (1 + k)]; %#ok<AGROW>
        end
        cand = cand(cand > 1e-4);
        u2 = nodes.u2; cl = find(u2 > 0.9 & u2 < 1);
        s = (1 - u2(cl)) ./ u2(cl);
        for i = 1:numel(s)
            [d, j] = min(abs(log(cand) - log(s(i))));
            others = s([1:i-1, i+1:end]);
            if d < log(1.5) && all(abs(log(others) - log(cand(j))) > log(1.1))
                s(i) = cand(j); cand(j) = NaN;                     % each edge value used once
            end
        end
        u2(cl) = 1 ./ (1 + s);
        nodes = struct('u1', sort(u1), 'u2', sort(u2));
    case 'logwealth'
        [lo, hi] = u1_ends(p);
        L  = [-log(hi), log(1 + 2), log(1 + 60), -log(lo)];    % -log(u1) = log(1 + w)
        rho = [1 3 1];                                          % relative density per segment
        len = diff(L) .* rho;
        xi = linspace(0, sum(len), N1);
        Lx = zeros(size(xi));
        for i = 1:numel(xi)
            k = find(xi(i) <= cumsum(len) + 1e-12, 1);
            Lx(i) = L(k) + (xi(i) - sum(len(1:k-1))) / rho(k);
        end
        u1 = exp(-Lx(:));
        nA = ceil(0.5 * (N2 - 1));                              % u2 = 0 ... 0.9
        nB = N2 - 1 - nA;                                       % log-spaced in s, then u2 = 1
        uA = linspace(0, 0.9, nA).';
        s  = exp(linspace(log(1 / 0.9 - 1), log(5e-4), nB + 1)).';
        uB = 1 ./ (1 + s(2:end));
        nodes = struct('u1', sort(u1), 'u2', sort([uA; uB; 1]));
    otherwise
        error('grid_rule:name', 'unknown rule %s', rule);
end
end

function [lo, hi] = u1_ends(p)
% The ends utility.build_state_grids uses with housing.
lo = 0.0002; if isfield(p, 'lambda_lo') && ~isempty(p.lambda_lo), lo = p.lambda_lo; end
hi = min(0.9, 3 / (1 + p.h_mult)); if isfield(p, 'lambda_hi') && ~isempty(p.lambda_hi), hi = p.lambda_hi; end
end
