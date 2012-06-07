function all_ms_framespecs = get_all_ms_framespecs()

i = 0;
i = i + 1; name{i} = 'less narrowband'; ms_frame(i) = 18; ms_frame_advance(i) = 1.5;
i = i + 1; name{i} = 'narrowband';      ms_frame(i) = 36; ms_frame_advance(i) = 3;
i = i + 1; name{i} = 'more narrowband'; ms_frame(i) = 72; ms_frame_advance(i) = 3;
i = i + 1; name{i} = 'broadband';       ms_frame(i) = 4; ms_frame_advance(i) = 0.8;
i = i + 1; name{i} = 'more broadband';  ms_frame(i) = 2; ms_frame_advance(i) = 0.4;

all_ms_framespecs.name = name;
all_ms_framespecs.ms_frame = ms_frame;
all_ms_framespecs.ms_frame_advance = ms_frame_advance;
