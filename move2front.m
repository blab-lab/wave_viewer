function move2front(hax_or_h,h)
% function move2front([hax],h)
% move h to the front of hax

if nargin < 2 || isempty(hax_or_h)
  h = hax_or_h;
  hax = gca;
else
  hax = hax_or_h;
end

axkids = get(hax,'Children');
ih = dsearchn(axkids,h);
if isempty(ih), error('handle(%f) not a child of hax(%f)', h, hax); end
remh_axkids = axkids;
remh_axkids(ih) = [];
new_axkids = [h; remh_axkids];
set(hax,'Children',new_axkids);
