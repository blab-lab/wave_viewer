function ypr = my_preemph(y,yes_preemph)

[leny,yes_rowvec] = get_len_yvec(y);

if yes_preemph
  if yes_preemph == 1, preemph_coff = 0.95; else, preemph_coff = yes_preemph; end
  ypr(1:(leny-1)) = y(2:end) - preemph_coff*y(1:(end-1));
  ypr(leny) = 0;
else
  ypr = y;
end
if yes_rowvec
  ypr = ypr';
end
