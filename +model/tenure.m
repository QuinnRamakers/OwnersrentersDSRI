function t = tenure(p)
%TENURE  'renter', 'owner', or 'nohousing' when the model has no housing.
if p.h_mult == 0
    t = 'nohousing';
elseif p.is_owner
    t = 'owner';
else
    t = 'renter';
end
end
