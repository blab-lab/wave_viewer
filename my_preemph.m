function ypr = my_preemph(y,yes_preemph)

[leny,yes_rowvec] = get_len_yvec(y);

ypr = y;
if yes_preemph
  sign_preemph = sign(yes_preemph);
  preemph_coff = abs(yes_preemph);
  n_complete_stages = floor(preemph_coff);
  final_preemph_coff = preemph_coff - n_complete_stages;
  stage_preemph_coff = 0.99;
  for istage = 1:n_complete_stages
    if sign_preemph == 1
      B = [1 -stage_preemph_coff]; A = 1;
    else
      B =  1; A = [1 stage_preemph_coff];
    end      
    ypr = filter(B,A,ypr);
  end
  if final_preemph_coff
    if sign_preemph == 1
      B = [1 -final_preemph_coff]; A = 1;
    else
      B =  1; A = [1 final_preemph_coff];
    end      
    ypr = filter(B,A,ypr);
  end
end
if yes_rowvec
  ypr = ypr';
end
