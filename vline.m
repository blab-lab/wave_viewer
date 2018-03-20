function hl = vline(val,color,linestyle)
% function hl = vline(val,color,linestyle)

a = axis;
hl = line(val*ones(2,1),a(3:4),'LineWidth',1);
if nargin >= 2
  set(hl,'Color',color);
end
if nargin >= 3
  set(hl,'LineStyle',linestyle);
end
