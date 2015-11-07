function moveback(hax_or_h,h)
% function moveback([hax],h)
% move h back by one

if nargin < 2 || isempty(hax_or_h)
  h = hax_or_h;
  hax = gca;
else
  hax = hax_or_h;
end

axkids = get(hax,'Children');
n_axkids = length(axkids);
for i=1:n_axkids
    if axkids(i)==h
        ih=i;
        break;
    end
end

if isempty(ih), error('handle(%f) not a child of hax(%f)', h, hax); end
if ih < n_axkids
  new_axkids(1:(ih-1)) = axkids(1:(ih-1));
  new_axkids(ih) = axkids(ih+1);
  new_axkids(ih+1) = h;
  new_axkids((ih+2):n_axkids) = axkids((ih+2):n_axkids);
  set(hax,'Children',new_axkids);
end