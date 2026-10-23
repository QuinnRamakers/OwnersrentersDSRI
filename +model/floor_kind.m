function [absorbing, label] = floor_kind(p)
%FLOOR_KIND  Whether the consumption floor is absorbing, and the word for a
%   household at it.
%
%   [absorbing, label] = model.floor_kind(p)
%
%   label is 'bankrupt' with the absorbing floor (c_min or phi_abs positive)
%   and 'floored' with the yearly top-up at phi_floor. A result saved before
%   the absorbing floor existed has the top-up.
absorbing = isfield(p, 'floor_absorbing') && p.floor_absorbing;
if absorbing, label = 'bankrupt'; else, label = 'floored'; end
end
