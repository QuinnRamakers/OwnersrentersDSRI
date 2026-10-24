function tf = same_calibration(p1, p2)
%SAME_CALIBRATION  True if two parameter structs agree on every primitive.
%   The primitives are the fields config.params sets; derived fields follow
%   from them. Tenure is compared too. A primitive added after results were
%   saved, whose default reproduces the solves made before it (abs_fill),
%   reads as that default where a saved struct lacks it.
f  = [fieldnames(config.params(false)); {'is_owner'}];
tf = true;
for i = 1:numel(f)
    a = getf(p1, f{i}); b = getf(p2, f{i});
    if ~isequaln(a, b), tf = false; return; end
end
end

function v = getf(p, f)
legacy = struct('abs_fill', 'none');
if isfield(p, f), v = p.(f); elseif isfield(legacy, f), v = legacy.(f); else, v = []; end
if isstring(v), v = char(v); end
end
