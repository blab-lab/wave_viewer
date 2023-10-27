# get_pitch_tracks.praat
#
# Measure pitch for whole .wav file
# For use with wave_viewer
#
# 2023-10 Chris Naber v1

#Inputs
form Measure pitch values for segments in a textgrid
    sentence directory_name: /Users/Public/Documents/software/wave_viewer
    sentence file_name_input: temp_wav
    positive max_candidates = 15
    positive silence_thresh = 0.03
    positive voicing_thresh = 0.45
    positive octave_cost = 0.01
    positive octave_jump_cost = 0.35
    positive voiced_unvoiced_cost = 0.14
endform

#open the sound and select it
wav_name$ = file_name_input$ + ".wav"
Read from file... 'directory_name$'/'wav_name$'
soundID1$ = selected$("Sound")

# TODO CWN put in the real code below

#extract formants
To Formant (burg)... 'time_step' 'number_of_formants' 'maximum_formant' 'window_size' 'preemphasis'

#write pitches
file_name_output$ = file_name$ + "_pitch.txt"
Down to Table... yes yes 6 no 3 yes 3 no 
Save as tab-separated file... 'directory_name$'/'file_name_output$'

