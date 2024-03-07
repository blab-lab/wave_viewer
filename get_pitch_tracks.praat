# get_pitch_tracks.praat
#
# Measure pitch for whole .wav file
# For use with wave_viewer
#
# 2023-10 Chris Naber v1

### Inputs
### ### also stored in free-speech\speech\get_sigproc_defaults.m and wave_viewer.m\get_sigproc_params
form Measure pitch values for segments in a textgrid
    sentence directory_name: C:\Users\Public\Documents\software\wave_viewer
    sentence input_filename: temp_wav
    positive pitch_floor 75
    positive max_candidates 15
    sentence pitch_very_accurate_checkbox no
    positive silence_thresh 0.03
    positive voicing_thresh 0.45
    positive octave_cost 0.01
    positive octave_jump_cost 0.35
    positive voiced_unvoiced_cost 0.14
    positive pitch_ceiling 300
endform

### open the sound and select it
wav_name$ = input_filename$ + ".wav"
Read from file... 'directory_name$'/'wav_name$'
selectObject: 1

### set up output text file
output_filename$ = input_filename$ + "_pitch.txt"
output_fullpath$ = directory_name$ + "/" + output_filename$
writeFileLine: output_fullpath$, "time,pitch"

### get pitch and append results to output text file
To Pitch (ac): 0.0, pitch_floor, max_candidates, pitch_very_accurate_checkbox$, silence_thresh, voicing_thresh, octave_cost, octave_jump_cost, voiced_unvoiced_cost, pitch_ceiling
no_of_frames = Get number of frames
for frame from 1 to no_of_frames
    time = Get time from frame number: frame
    pitch = Get value in frame: frame, "Hertz"
    appendFileLine: output_fullpath$, "'time','pitch'"
endfor
