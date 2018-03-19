function hl = hline(val,color,linestyle)
% function hl = hline(val,color,linestyle)

a = axis;
hl = line(a(1:2),val*ones(2,1),'LineWidth',1);
if nargin >= 2
  set(hl,'Color',color);
end
if nargin >= 3
  set(hl,'LineStyle',linestyle);
end
