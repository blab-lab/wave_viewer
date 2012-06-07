function [ms_frame,ms_frame_advance,nsamps_frame,nsamps_frame_advance] = get_ms_framespec(ms_framespec,fs)

if length(ms_framespec) == 2
  ms_frame = ms_framespec(1); ms_frame_advance = ms_framespec(2);
else
  all_ms_framespecs = get_all_ms_framespecs();
  idx = strmatch(ms_framespec,all_ms_framespecs.name);
  if isempty(idx), error('ms_framespec(%s) not recognized',ms_framespec); end
  ms_frame = all_ms_framespecs.ms_frame(idx);
  ms_frame_advance = all_ms_framespecs.ms_frame_advance(idx);
end

nsamps_frame = round(ms_frame*fs/1000);
nsamps_frame_advance = round(ms_frame_advance*fs/1000);
