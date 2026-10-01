function tf = same_calibration(p1, p2)
%SAME_CALIBRATION  True if two parameter structs agree on every primitive.
%   The primitives are the fields config.params sets; derived fields follow
%   from them. Tenure is compared too.
f  = [fieldnames(config.params(false)); {'is_owner'}];
tf = true;
for i = 1:numel(f)
    a = getf(p1, f{i}); b = getf(p2, f{i});
    if ~isequaln(a, b), tf = false; return; end
end
end

function v = getf(p, f)
if isfield(p, f), v = p.(f); else, v = []; end
if isstring(v), v = char(v); end
end
