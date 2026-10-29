function tf = same_calibration(p1, p2)
%SAME_CALIBRATION  True if two parameter structs agree on every primitive.
%   The primitives are the fields config.params sets; derived fields follow
%   from them. Tenure is compared too. When the REIT leg is off in both
%   (config.reit_active), its fields are not compared: nothing reads them
%   then, so a solve saved before a REIT field was added or changed is still
%   the same calibration. A REIT field is one whose name contains reit or
%   REIT, or a REIT correlation (corr_RL, corr_RS, corr_RH, corr_RH_rent).
%   A result saved before dc_choice or glide_rule existed (29 October 2026)
%   had the fund's own shares and the span glide, so a missing dc_choice
%   reads as false and a missing glide_rule as 'span'.
f  = [fieldnames(config.params(false)); {'is_owner'}];
if ~config.reit_active(p1) && ~config.reit_active(p2)
    f = f(cellfun(@isempty, regexp(f, 'reit|REIT|^corr_R[LSH]', 'once')));
end
tf = true;
for i = 1:numel(f)
    a = getf(p1, f{i}); b = getf(p2, f{i});
    if ~isequaln(a, b), tf = false; return; end
end
end

function v = getf(p, f)
before = struct('dc_choice', false, 'glide_rule', 'span');   % primitives added later, as they were
if isfield(p, f), v = p.(f); elseif isfield(before, f), v = before.(f); else, v = []; end
if isstring(v), v = char(v); end
end
