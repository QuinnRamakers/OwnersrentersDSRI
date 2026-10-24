function Z = fill_bankrupt(Z, bk, method, ax, guard)
%FILL_BANKRUPT  Fill the bankrupt grid points of an array from its solvent side.
%
%   Z = solver.fill_bankrupt(Z, bk, method, ax, guard)
%
%   Z is an array on the grid with axis vectors ax{1..d}, bk a logical array
%   of the same size, true at bankrupt points. The bankrupt points are filled
%   in layers, nearest the solvent region first: a point is filled once it has
%   a neighbour along one of the axes that is solvent or filled in an earlier
%   layer, and takes the mean over the axes and directions where it has one of
%     'nearest'  that neighbour's value;
%     'linear'   the straight line through that neighbour and the next point
%                along the same axis, extended to the bankrupt point; the
%                neighbour's value where the next point is bankrupt (not yet
%                filled) or off the grid.
%   guard keeps the straight line from overshooting:
%     'value'    between the point's own value and the neighbour's (for the
%                continuation: between the bankrupt value and the solvent one);
%     'unit'     between 0 and 1 (for the policies).
%   'nearest' needs no guard. Points with no solvent point to reach keep their
%   value.

if ~any(bk(:)) || all(bk(:)), return; end
linear = strcmp(validatestring(method, {'nearest', 'linear'}, 'fill_bankrupt', 'method'), 'linear');
by_value = strcmp(validatestring(guard, {'value', 'unit'}, 'fill_bankrupt', 'guard'), 'value');

d  = numel(ax);
sz = size(Z); sz(end+1 : d) = 1;
stride = cumprod([1, sz(1:end-1)]);
Z0 = Z;
known = ~bk;
todo  = find(bk);
sub   = cell(1, d);
while ~isempty(todo)
    [sub{:}] = ind2sub(sz(1:d), todo);
    S = zeros(numel(todo), 1);
    n = zeros(numel(todo), 1);
    for a = 1:d
        if sz(a) < 2, continue; end
        x = ax{a}(:);
        for s = [-1, 1]
            i1 = sub{a} + s;
            m  = find(i1 >= 1 & i1 <= sz(a));
            j1 = todo(m) + s * stride(a);
            k  = known(j1);
            m  = m(k); j1 = j1(k);
            v  = Z(j1);
            if linear
                i2 = sub{a}(m) + 2 * s;
                m2 = find(i2 >= 1 & i2 <= sz(a));
                j2 = j1(m2) + s * stride(a);
                k2 = known(j2);
                m2 = m2(k2); j2 = j2(k2);
                i0 = sub{a}(m(m2));
                x0 = x(i0); xa = x(i0 + s); xb = x(i0 + 2 * s);
                v1 = v(m2);
                vl = v1 + (v1 - Z(j2)) .* (x0 - xa) ./ (xa - xb);
                if by_value
                    w  = Z0(todo(m(m2)));
                    vl = min(max(vl, min(w, v1)), max(w, v1));
                else
                    vl = min(max(vl, 0), 1);
                end
                v(m2) = vl;
            end
            S(m) = S(m) + v;
            n(m) = n(m) + 1;
        end
    end
    now = n > 0;
    if ~any(now), break; end
    Z(todo(now)) = S(now) ./ n(now);
    known(todo(now)) = true;
    todo = todo(~now);
end
end
