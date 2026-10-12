function t = tenure(p)
%TENURE  Label of the arm p describes.
%   'renter' or 'owner' with housing. Without housing, 'nohousing' when the
%   two tenures coincide, and 'nohousing_renter' or 'nohousing_owner' when
%   their income fields differ (model.tenures_differ).
if p.h_mult > 0
    if p.is_owner, t = 'owner'; else, t = 'renter'; end
elseif model.tenures_differ(p)
    if p.is_owner, t = 'nohousing_owner'; else, t = 'nohousing_renter'; end
else
    t = 'nohousing';
end
end
