function viewer_end_state = wave_viewer(y,varargin)
% function [viewer_end_state] = wave_viewer(y, [options...])
% if output arg viewer_end_state is provided, wave_viewer() will start blocked, otherwise command prompt is returned
% signal processing options (with default values shown):
%   'fs', 11025, ...
%   'ms_framespec_gram', 'broadband', ...
%   'ms_framespec_form', 'narrowband', ...
%   'nfft', 4096, ...
%   'nlpc', 15, ...
%   'nformants', 3, ...
%   'preemph', 0.95, ...
%   'pitchlimits', [50 300], ...
%   'ampl_thresh4voicing', 0, ... (0 means don't apply a voicing threshold)
%   or: 'sigproc_params',<a sigproc_params struct from a viewer_end_state>
%
% plot options (with default values shown):
%   'hzbounds4plot', [0 sigproc_params.fs/2], ...
%   'name', 'signal', ...
%   'axfracts', [], ... (it's a correctly ordered list of wave_viewer axis figure fractions)
%   'yes_gray', 1, ...
%   'figpos',[850         726        1170         757], ...
%   or: 'plot_params',<a plot_params struct from a viewer_end_state>
%
% event options (with default values shown):
%   'event_names', [], ...
%   'event_times', [], ...
%   'user_event_names', [], ...
%   'user_event_times', [], ...
%   'is_good_trial', 1, ...
%   or: 'event_params',<an event_params struct from a viewer_end_state>

  global yes_auto_process
  global wavefig nwavefigs
  global yax_fact tmarker_init_border
  global axborder_xl axborder_xr axborder_yl axborder_yu
  global figborder_xl figborder_xr figborder_yl figborder_yu
  global ax_heighten_inc
  global wave_viewer_logshim
  global default_tmarker_width
  global max_dist_fract2del_event
  global formant_colors formant_marker_width

  yes_profile = 0;
  
  if yes_profile, profile on; end
  
  yes_auto_process = 0;
  yax_fact = 0.05;
  tmarker_init_border = 0.05;
  axborder_xl = 0.1; axborder_xr = 0.05;
  % axborder_yl = 0.2; axborder_yu = 0.15;
  axborder_yl = 0.02; axborder_yu = 0.075;
  figborder_xl = 0.02; figborder_xr = 0.01; figborder_yl = 0.01; figborder_yu = 0.05;
  ax_heighten_inc = 0.1;
  wave_viewer_logshim = 1; % makes 20*log10(0 + wave_viewer_logshim) = 0
  default_tmarker_width = 2;
  max_dist_fract2del_event = 0.03; % must be within 3% of ax_tlims of event marker to delete it
  formant_colors = {'b','r','g','k','c','m'}; % colors for more formants than you'll ever use
  formant_marker_width = 4;

  nlpc_choices = 7:20;
  preemph_range = [-2 3];
  all_ms_framespecs = get_all_ms_framespecs();

  params.sigproc_params = struct('fs', 11025, ...
                                 'ms_framespec_gram', 'broadband', ...
                                 'ms_framespec_form', 'narrowband', ...
                                 'nfft', 4096, ...
                                 'nlpc', 15, ...
                                 'nformants', 3, ...
                                 'preemph', 0.95, ...
                                 'pitchlimits', [50 300], ...
                                 'ampl_thresh4voicing', 0);
  params.plot_params    = struct('hzbounds4plot', [], ...
                                 'name', 'signal', ...
                                 'axfracts', [], ...
                                 'yes_gray', 1, ...
                                 'thresh_gray', 0, ...
                                 'max_gray', 1, ...
                                 'figpos',[850         726        1170         757]);
  params.event_params   = struct('event_names', [], ...
                                 'event_times', [], ...
                                 'user_event_name_prefix','uev', ...
                                 'user_event_names', [], ...
                                 'user_event_times', [], ...
                                 'is_good_trial', 1);

  param_struct_names = fieldnames(params);
  n_param_structs = length(param_struct_names);
  [option_names,option_values] = make_option_specs(varargin{:});
  iopt = 0;
  while 1
    nopts_left = length(option_names);
    iopt = iopt + 1; if iopt > nopts_left, break; end
    the_opt_name = option_names{iopt}; the_opt_val = option_values{iopt};
    opt_idx = strmatch(the_opt_name,param_struct_names);
    if ~isempty(opt_idx)
      if ~isempty(the_opt_val)
        the_opt_val_fields = fieldnames(the_opt_val);
        nfields = length(the_opt_val_fields);
        for ifield = 1:nfields
          the_field_name = the_opt_val_fields{ifield};
          the_field_val = the_opt_val.(the_field_name);
          if ~isempty(the_field_val), params.(the_opt_name).(the_field_name) = the_field_val; end
        end
      end
      option_names(iopt) = []; option_values(iopt) = []; iopt = iopt - 1;
    end
  end
  % notice how the ordering here allows command line params to override values of params in command line param structures
  for i_param_struct = 1:n_param_structs
    iopt = 0;
    while 1
      nopts_left = length(option_names);
      iopt = iopt + 1; if iopt > nopts_left, break; end
      the_opt_name = option_names{iopt}; the_opt_val = option_values{iopt};
      the_params_struct_name = param_struct_names{i_param_struct};
      opt_idx = strmatch(the_opt_name,fieldnames(params.(the_params_struct_name)));
      if ~isempty(opt_idx)
        if ~isempty(the_opt_val), params.(the_params_struct_name).(the_opt_name) = the_opt_val; end
        option_names(iopt) = []; option_values(iopt) = []; iopt = iopt - 1;
      end
    end
  end
  nopts_left = length(option_names);
  for iopt = 1:nopts_left
    the_opt_name = option_names{iopt}; the_opt_val = option_values{iopt};
    if strcmp(the_opt_name,'auto_process')
      yes_auto_process = the_opt_val;
    else
      warning(sprintf('option(%s) not recognized',the_opt_name));
    end
  end
  for i_param_struct = 1:n_param_structs
    eval(sprintf('%s = params.%s;',param_struct_names{i_param_struct},param_struct_names{i_param_struct}));
  end
  clear params

  if isempty(plot_params.hzbounds4plot), plot_params.hzbounds4plot = [0 sigproc_params.fs/2]; end
  
  if nargout >= 1, yes_start_blocking = 1; else, yes_start_blocking = 0; end
  if nargout >= 1, viewer_end_state.name = 'running'; end
  fprintf('yes_start_blocking(%d)\n',yes_start_blocking);
  
  hf = figure('Name',plot_params.name,'Position',plot_params.figpos);
  set(hf,'DeleteFcn',@delete_func);
  wave_ax = new_wave_ax(y,sigproc_params,plot_params,event_params);
  ampl_ax = new_ampl_ax(wave_ax,sigproc_params);
  pitch_ax = new_pitch_ax(wave_ax,ampl_ax,sigproc_params);
  gram_ax = new_gram_ax(wave_ax,ampl_ax,sigproc_params,plot_params);
  spec_ax = new_spec_ax(gram_ax);

  update_wave_ax_tlims_from_gram_ax(wave_ax,gram_ax);
  
  % reorder the axes with wave_ax on top
  nax = 0;
  nax = nax + 1; ax(nax) = spec_ax; set_ax_i(spec_ax,nax);
  nax = nax + 1; ax(nax) = ampl_ax; set_ax_i(ampl_ax,nax);
  nax = nax + 1; ax(nax) = pitch_ax; set_ax_i(pitch_ax,nax);
  nax = nax + 1; ax(nax) = gram_ax; set_ax_i(gram_ax,nax);
  nax = nax + 1; ax(nax) = wave_ax; set_ax_i(wave_ax,nax);
  if ~isempty(plot_params.axfracts)
    set_axfracts(ax,nax,plot_params.axfracts);
    reposition_ax(ax,nax);
  else
    redistrib_ax(ax,nax);
  end
  cur_ax = ax(1);
  my_iwavefig = add_wavefig(hf,nax,ax);

  if yes_auto_process
    viewer_end_state.name = 'cont';
    if yes_profile, profile off; end
    delete(hf);
    return;
  end
  
  bgcolor = [.8 .8 .8]; padL = 10; padU = 10; padUinter = 2;
  horiz_orig = padU;
  colwidth = 70;
  textbutt1line_height = 30;
  textbutt2line_height = 40;
  h_button_calcFx = [];
  normal_bgcolor = [];
  alert4calcFx = 0;
  h_button_help = uicontrol('Style','pushbutton', 'String','HELP', 'FontWeight','bold', ...
                             'Position',[padL horiz_orig colwidth textbutt1line_height], 'HandleVisibility','off', 'Callback',@my_help_func); horiz_orig = horiz_orig + textbutt1line_height + padU;
  function my_help_func(hObject,eventdata) % callback for h_button_help
    helpstr = sprintf(['keyboard shortcuts:\n', ...
                       '"v": if ampl_ax, set amplitude threshold for voicing (i.e., valid formants)\n', ...
                       '"a": add a user event\n', ...
                       '"d": delete a user event\n', ...
                       '"rightarrow": advance tmarker_spec by one frame\n', ...
                       '"leftarrow": retreat tmarker_spec by one frame\n', ...
                       '"e": expand\n', ...
                       '"w": widen\n', ...
                       '"h": heighten\n', ...
                       '"u": unheighten = reduce\n']);
    helpdlg(helpstr);
  end
  h_button_playin = uicontrol('Style','pushbutton', 'String','PLAY', 'FontWeight','bold', ...
                             'Position',[padL horiz_orig colwidth textbutt1line_height], 'HandleVisibility','off', 'Callback',@playin); horiz_orig = horiz_orig + textbutt1line_height + padU;
  function playin(hObject,eventdata) % callback for h_button_playin
    play_from_wave_ax(wave_ax);
  end

  h_button_endprogram = uicontrol('Style','pushbutton','String','END', 'FontWeight','bold', ...
                             'Position',[padL horiz_orig colwidth textbutt1line_height], 'HandleVisibility','off', 'Callback',@endprogram); horiz_orig = horiz_orig + textbutt1line_height + padU;
  function endprogram(hObject,eventdata) % callback for h_button_endprogram
    if check4alert4calcFx('ending')
      viewer_end_state.name = 'end';
      delete(hf);
    end
  end
  h_button_contprogram = uicontrol('Style','pushbutton','String','CONTINUE', 'FontWeight','bold', ...
                             'Position',[padL horiz_orig colwidth textbutt1line_height], 'HandleVisibility','off', 'Callback',@contprogram); horiz_orig = horiz_orig + textbutt1line_height + padU;
  function contprogram(hObject,eventdata) % callback for h_button_contprogram

    if check4alert4calcFx('continuing')
      viewer_end_state.name = 'cont';
      delete(hf);
    end
  end
  function yes_end = check4alert4calcFx(endcont_str)
    yes_end = 1;
    if alert4calcFx
      calc_quest_response = questdlg(sprintf('recalculate before %s?',endcont_str));
      switch calc_quest_response
        case 'Yes',  calcFx([],[]), yes_end = 1;
        case 'No', yes_end = 1;
        case 'Cancel', yes_end = 0;
      end
    end
  end

  h_button_clear_events = uicontrol('Style','pushbutton', 'String','<html>CLEAR<br>EVENTS', 'FontWeight','bold', ...
                             'Position',[padL horiz_orig colwidth textbutt2line_height], 'HandleVisibility','off', 'Callback',@clear_events); horiz_orig = horiz_orig + textbutt2line_height + padU;
  function clear_events(hObject,eventdata) % callback for h_button_clear_events
    clear_all_user_events(nax,ax);
  end
  h_button_bad_trial = uicontrol('Style','pushbutton', 'String','poop', 'FontWeight','bold', ...
                              'Position',[padL horiz_orig colwidth textbutt1line_height], 'HandleVisibility','off', 'Callback',@toggle_bad_trial); horiz_orig = horiz_orig + textbutt1line_height + padU;
  if event_params.is_good_trial
    set(h_button_bad_trial,'String','GOOD');
    set(h_button_bad_trial,'BackgroundColor',[0 1 0]);
  else
    set(h_button_bad_trial,'String','BAD');
    set(h_button_bad_trial,'BackgroundColor',[1 0 0]);
  end
  function toggle_bad_trial(hObject,eventdata) % callback for h_button_bad_trial
    if event_params.is_good_trial
      event_params.is_good_trial = 0;
    else
      event_params.is_good_trial = 1;
    end
    if event_params.is_good_trial
      set(h_button_bad_trial,'String','GOOD');
      set(h_button_bad_trial,'BackgroundColor',[0 1 0]);
    else
      set(h_button_bad_trial,'String','BAD');
      set(h_button_bad_trial,'BackgroundColor',[1 0 0]);
    end
  end
  
  h_slider_preemph = uicontrol('Style','slider', 'Min',preemph_range(1), 'Max',preemph_range(2), 'SliderStep', [0.01 0.1], 'Value',sigproc_params.preemph, ...
                             'Position',[padL horiz_orig colwidth 20], 'HandleVisibility','off', 'Callback',@set_preemph); horiz_orig = horiz_orig + 20 + padUinter;
  h_edit_preemph = uicontrol('Style','edit', 'String',sigproc_params.preemph, ...
                             'Position',[padL horiz_orig colwidth 20], 'HandleVisibility','off'); horiz_orig = horiz_orig + 20 + padUinter;
  h_text_preemph = uicontrol('Style','text', 'String','preemph', 'FontWeight','bold', ...
                             'Position',[padL horiz_orig colwidth 15], 'HandleVisibility','off', 'BackgroundColor',bgcolor); horiz_orig = horiz_orig + 15 + padU;
  last_sigproc_params.preemph = sigproc_params.preemph;
  function set_preemph(hObject,eventdata) % callback for h_slider_preemph
    sigproc_params.preemph = get(hObject, 'Value'); set(h_edit_preemph,'String',sigproc_params.preemph);
    set_alert4calcFx_if_true(last_sigproc_params.preemph ~= sigproc_params.preemph);
    calcFx(hObject,eventdata);
  end
  
  n_framespecs = length(all_ms_framespecs.name);
  for i_framespec = 1:n_framespecs
    framespec_choice_str{i_framespec} = sprintf('%.0f/%.1fms, %s',all_ms_framespecs.ms_frame(i_framespec),all_ms_framespecs.ms_frame_advance(i_framespec),all_ms_framespecs.name{i_framespec});
  end

  h_slider_thresh_gray = uicontrol('Style','slider', 'Min',0, 'Max',1, 'SliderStep', [0.01 0.1], 'Value',plot_params.thresh_gray, ...
                               'Position',[padL horiz_orig colwidth 20], 'HandleVisibility','off', 'Callback',@set_thresh_gray); horiz_orig = horiz_orig + 20 + padUinter;
  function set_thresh_gray(hObject,eventdata) % callback for h_slider_thresh_gray
    plot_params.thresh_gray = get(hObject, 'Value');
    if plot_params.yes_gray, my_colormap('my_gray',1,plot_params.thresh_gray,plot_params.max_gray); end
  end

  h_slider_max_gray = uicontrol('Style','slider', 'Min',0, 'Max',1, 'SliderStep', [0.01 0.1], 'Value',plot_params.max_gray, ...
                               'Position',[padL horiz_orig colwidth 20], 'HandleVisibility','off', 'Callback',@set_max_gray); horiz_orig = horiz_orig + 20 + padUinter;
  h_text_max_gray = uicontrol('Style','text', 'String','gram color', 'FontWeight','bold', ...
                             'Position',[padL horiz_orig colwidth 15], 'HandleVisibility','off', 'BackgroundColor',bgcolor); horiz_orig = horiz_orig + 15 + padU;
  function set_max_gray(hObject,eventdata) % callback for h_slider_max_gray
    plot_params.max_gray = get(hObject, 'Value');
    if plot_params.yes_gray, my_colormap('my_gray',1,plot_params.thresh_gray,plot_params.max_gray); end
  end
  
  
  if ~ischar(sigproc_params.ms_framespec_gram), error('sorry: we only support named ms_framespecs right now'); end
  initial_pulldown_value = strmatch(sigproc_params.ms_framespec_gram,all_ms_framespecs.name); if isempty(initial_pulldown_value), initial_pulldown_value = 1; end
  h_pulldown_ms_framespec_gram = uicontrol('Style','popupmenu', 'String',framespec_choice_str, 'Value',initial_pulldown_value, ...
                             'Position',[padL horiz_orig colwidth 20], 'HandleVisibility','off', 'Callback',@set_ms_framespec_gram); horiz_orig = horiz_orig + 15 + padUinter;
  h_text_ms_framespec_gram = uicontrol('Style','text', 'String','gram', 'FontWeight','bold', ...
                             'Position',[padL horiz_orig colwidth 15], 'HandleVisibility','off', 'BackgroundColor',bgcolor); horiz_orig = horiz_orig + 15 + padUinter;
  last_sigproc_params.ms_framespec_gram = sigproc_params.ms_framespec_gram;
  function set_ms_framespec_gram(hObject,eventdata) % callback for h_pulldown_ms_framespec_gram
    sigproc_params.ms_framespec_gram = all_ms_framespecs.name{get(h_pulldown_ms_framespec_gram,'Value')};
    set_alert4calcFx_if_true(~strcmp(last_sigproc_params.ms_framespec_gram,sigproc_params.ms_framespec_gram));
  end
  if ~ischar(sigproc_params.ms_framespec_form), error('sorry: we only support named ms_framespecs right now'); end
  initial_pulldown_value = strmatch(sigproc_params.ms_framespec_form,all_ms_framespecs.name); if isempty(initial_pulldown_value), initial_pulldown_value = 1; end
  h_pulldown_ms_framespec_form = uicontrol('Style','popupmenu', 'String',framespec_choice_str, 'Value',initial_pulldown_value, ...
                             'Position',[padL horiz_orig colwidth 20], 'HandleVisibility','off', 'Callback',@set_ms_framespec_form); horiz_orig = horiz_orig + 15 + padUinter;
  h_text_ms_framespec_form = uicontrol('Style','text', 'String','formants', 'FontWeight','bold', ...
                             'Position',[padL horiz_orig colwidth 15], 'HandleVisibility','off', 'BackgroundColor',bgcolor); horiz_orig = horiz_orig + 15 + padUinter;
  last_sigproc_params.ms_framespec_form = sigproc_params.ms_framespec_form;
  function set_ms_framespec_form(hObject,eventdata) % callback for h_pulldown_ms_framespec_form
    sigproc_params.ms_framespec_form = all_ms_framespecs.name{get(h_pulldown_ms_framespec_form,'Value')};
    set_alert4calcFx_if_true(~strcmp(last_sigproc_params.ms_framespec_form ,sigproc_params.ms_framespec_form));
  end
  h_text_ms_framespecm = uicontrol('Style','text', 'String','ms fr/adv', 'FontWeight','bold', ...
                                   'Position',[padL horiz_orig colwidth 15], 'HandleVisibility','off', 'BackgroundColor',bgcolor); horiz_orig = horiz_orig + 15 + padU;
  
  nchoices = length(nlpc_choices);
  for ichoice = 1:nchoices
    nlpc_choice_strs{ichoice} = sprintf('%d',nlpc_choices(ichoice));
  end
  initial_pulldown_value = find(nlpc_choices == sigproc_params.nlpc); if isempty(initial_pulldown_value), initial_pulldown_value = 1; end
  h_pulldown_nlpc = uicontrol('Style','popupmenu', 'String',nlpc_choice_strs, 'Value',initial_pulldown_value, ...
                             'Position',[padL horiz_orig colwidth 20], 'HandleVisibility','off', 'Callback',@set_nlpc_choice); horiz_orig = horiz_orig + 15 + padUinter;
  h_text_nlpc     = uicontrol('Style','text', 'String','LPC order', 'FontWeight','bold', ...
                             'Position',[padL horiz_orig colwidth 15], 'HandleVisibility','off', 'BackgroundColor',bgcolor); horiz_orig = horiz_orig + 15 + padU;
  last_sigproc_params.nlpc = sigproc_params.nlpc;
  function set_nlpc_choice(hObject,eventdata) % callback for h_pulldown_nlpc
    sigproc_params.nlpc = nlpc_choices(get(h_pulldown_nlpc,'Value'));
    set_alert4calcFx_if_true(last_sigproc_params.nlpc ~= sigproc_params.nlpc)
  end

  h_edit_ampl_thresh4voicing = uicontrol('Style','edit', 'String',sigproc_params.ampl_thresh4voicing, ...
                             'Position',[padL horiz_orig colwidth 20], 'HandleVisibility','off', 'Callback',@set_edit_ampl_thresh4voicing); horiz_orig = horiz_orig + 20 + padUinter;
  h_text_ampl_thresh4voicing = uicontrol('Style','text', 'String','voice thr', 'FontWeight','bold', ...
                             'Position',[padL horiz_orig colwidth 15], 'HandleVisibility','off', 'BackgroundColor',bgcolor); horiz_orig = horiz_orig + 15 + padU;
  function set_edit_ampl_thresh4voicing(hObject,eventdata) % callback for h_edit_ampl_thresh4voicing
    set_ampl_thresh4voicing(str2num(get(h_edit_ampl_thresh4voicing,'String')));
  end
  last_sigproc_params.ampl_thresh4voicing = sigproc_params.ampl_thresh4voicing;
  function set_ampl_thresh4voicing(new_ampl_thresh4voicing)
    if ~isempty(new_ampl_thresh4voicing)
      sigproc_params.ampl_thresh4voicing = new_ampl_thresh4voicing;
      set(h_edit_ampl_thresh4voicing,'String',new_ampl_thresh4voicing);
      update_ampl_ax(  ampl_ax,wave_ax,        sigproc_params);
      set_alert4calcFx_if_true(last_sigproc_params.ampl_thresh4voicing ~= sigproc_params.ampl_thresh4voicing);
    end
  end
  
  h_button_calcFx = uicontrol('Style','pushbutton', 'String','CALC', 'FontWeight','bold', ...
                              'Position',[padL horiz_orig colwidth textbutt1line_height], 'HandleVisibility','off', 'Callback',@calcFx); horiz_orig = horiz_orig + textbutt1line_height + padU;
  normal_bgcolor = get(h_button_calcFx,'BackgroundColor');
  function calcFx(hObject,eventdata) % callback for h_button_calcFx
    update_ampl_ax(  ampl_ax,wave_ax,        sigproc_params);
    update_pitch_ax(pitch_ax,wave_ax,ampl_ax,sigproc_params);
    update_gram_ax(  gram_ax,wave_ax,ampl_ax,sigproc_params,plot_params);
    update_spec_ax(  spec_ax,gram_ax);
    last_sigproc_params = sigproc_params;
    set(h_button_calcFx,'BackgroundColor',normal_bgcolor);
    alert4calcFx = 0;
  end
  function set_alert4calcFx_if_true(yes_true)
    alert4calcFx = yes_true;
    if alert4calcFx
      set(h_button_calcFx,'BackgroundColor',[1 0 0]);
    else
      set(h_button_calcFx,'BackgroundColor',normal_bgcolor);
    end
  end
  
  marker_captured = 0;
  
  function key_press_func(src,event)
    the_ax = cur_ax_from_curpt(nax,ax);
    the_axinfo = get(the_ax,'UserData');
    if ~isempty(the_ax) && ~isempty(the_axinfo.h_tmarker_low)
      switch(event.Key)
       case 'v' % if ampl_ax, set amplitude threshold for voicing (i.e., valid formants)
         ampl_thresh4voicing = get_ampl_thresh4voicing(the_ax,nax,ax);
         set_ampl_thresh4voicing(ampl_thresh4voicing);
       case 'a' % add a user event
        add_user_event(the_ax,nax,ax);
       case 'd' % delete a user event
        delete_user_event(the_ax,nax,ax);
       case 'rightarrow' % advance tmarker_spec by one frame
	incdec_tmarker_spec(1,the_ax,my_iwavefig);
       case 'leftarrow'  % retreat tmarker_spec by one frame
	incdec_tmarker_spec(0,the_ax,my_iwavefig);
       case 'e' % expand
        expand_btw_ax_tmarkers(the_ax);
       case 'w' % widen
        widen_ax_view(the_ax);
       case 'h' % heighten
        heigthen_ax(the_ax);
       case 'u' % unheighten = reduce
        unheigthen_ax(the_ax);
       case 'c' % shortcut for "continue" button
        contprogram([],[]);
       case 'm' % mark me for tying to some other wavefig
	mark_wavefig4tying(my_iwavefig);
       case 't' % tie me to the wavefig marked for tying
	iwavefig2tie = find_wavefig4tying();
	if iwavefig2tie
	  if iwavefig2tie == my_iwavefig
	    wavefig(my_iwavefig).marked4tying = 0;
	  else
	    tie_wavefig4tying(my_iwavefig,iwavefig2tie);
	    tie_wavefig4tying(iwavefig2tie,my_iwavefig);
	  end
	end
       case 'b' % break my ties to all other wavefigs
	untie_wavefig(my_iwavefig);
       otherwise
	fprintf('len(%d)\n',length(event.Key));
	fprintf('%d,',event.Key);
	fprintf('\n');
	fprintf('%c',event.Key);
	fprintf('\n');
      end
    end
  end
    
  function delete_func(src,event)
    iaxfr = 0;
    viewer_end_state.spec_axinfo  = get(spec_ax,'UserData');  iaxfr = iaxfr + 1; [axfracts.x(iaxfr),axfracts.y(iaxfr)] = get_axfract(spec_ax);
    viewer_end_state.ampl_axinfo  = get(ampl_ax,'UserData');  iaxfr = iaxfr + 1; [axfracts.x(iaxfr),axfracts.y(iaxfr)] = get_axfract(ampl_ax);
    viewer_end_state.pitch_axinfo = get(pitch_ax,'UserData'); iaxfr = iaxfr + 1; [axfracts.x(iaxfr),axfracts.y(iaxfr)] = get_axfract(pitch_ax);
    viewer_end_state.gram_axinfo  = get(gram_ax,'UserData');  iaxfr = iaxfr + 1; [axfracts.x(iaxfr),axfracts.y(iaxfr)] = get_axfract(gram_ax);
    viewer_end_state.wave_axinfo  = get(wave_ax,'UserData');  iaxfr = iaxfr + 1; [axfracts.x(iaxfr),axfracts.y(iaxfr)] = get_axfract(wave_ax);
    axfracts.n = iaxfr;
    plot_params.axfracts = axfracts;
    is_good_trial = event_params.is_good_trial;
    event_params = viewer_end_state.wave_axinfo.event_params;
    event_params.is_good_trial = is_good_trial;

    
    viewer_end_state.sigproc_params = sigproc_params;
    viewer_end_state.plot_params = plot_params;
    viewer_end_state.event_params = event_params;
    if exist('my_iwavefig','var')
      remove_wavefig(my_iwavefig);
    end
  end

  function capture_tmarker(src,event)
    cur_axinfo = get(cur_ax,'UserData');
    marker_captured = 0;
    switch(get(src,'SelectionType'))
     case 'normal'
      cur_ax = cur_ax_from_curpt(nax,ax);
      if ~isempty(cur_ax) && ~isempty(cur_axinfo.h_tmarker_low)
        h_captured_tmarker = capture_ax_tmarker(cur_ax);
        set(src,'WindowButtonMotionFcn',@move_tmarker);
	marker_captured = 1;
      end
    end
    function move_tmarker(src,event)      
      move_tmarker2ax_curpt(cur_ax,h_captured_tmarker);
    end
  end
  
  function release_tmarker(src,event)
    cur_axinfo = get(cur_ax,'UserData');
    if marker_captured
      [t_low,t_spec,t_hi] = get_ax_tmarker_times(cur_ax);
      if t_spec < t_low || t_spec > t_hi
	t_spec = (t_low + t_hi)/2;
      end  
      if ~(cur_axinfo.i == get_ax_i(spec_ax))
        update_ax_tmarkers(wave_ax,t_low,t_spec,t_hi);
        update_ax_tmarkers(gram_ax,t_low,t_spec,t_hi);
        update_ax_tmarkers(pitch_ax,t_low,t_spec,t_hi);
        update_ax_tmarkers(ampl_ax,t_low,t_spec,t_hi);
        update_spec_ax(spec_ax,gram_ax);
      end
      update_tied_wavefigs(my_iwavefig);
      marker_captured = 0;
    end
    set(src,'WindowButtonMotionFcn',@set_current_ax);
  end
  
  function set_current_ax(src,event)
    cur_ax = cur_ax_from_curpt(nax,ax);
  end

  function heigthen_ax(ax2heighten);
    iax2heighten = get_iax(ax2heighten,ax,nax);
    heighten_iax(iax2heighten,ax,nax);
  end

  function unheigthen_ax(ax2heighten);
    iax2heighten = get_iax(ax2heighten,ax,nax);
    unheighten_iax(iax2heighten,ax,nax);
  end
  
  function fig_resize_func(src,event)
    plot_params.figpos = get(hf,'Position');
    reposition_ax(ax,nax);
  end
  
  set(hf,'WindowButtonDownFcn',@capture_tmarker);
  set(hf,'WindowButtonUpFcn',@release_tmarker);
  set(hf,'WindowButtonMotionFcn',@set_current_ax);
  set(hf,'KeyPressFcn',@key_press_func);
  set(hf,'ResizeFcn',@fig_resize_func);
  if yes_profile, profile off; end
  if yes_start_blocking, uiwait(hf); end
end

% ax creation/update stuff

function wave_ax = new_wave_ax(y,sigproc_params,plot_params,event_params)
  [row_y,col_y] = size(y);
  if row_y > 1
    if col_y > 1, error('cannot currently handle signals that are matrices');
    else, y = y'; % make y a row vector if it was a column vector
    end
  end
  fs = sigproc_params.fs;
  name = plot_params.name;
  
  axdat{1} = y;
  params{1}.taxis = (0:(length(y)-1))/fs;
  params{1}.fs = fs;
  params{1}.player_started = 0;
  params{1}.start_player_t = 0;
  params{1}.stop_player_t = 0;
  params{1}.current_player_t = 0;
  params{1}.inc_player_t = 0.01;
  h_player = audioplayer(0.5*y/max(abs(y)),fs); % the scaling of y is a bit of a hack to make audioplayer play like soundsc
  params{1}.h_player = h_player;
  params{1}.isamps2play_total = get(h_player,'TotalSamples');
  set(h_player,'StartFcn',@player_start);
  set(h_player,'StopFcn',@player_stop);
  set(h_player,'TimerFcn',@player_runfunc);
  set(h_player,'TimerPeriod',params{1}.inc_player_t);

  wave_ax = axes();
  set(params{1}.h_player,'UserData',wave_ax);
  axinfo = new_axinfo('wave',params{1}.taxis,[],axdat,wave_ax,[],name,params{1}.taxis(1),params{1}.taxis(end),params,event_params);
  set(wave_ax,'UserData',axinfo);
end

function update_wave_ax_tlims_from_gram_ax(wave_ax,gram_ax)
  wave_axinfo = get(wave_ax,'UserData');
  gram_axinfo = get(gram_ax,'UserData');
  t_min = gram_axinfo.t_llim;
  t_max = gram_axinfo.t_hlim;
  t_range = t_max - t_min;
  the_axdat = wave_axinfo.dat{1};
  hax = wave_axinfo.h;
  set_viewer_axlims(hax,t_min,t_max,the_axdat);
  wave_axinfo.t_llim = t_min;
  wave_axinfo.t_hlim = t_max;
  set(wave_ax,'UserData',wave_axinfo);
  update_tmarker(wave_axinfo.h_tmarker_low,[]);
  update_tmarker(wave_axinfo.h_tmarker_spec,[]);
  update_tmarker(wave_axinfo.h_tmarker_hi,[]);
  set(wave_ax,'UserData',wave_axinfo);
end

function ampl_ax = new_ampl_ax(wave_ax,sigproc_params)
  wave_axinfo = get(wave_ax,'UserData');
  fs = wave_axinfo.params{1}.fs;
  y = wave_axinfo.dat{1};
  ampl_thresh4voicing = sigproc_params.ampl_thresh4voicing;

  [axdat{1},params{1}] = make_ampl_axdat(y,fs);

  ampl_ax = axes();
  axinfo = new_axinfo('ampl',params{1}.taxis,[],axdat,ampl_ax,[],wave_axinfo.name,params{1}.taxis(1),params{1}.taxis(end),params,wave_axinfo.event_params);
  axinfo.hl_ampl_thresh4voicing = set_ampl_thresh4voicing_line(ampl_thresh4voicing,axinfo,[]);
  set(ampl_ax,'UserData',axinfo);
end

function update_ampl_ax(ampl_ax,wave_ax,sigproc_params)
  wave_axinfo = get(wave_ax,'UserData');
  t_min = wave_axinfo.t_llim;
  t_max = wave_axinfo.t_hlim;
  fs = wave_axinfo.params{1}.fs;
  y = wave_axinfo.dat{1};
  ampl_thresh4voicing = sigproc_params.ampl_thresh4voicing;
  old_ampl_axinfo = get(ampl_ax,'UserData');
  old_hl_ampl_thresh4voicing = old_ampl_axinfo.hl_ampl_thresh4voicing;
  
  [axdat{1},params{1}] = make_ampl_axdat(y,fs);
  
  ampl_axinfo = get(ampl_ax,'UserData');
  ampl_axinfo.dat = axdat;
  ampl_axinfo.datlims = size(axdat{1});
  ampl_axinfo.params = params;
  ampl_axinfo.taxis = params{1}.taxis;
  set(ampl_axinfo.hply(1),'XData',params{1}.taxis);
  set(ampl_axinfo.hply(1),'YData',axdat{1});
  set_viewer_axlims(ampl_ax,t_min,t_max,axdat{1});
  ampl_axinfo.hl_ampl_thresh4voicing = set_ampl_thresh4voicing_line(ampl_thresh4voicing,ampl_axinfo,old_hl_ampl_thresh4voicing);
  set(ampl_ax,'UserData',ampl_axinfo);
  update_tmarker(ampl_axinfo.h_tmarker_low,[]);
  update_tmarker(ampl_axinfo.h_tmarker_spec,[]);
  update_tmarker(ampl_axinfo.h_tmarker_hi,[]);
  set(ampl_ax,'UserData',ampl_axinfo);
end

function [the_axdat,the_params] = make_ampl_axdat(y,fs)
  yampl = get_sig_ampl(y,fs);
  the_axdat = yampl;
  len_yampl = length(yampl);
  ampl_taxis = (0:(len_yampl-1))/fs;
  the_params.fs = fs;
  the_params.taxis = ampl_taxis;
end

function  hl_ampl_thresh4voicing = set_ampl_thresh4voicing_line(ampl_thresh4voicing,ampl_axinfo,old_hl_ampl_thresh4voicing)
  ylim = get(ampl_axinfo.h,'YLim');
  if ylim(1) <= ampl_thresh4voicing && ampl_thresh4voicing < ylim(2)
    yes_inrange2plot = 1;
  else
    yes_inrange2plot = 0;
  end
  if isempty(old_hl_ampl_thresh4voicing)
    if yes_inrange2plot
      hl_ampl_thresh4voicing = hline(ampl_thresh4voicing,'r');
      set(hl_ampl_thresh4voicing,'Visible','on');
    else
      hl_ampl_thresh4voicing = hline(mean(ylim),'r');
      set(hl_ampl_thresh4voicing,'Visible','off');
    end
  else
    hl_ampl_thresh4voicing = old_hl_ampl_thresh4voicing;
    if yes_inrange2plot
      set(hl_ampl_thresh4voicing,'YData',ampl_thresh4voicing*[1 1]);
      set(hl_ampl_thresh4voicing,'Visible','on');
    else
      set(hl_ampl_thresh4voicing,'YData',mean(ylim)*[1 1]);
      set(hl_ampl_thresh4voicing,'Visible','off');
    end
  end
end

function pitch_ax = new_pitch_ax(wave_ax,ampl_ax,sigproc_params)
  wave_axinfo = get(wave_ax,'UserData');
  ampl_axinfo = get(ampl_ax,'UserData');
  fs = wave_axinfo.params{1}.fs;
  y = wave_axinfo.dat{1};

  pitchlimits = sigproc_params.pitchlimits;
  ampl_thresh4voicing = sigproc_params.ampl_thresh4voicing;
  
  thresh4voicing_spec.ampl = ampl_axinfo.dat{1};
  thresh4voicing_spec.ampl_taxis = ampl_axinfo.params{1}.taxis;
  thresh4voicing_spec.ampl_thresh4voicing = ampl_thresh4voicing;
  [axdat{1},params{1}] = make_pitch_axdat(y,fs,pitchlimits,thresh4voicing_spec);

  pitch_ax = axes();
  axinfo = new_axinfo('pitch',params{1}.taxis,[],axdat,pitch_ax,[],wave_axinfo.name,params{1}.taxis(1),params{1}.taxis(end),params,wave_axinfo.event_params);
  set(pitch_ax,'UserData',axinfo);
end

function  update_pitch_ax(pitch_ax,wave_ax,ampl_ax,sigproc_params)
  wave_axinfo = get(wave_ax,'UserData');
  ampl_axinfo = get(ampl_ax,'UserData');
  t_min = wave_axinfo.t_llim;
  t_max = wave_axinfo.t_hlim;
  fs = wave_axinfo.params{1}.fs;
  y = wave_axinfo.dat{1};

  pitchlimits = sigproc_params.pitchlimits;
  ampl_thresh4voicing = sigproc_params.ampl_thresh4voicing;

  thresh4voicing_spec.ampl = ampl_axinfo.dat{1};
  thresh4voicing_spec.ampl_taxis = ampl_axinfo.params{1}.taxis;
  thresh4voicing_spec.ampl_thresh4voicing = ampl_thresh4voicing;
  [axdat{1},params{1}] = make_pitch_axdat(y,fs,pitchlimits,thresh4voicing_spec);

  pitch_axinfo = get(pitch_ax,'UserData');
  pitch_axinfo.dat = axdat;
  pitch_axinfo.datlims = size(axdat{1});
  pitch_axinfo.params = params;
  pitch_axinfo.taxis = params{1}.taxis;
  set(pitch_axinfo.hply(1),'XData',params{1}.taxis);
  set(pitch_axinfo.hply(1),'YData',axdat{1});
  set_viewer_axlims(pitch_ax,t_min,t_max,axdat{1});
  set(pitch_ax,'UserData',pitch_axinfo);
  update_tmarker(pitch_axinfo.h_tmarker_low,[]);
  update_tmarker(pitch_axinfo.h_tmarker_spec,[]);
  update_tmarker(pitch_axinfo.h_tmarker_hi,[]);
  set(pitch_ax,'UserData',pitch_axinfo);
end

function [the_axdat,the_params] = make_pitch_axdat(y,fs,pitchlimits,thresh4voicing_spec)
  [ypitch,window_size,frame_step,nframes] = get_sig_pitch(y,fs,pitchlimits);
  len_ypitch = length(ypitch);
  pitch_taxis = (0:(len_ypitch-1))/fs;
  ampl4pitch = interp1(thresh4voicing_spec.ampl_taxis,thresh4voicing_spec.ampl,pitch_taxis);
  ypitch(ampl4pitch < thresh4voicing_spec.ampl_thresh4voicing) = NaN;
  the_axdat = ypitch;
  the_params.fs = fs;
  the_params.pitchlimits = pitchlimits;
  the_params.taxis = pitch_taxis;
end

function gram_ax = new_gram_ax(wave_ax,ampl_ax,sigproc_params,plot_params)
  wave_axinfo = get(wave_ax,'UserData');
  ampl_axinfo = get(ampl_ax,'UserData');
  fs = wave_axinfo.params{1}.fs;
  y = wave_axinfo.dat{1};
  
  yes_gray = plot_params.yes_gray;
  thresh_gray = plot_params.thresh_gray;
  max_gray = plot_params.max_gray;
  hzbounds4plot = plot_params.hzbounds4plot;
  ms_framespec_gram = sigproc_params.ms_framespec_gram;
  ms_framespec_form = sigproc_params.ms_framespec_form;
  nfft = sigproc_params.nfft;
  nlpc = sigproc_params.nlpc;
  nformants = sigproc_params.nformants;
  preemph = sigproc_params.preemph;
  ampl_thresh4voicing = sigproc_params.ampl_thresh4voicing;
  if isfield(sigproc_params,'ftrack_method')
      ftrack_method = sigproc_params.ftrack_method;
  else
      ftrack_method = 'mine2';
  end

  if yes_gray, my_colormap('my_gray',1,thresh_gray,max_gray); end

  [axdat{1},params{1}] = make_spectrogram_axdat(y,fs,ms_framespec_gram,nfft,preemph);
  thresh4voicing_spec.ampl = ampl_axinfo.dat{1};
  thresh4voicing_spec.ampl_taxis = ampl_axinfo.params{1}.taxis;
  thresh4voicing_spec.ampl_thresh4voicing = ampl_thresh4voicing;
  [axdat{2},params{2}] = make_ftrack_axdat(y,fs,params{1}.faxis,ms_framespec_form,nlpc,preemph,nformants,thresh4voicing_spec,ftrack_method);
  
  gram_ax = axes();
  axinfo = new_axinfo('gram',params{1}.taxis,params{1}.faxis,axdat,gram_ax,hzbounds4plot,wave_axinfo.name,params{1}.taxis(1),params{1}.taxis(end),params,wave_axinfo.event_params);
  set(gram_ax,'UserData',axinfo);
end

function update_gram_ax(gram_ax,wave_ax,ampl_ax,sigproc_params,plot_params)

  global wave_viewer_logshim

  wave_axinfo = get(wave_ax,'UserData');
  ampl_axinfo = get(ampl_ax,'UserData');
  fs = wave_axinfo.params{1}.fs;
  y = wave_axinfo.dat{1};

  hzbounds4plot = plot_params.hzbounds4plot;
  ms_framespec_gram = sigproc_params.ms_framespec_gram;
  ms_framespec_form = sigproc_params.ms_framespec_form;
  nfft = sigproc_params.nfft;
  nlpc = sigproc_params.nlpc;
  nformants = sigproc_params.nformants;
  preemph = sigproc_params.preemph;
  ampl_thresh4voicing = sigproc_params.ampl_thresh4voicing;
  if isfield(sigproc_params,'ftrack_method')
      ftrack_method = sigproc_params.ftrack_method;
  else
      ftrack_method = 'mine2';
  end
  
  [axdat{1},params{1}] = make_spectrogram_axdat(y,fs,ms_framespec_gram,nfft,preemph);
  thresh4voicing_spec.ampl = ampl_axinfo.dat{1};
  thresh4voicing_spec.ampl_taxis = ampl_axinfo.params{1}.taxis;
  thresh4voicing_spec.ampl_thresh4voicing = ampl_thresh4voicing;
  [axdat{2},params{2}] = make_ftrack_axdat(y,fs,params{1}.faxis,ms_framespec_form,nlpc,preemph,nformants,thresh4voicing_spec,ftrack_method);

  taxis = params{1}.taxis;
  faxis = params{1}.faxis;
  
  gram_axinfo = get(gram_ax,'UserData');
  gram_axinfo.dat = axdat;
  gram_axinfo.datlims = size(axdat{1});
  gram_axinfo.params = params;
  gram_axinfo.taxis = taxis;
  gram_axinfo.faxis = faxis;
  absS = axdat{1};
  absS2plot = 20*log10(absS+wave_viewer_logshim);
  set(gram_axinfo.hply(1),'CData',absS2plot);
  set(gram_axinfo.hply(1),'XData',taxis);
  set(gram_axinfo.hply(1),'YData',faxis);
  ftrack = axdat{2};
  frame_taxis_form = params{2}.taxis;
  for iformant = 1:nformants
    set(gram_axinfo.hply(iformant+1),'XData',frame_taxis_form);
    set(gram_axinfo.hply(iformant+1),'YData',ftrack(iformant,:));
  end
  set(gram_ax,'UserData',gram_axinfo);
  update_tmarker(gram_axinfo.h_tmarker_low,[]);
  update_tmarker(gram_axinfo.h_tmarker_spec,[]);
  update_tmarker(gram_axinfo.h_tmarker_hi,[]);
  set(gram_ax,'UserData',gram_axinfo);
end

function [the_axdat,the_params] = make_spectrogram_axdat(y,fs,ms_framespec,nfft,preemph)
  [absS,F,msT,window_size,frame_size] = my_specgram(y,[],fs,ms_framespec,nfft,preemph,0);
  [nchans,nframes_gram] = size(absS);
  faxis_gram = F;
  frame_taxis_gram = msT/1000;
  the_axdat = absS;
  the_params.fs = fs;
  the_params.ms_framespec = ms_framespec;
  the_params.nfft = nfft;
  the_params.preemph = preemph;
  the_params.faxis = faxis_gram;
  the_params.taxis = frame_taxis_gram;
end

function [the_axdat,the_params] = make_ftrack_axdat(y,fs,faxis,ms_framespec,nlpc,preemph,nformants,thresh4voicing_spec,ftrack_method)
  [ftrack,ftrack_msT,lpc_coeffs] = get_formant_tracks(y,fs,faxis,ms_framespec,nlpc,preemph,nformants,ftrack_method,0);
  [nforms,nframes_form] = size(ftrack);
  frame_taxis_form = ftrack_msT/1000;
  ampl4form = interp1(thresh4voicing_spec.ampl_taxis,thresh4voicing_spec.ampl,frame_taxis_form);
  for iformant = 1:nformants
    ftrack(iformant,ampl4form < thresh4voicing_spec.ampl_thresh4voicing) = NaN;
  end
  for i_lpc_coeff = 1:nlpc
    lpc_coeffs(i_lpc_coeff,ampl4form < thresh4voicing_spec.ampl_thresh4voicing) = NaN;
  end
  the_axdat = ftrack;
  the_params.fs = fs;
  the_params.ms_framespec = ms_framespec;
  the_params.nlpc = nlpc;
  the_params.nformants = nformants;
  the_params.preemph = preemph;
  the_params.faxis = faxis;
  the_params.taxis = frame_taxis_form;
  the_params.lpc_coeffs = lpc_coeffs;
end

function spec_ax = new_spec_ax(gram_ax)
  gram_axinfo = get(gram_ax,'UserData');

  t_spec = get_tmarker_time(gram_axinfo.h_tmarker_spec);

  absS = gram_axinfo.dat{1};
  frame_taxis_gram = gram_axinfo.taxis;
  faxis = gram_axinfo.faxis;

  ftrack = gram_axinfo.dat{2};
  lpc_coeffs = gram_axinfo.params{2}.lpc_coeffs;
  frame_taxis_form = gram_axinfo.params{2}.taxis;
  fs = gram_axinfo.params{2}.fs;

  [axdat{1},params{1}] = make_gram_spec_axdat(absS,frame_taxis_gram,faxis,t_spec);
  [axdat{2},params{2}] = make_form_spec_axdat(ftrack,lpc_coeffs,frame_taxis_form,faxis,fs,t_spec);

  spec_ax = axes();
  axinfo = new_axinfo('spec',params{1}.taxis,[],axdat,spec_ax,[],gram_axinfo.name,params{1}.taxis(1),params{1}.taxis(end),params,gram_axinfo.event_params);
  set(spec_ax,'UserData',axinfo);
  update_spec_ax(spec_ax,gram_ax);
end

function update_spec_ax(spec_ax,gram_ax)
  global tmarker_init_border
  global axborder_xl axborder_xr axborder_yl axborder_yu
  global figborder_xl figborder_xr figborder_yl figborder_yu
  global ax_heighten_inc
  global wave_viewer_logshim

  gram_axinfo = get(gram_ax,'UserData');
  spec_axinfo = get(spec_ax,'UserData');

  t_spec = get_tmarker_time(gram_axinfo.h_tmarker_spec);

  absS = gram_axinfo.dat{1};
  frame_taxis_gram = gram_axinfo.taxis;
  faxis = gram_axinfo.faxis;
  
  ftrack = gram_axinfo.dat{2};
  lpc_coeffs = gram_axinfo.params{2}.lpc_coeffs;
  frame_taxis_form = gram_axinfo.params{2}.taxis;
  fs = gram_axinfo.params{2}.fs;

  [axdat{1},params{1}] = make_gram_spec_axdat(absS,frame_taxis_gram,faxis,t_spec);
  [axdat{2},params{2}] = make_form_spec_axdat(ftrack,lpc_coeffs,frame_taxis_form,faxis,fs,t_spec);

  spec_axinfo.dat = axdat;
  spec_axinfo.datlims = size(axdat{1});
  spec_axinfo.params = params;

  update_spec_plots(spec_axinfo.h,spec_axinfo.hply,axdat,params);

  set(spec_axinfo.htitl,'String',sprintf('frame(%d), %.2fsec:',params{1}.iframe,t_spec));
  set(spec_ax,'UserData',spec_axinfo);
  [t_low,t_spec,t_hi] = get_ax_tmarker_times(spec_ax);
  update_tmarker(spec_axinfo.h_tmarker_low, t_low);
  update_tmarker(spec_axinfo.h_tmarker_spec, t_spec);
  update_tmarker(spec_axinfo.h_tmarker_hi,  t_hi);
  set(spec_ax,'UserData',spec_axinfo);
end

function [the_axdat,the_params] = make_gram_spec_axdat(absS,frame_taxis_gram,faxis_gram,t_spec)
  iframe_gram = dsearchn(frame_taxis_gram',t_spec);
  gram_frame_spec = absS(:,iframe_gram)';

  the_axdat = gram_frame_spec;
  the_params.iframe = iframe_gram;
  the_params.taxis = faxis_gram';
end  

function [the_axdat,the_params] = make_form_spec_axdat(ftrack,lpc_coeffs,frame_taxis_form,faxis_form,fs,t_spec)
  
  iframe_form = dsearchn(frame_taxis_form',t_spec);
  form_frame_formants = ftrack(:,iframe_form);
  form_frame_lpc_spec = get_lpc_magspec(lpc_coeffs(:,iframe_form),faxis_form,fs)';
  
  the_axdat = form_frame_lpc_spec;
  the_params.iframe = iframe_form;
  the_params.taxis = faxis_form';
  the_params.formants = form_frame_formants;
end

function update_spec_plots(hax,hply,axdat,params)
  global formant_colors formant_marker_width
  
  min_axdat1 = min(axdat{1}); max_axdat1 = max(axdat{1});
  range_axdat1 = max_axdat1 - min_axdat1;
  norm_axdat{1} = (axdat{1} - min_axdat1)/range_axdat1;

  min_axdat2 = min(axdat{2}); max_axdat2 = max(axdat{2});
  range_axdat2 = max_axdat2 - min_axdat2;
  norm_axdat{2} = (axdat{2} - min_axdat2)/range_axdat2;
  
  haxlims = axis(hax);
  t_min = haxlims(1); t_max = haxlims(2); t_range = t_max - t_min;
  dat4minmax = [norm_axdat{1} norm_axdat{2}];
  set_viewer_axlims(hax,t_min,t_max,dat4minmax);
  haxlims = axis(hax);
  set(hply(1),'YData',norm_axdat{1}); set(hply(1),'Color','b');
  set(hply(2),'YData',norm_axdat{2}); set(hply(2),'Color','r');
  formant = params{2}.formants;
  nformants = length(formant);
  for iformant = 1:nformants
    formant_freq = formant(iformant);
    iformant_freq = dsearchn(params{2}.taxis',formant_freq);
    formant_ampl = norm_axdat{2}(iformant_freq);
    set(hply(iformant+2),'XData',formant_freq*[1 1]);
    set(hply(iformant+2),'YData',[haxlims(3) formant_ampl]);
    set(hply(iformant+2),'Color',formant_colors{iformant});
    set(hply(iformant+2),'LineWidth',formant_marker_width);
    h_formant_name = get(hply(iformant+2),'UserData');
    set(h_formant_name,'Position',[formant_freq formant_ampl 0]);
    set(h_formant_name,'FontWeight','bold');
    set(h_formant_name,'VerticalAlignment','top');
  end
end

function axinfo = new_axinfo(axtype,taxis,faxis,axdat,hax,hzbounds4plot,name,t_min,t_max,params,event_params)

  global tmarker_init_border
  global wave_viewer_logshim
  global formant_colors

  t_range = t_max - t_min;
  
  axinfo.i = 0;
  axinfo.type = axtype;
  axinfo.name = name;
  axinfo.dat = axdat;
  axinfo.datlims = size(axdat{1});
  axinfo.params = params;
  axinfo.taxis = taxis;
  axinfo.faxis = faxis;
  
  switch axinfo.type
    case 'wave'
      hply(1) = plot(taxis,axdat{1});
      titlstr = sprintf('waveform(%s): %.1f sec, %d samples',name,t_range,axinfo.datlims(2));
      hxlab = xlabel('Time (sec)');
      hylab = ylabel('ampl');
      set_viewer_axlims(hax,t_min,t_max,axdat{1});
      yes_tmarker_play = 1;
      yes_add_user_events = 1;
      spec_marker_name.name = ' %.3f s ';
      spec_marker_name.vert_align = 'top';
      spec_marker_name.bgrect.color = 'same';
    case 'gram'
      absS = axdat{1};
      gram_params = params{1};
      absS2plot = 20*log10(absS+wave_viewer_logshim);
      hply(1) = imagesc(taxis,faxis,absS2plot);
      set(hax,'YDir','normal');
      
      ftrack = axdat{2};
      ftrack_params = params{2};
      nformants = ftrack_params.nformants;
      frame_taxis_form = ftrack_params.taxis;
      hold on
      for iformant = 1:nformants
        hply(iformant+1) = plot(frame_taxis_form,ftrack(iformant,:),formant_colors{iformant});
        set(hply(iformant+1),'LineWidth',3);
      end
      hold off

      titlstr = sprintf('spectrogram(%s): %.1f sec, %d frames',name,t_range,axinfo.datlims(2));
      hxlab = xlabel('Time (sec)');
      hylab = ylabel('Hz');
      set_viewer_axlims(hax,t_min,t_max,hzbounds4plot,0);
      yes_tmarker_play = 0;
      yes_add_user_events = 1;

      for iformant = 1:nformants
        spec_marker_name(iformant).name = ' %.0f Hz ';
        spec_marker_name(iformant).vert_align = 'top';
        spec_marker_name(iformant).idatsources = [2];
        spec_marker_name(iformant).iidatsource4ypos = 1;
        spec_marker_name(iformant).idatrows = iformant;
        spec_marker_name(iformant).bgrect.color = 'same';
      end
    case 'pitch'
      hply(1) = plot(taxis,axdat{1});
      titlstr = sprintf('pitch(%s): %.1f sec, %d samples',name,t_range,axinfo.datlims(2));
      hxlab = xlabel('Time (sec)');
      hylab = ylabel('Hz');
      set_viewer_axlims(hax,t_min,t_max,axdat{1});
      yes_tmarker_play = 0;
      yes_add_user_events = 1;
      spec_marker_name.name = ' %.0f Hz ';
      spec_marker_name.vert_align = 'top';
      spec_marker_name.idatsources = [1];
      spec_marker_name.bgrect.color = 'same';
    case 'ampl'
      hply(1) = plot(taxis,axdat{1});
      titlstr = sprintf('ampl(%s): %.1f sec, %d samples',name,t_range,axinfo.datlims(2));
      hxlab = xlabel('Time (sec)');
      hylab = ylabel('ampl');
      set_viewer_axlims(hax,t_min,t_max,axdat{1});
      yes_tmarker_play = 0;
      yes_add_user_events = 1;
      spec_marker_name.name = ' %.2f ';
      spec_marker_name.vert_align = 'top';
      spec_marker_name.idatsources = [1];
      spec_marker_name.bgrect.color = 'same';
    case 'spec'
      % first, do some dummy plotting to create the hlpy's
      hply(1) = plot(taxis,axdat{1});
      hold on;
      hply(2) = plot(taxis,axdat{2});
      formant = params{2}.formants;
      nformants = length(formant);
      for iformant = 1:nformants
        hply(iformant+2) = line(formant(iformant)*[1 1],[0 1]);
        h_formant_name = text(t_min,0,sprintf(' F%d',iformant));
        set(hply(iformant+2),'UserData',h_formant_name);
      end
      set_viewer_axlims(hax,t_min,t_max,[0 1],0);
      hold off

      % then do the real plotting
      update_spec_plots(hax,hply,axdat,params);
      
      titlstr = 'you should never see this';
      hxlab = xlabel('Hz');
      hylab = ylabel('ampl');
      
      yes_tmarker_play = 0;
      yes_add_user_events = 0;
      spec_marker_name.name = ' %.0f Hz ';
      spec_marker_name.vert_align = 'top';
      spec_marker_name.bgrect.color = 'same';
    otherwise
      error('axtype(%d) not recognized',axinfo.type);
  end
  hold on;
  axinfo.h = hax;
  axinfo.hply = hply;
  axinfo.hxlab = hxlab;
  axinfo.hylab = hylab;
  set(hax,'UserData',axinfo); % potentially need this for setting up tmarkers below

  axinfo.htitl = title(titlstr);
  set(axinfo.htitl,'FontWeight','bold');
  set(axinfo.htitl,'Units','normalized');
  titlpos = get(axinfo.htitl,'Position');
  set(axinfo.htitl,'Position',[0 titlpos(2:3)]);
  set(axinfo.htitl,'HorizontalAlignment','left');

  if ~isempty(event_params.event_names)
    nevents = length(event_params.event_names);
    axinfo.event_params.event_names = event_params.event_names;
    if length(event_params.event_times) ~= nevents, error('# of event_times(%d) ~= # of event names(%d)',length(event_params.event_times),nevents); end
    axinfo.event_params.event_times = event_params.event_times;
    for ievent = 1:nevents
      h_tmarker_event(ievent) = make_tmarker(hax,'m-',event_params.event_names{ievent}); update_tmarker(h_tmarker_event(ievent),event_params.event_times(ievent));
    end
    axinfo.nevents = nevents;
    axinfo.h_tmarker_event = h_tmarker_event;
  else
    axinfo.nevents = 0;
    axinfo.event_params.event_names = [];
    axinfo.event_params.event_times = [];
    axinfo.h_tmarker_event = [];
  end
  axinfo.yes_add_user_events = yes_add_user_events;
  axinfo.event_params.user_event_name_prefix = event_params.user_event_name_prefix;
  if yes_add_user_events && ~isempty(event_params.user_event_names)
    n_user_events = length(event_params.user_event_names);
    axinfo.event_params.user_event_names = event_params.user_event_names;
    if length(event_params.user_event_times) ~= n_user_events, error('# of user_event_times(%d) ~= # of user_event names(%d)',length(event_params.user_event_times),n_user_events); end
    axinfo.event_params.user_event_times = event_params.user_event_times;
    for i_user_event = 1:n_user_events
      h_tmarker_user_event(i_user_event) = make_tmarker(hax,'c-',event_params.user_event_names{i_user_event}); update_tmarker(h_tmarker_user_event(i_user_event),event_params.user_event_times(i_user_event));
    end
    axinfo.n_user_events = n_user_events;
    axinfo.h_tmarker_user_event = h_tmarker_user_event;
  else
    axinfo.n_user_events = 0;
    axinfo.event_params.user_event_names = [];
    axinfo.event_params.user_event_times = [];
    axinfo.h_tmarker_user_event = [];
  end
  h_tmarker_low = make_tmarker(hax,'g-'); update_tmarker(h_tmarker_low, t_min + tmarker_init_border*t_range);
  h_tmarker_spec = make_tmarker(hax,'y-',spec_marker_name); update_tmarker(h_tmarker_spec, t_min + t_range/2);
  h_tmarker_hi = make_tmarker(hax,'r-');  update_tmarker(h_tmarker_hi,  t_max - tmarker_init_border*t_range);
  if yes_tmarker_play
    h_tmarker_play = make_tmarker(hax,'c-',[],[],0); update_tmarker(h_tmarker_play, t_min + tmarker_init_border*t_range);
  else
    h_tmarker_play = [];
  end
  axinfo.h_tmarker_low = h_tmarker_low;
  axinfo.h_tmarker_spec = h_tmarker_spec;
  axinfo.h_tmarker_hi  = h_tmarker_hi;
  axinfo.h_tmarker_play = h_tmarker_play;
  
  axinfo.t_llim = t_min;
  axinfo.t_hlim = t_max;
end

function update_tied_wavefigs(my_iwavefig)
  global wavefig nwavefigs
  my_wavefig_idx = get_wavefig_idx(my_iwavefig);
  [wave_ax,gram_ax,pitch_ax,ampl_ax,spec_ax] = get_ax_from_wavefig(my_wavefig_idx);
  [wave_t_low,wave_t_spec,wave_t_hi] = get_ax_tmarker_times(wave_ax);
  [gram_t_low,gram_t_spec,gram_t_hi] = get_ax_tmarker_times(gram_ax);
  [pitch_t_low,pitch_t_spec,pitch_t_hi] = get_ax_tmarker_times(pitch_ax);
  [ampl_t_low,ampl_t_spec,ampl_t_hi] = get_ax_tmarker_times(ampl_ax);
  [spec_t_low,spec_t_spec,spec_t_hi] = get_ax_tmarker_times(spec_ax);
  ntied2figs = wavefig(my_wavefig_idx).ntied2figs;
  tied2fig = wavefig(my_wavefig_idx).tied2fig;
  for iiwavefig = 1:ntied2figs
    wavefig_idx = get_wavefig_idx(tied2fig(iiwavefig));
    [wave_ax,gram_ax,pitch_ax,ampl_ax,spec_ax] = get_ax_from_wavefig(wavefig_idx);
    update_ax_tmarkers(wave_ax,wave_t_low,wave_t_spec,wave_t_hi);
    update_ax_tmarkers(gram_ax,gram_t_low,gram_t_spec,gram_t_hi);
    update_ax_tmarkers(pitch_ax,pitch_t_low,pitch_t_spec,pitch_t_hi);
    update_ax_tmarkers(ampl_ax,ampl_t_low,ampl_t_spec,ampl_t_hi);
    update_ax_tmarkers(spec_ax,spec_t_low,spec_t_spec,spec_t_hi);
    update_spec_ax(spec_ax,gram_ax);
  end
end

function incdec_tmarker_spec(yes_inc,the_ax,my_iwavefig)
  the_axinfo = get(the_ax,'UserData');
  my_wavefig_idx = get_wavefig_idx(my_iwavefig);
  [wave_ax,gram_ax,pitch_ax,ampl_ax,spec_ax] = get_ax_from_wavefig(my_wavefig_idx);
  [t_low,t_spec,t_hi] = get_ax_tmarker_times(the_ax);
  t_spec = incdec_t_spec(yes_inc,t_low,t_spec,t_hi,the_ax);
  switch the_axinfo.type
    case 'spec'
      update_ax_tmarkers(spec_ax,t_low,t_spec,t_hi);
    otherwise
      update_ax_tmarkers(wave_ax,t_low,t_spec,t_hi);
      update_ax_tmarkers(gram_ax,t_low,t_spec,t_hi);
      update_ax_tmarkers(pitch_ax,t_low,t_spec,t_hi);
      update_ax_tmarkers(ampl_ax,t_low,t_spec,t_hi);
      update_spec_ax(spec_ax,gram_ax);
  end
  update_tied_wavefigs(my_iwavefig);
end

function [wave_ax,gram_ax,pitch_ax,ampl_ax,spec_ax] = get_ax_from_wavefig(wavefig_idx)
  global wavefig
  wave_ax = wavefig(wavefig_idx).ax(wavefig(wavefig_idx).i_wave_ax);
  gram_ax = wavefig(wavefig_idx).ax(wavefig(wavefig_idx).i_gram_ax);
  pitch_ax = wavefig(wavefig_idx).ax(wavefig(wavefig_idx).i_pitch_ax);
  ampl_ax = wavefig(wavefig_idx).ax(wavefig(wavefig_idx).i_ampl_ax);
  spec_ax = wavefig(wavefig_idx).ax(wavefig(wavefig_idx).i_spec_ax);
end  

% audioplayer callback functions

function play_from_wave_ax(wave_ax)
  [start_player_t,duh,stop_player_t] = get_ax_tmarker_times(wave_ax);
  wave_axinfo = get(wave_ax,'UserData');
  fs = wave_axinfo.params{1}.fs;
  isamps2play_total = wave_axinfo.params{1}.isamps2play_total;
  h_player = wave_axinfo.params{1}.h_player;
  current_player_t = start_player_t;
  isamps2play_start = round(fs*start_player_t); if isamps2play_start < 1, isamps2play_start = 1; end
  isamps2play_stop  = round(fs*stop_player_t);   if isamps2play_stop  > isamps2play_total, isamps2play_stop  = isamps2play_total; end
  isamps2play = [isamps2play_start isamps2play_stop];
  wave_axinfo.params{1}.current_player_t = current_player_t;
  set(wave_ax,'UserData',wave_axinfo);
  playblocking(h_player,isamps2play);
end

function player_start(hObject,eventdata)
  wave_ax = get(hObject,'UserData');
  wave_axinfo = get(wave_ax,'UserData');
  h_tmarker_play = wave_axinfo.h_tmarker_play;
  current_player_t = wave_axinfo.params{1}.current_player_t;
  update_tmarker(h_tmarker_play,current_player_t);
  set(h_tmarker_play,'Visible','on');
  wave_axinfo.params{1}.player_started = 0;
  set(wave_ax,'UserData',wave_axinfo);
  % fprintf('player started\n');
end

function player_stop(hObject,eventdata)
  wave_ax = get(hObject,'UserData');
  wave_axinfo = get(wave_ax,'UserData');
  h_tmarker_play = wave_axinfo.h_tmarker_play;
  update_tmarker(h_tmarker_play,get_tmarker_time(wave_axinfo.h_tmarker_low));
  set(h_tmarker_play,'Visible','off');
  % fprintf('player stopped\n');
end

function player_runfunc(hObject,eventdata)
  wave_ax = get(hObject,'UserData');
  wave_axinfo = get(wave_ax,'UserData');
  fs = wave_axinfo.params{1}.fs;
  player_started = wave_axinfo.params{1}.player_started;
  [start_player_t,duh,stop_player_t] = get_ax_tmarker_times(wave_ax);
  isamp_playing = get(hObject,'CurrentSample');
  current_player_t = isamp_playing/fs;
  if current_player_t < start_player_t
    if ~player_started
      current_player_t = start_player_t;
    else
      current_player_t = stop_player_t;
    end
  else
    player_started = 1;
  end
  wave_axinfo.params{1}.player_started = player_started;
  update_tmarker(wave_axinfo.h_tmarker_play,current_player_t);
  set(wave_ax,'UserData',wave_axinfo);
  % fprintf('player running(%d)\n',isamp_playing);
end

% generic ax stuff

function set_ax_i(ax,i)
  axinfo = get(ax,'UserData');
  axinfo.i = i;
  set(ax,'UserData',axinfo);
end

function i = get_ax_i(ax)
  axinfo = get(ax,'UserData');
  i = axinfo.i;
end

function new_t_spec = incdec_t_spec(yes_inc,t_low,t_spec,t_hi,the_ax)
  the_axinfo = get(the_ax,'UserData');
  taxis = the_axinfo.taxis;
  [duh,itaxis] = min(abs(taxis - t_spec));
  if yes_inc
    itaxis = itaxis + 1; if itaxis > the_axinfo.datlims(2), itaxis = the_axinfo.datlims(2); end
  else
    itaxis = itaxis - 1; if itaxis < 1, itaxis = 1; end
  end
  new_t_spec = taxis(itaxis);
  if new_t_spec < t_low || new_t_spec > t_hi, new_t_spec = (t_low + t_hi)/2; end
end

function [axtype,hax,hply,h_tmarker_low,h_tmarker_spec,h_tmarker_hi] = get_ax_info(ax)
  axinfo = get(ax,'UserData');
  axtype = axinfo.type;
  hax = axinfo.h;
  hply = axinfo.hply;
  h_tmarker_low = axinfo.h_tmarker_low;
  h_tmarker_spec = axinfo.h_tmarker_spec;
  h_tmarker_hi = axinfo.h_tmarker_hi;
end

function h_tmarker = make_tmarker(hax,linestyle,marker_name,line_width,yes_visible)
  global default_tmarker_width
  if nargin < 3, marker_name = []; end
  if nargin < 4 || isempty(line_width), line_width = default_tmarker_width; end
  if nargin < 5 || isempty(yes_visible), yes_visible = 1; end
  xlims = get(hax,'XLim');
  t = xlims(1);
  tmarker_xdat = t*[1 1];
  tmarker_ydat = get(hax,'YLim');
  h_tmarker = plot(hax,tmarker_xdat,tmarker_ydat,linestyle);
  set(h_tmarker,'LineWidth',line_width);
  if isempty(marker_name)
    h_marker_name = [];
  else
    if ~isstruct(marker_name)
      marker_name_specs(1).name = marker_name;
    else
      marker_name_specs = marker_name;
    end
    n_marker_names = length(marker_name_specs);
    for i_marker_name = 1:n_marker_names
      marker_name_spec = marker_name_specs(i_marker_name);
      if ~isfield(marker_name_spec,'name'), error('marker_name_spec must have a "name" field'); end
      if ~isfield(marker_name_spec,'vert_align'), marker_name_spec.vert_align = 'bottom'; end
      if ~isfield(marker_name_spec,'color'), marker_name_spec.color = 'k'; end
      if ~isfield(marker_name_spec,'idatsources'), marker_name_spec.idatsources = 0; end
      if ~isfield(marker_name_spec,'idatrows'), marker_name_spec.idatrows = []; end
      if ~isfield(marker_name_spec,'bgrect'), marker_name_spec.bgrect = []; end
      if ~isfield(marker_name_spec,'iidatsource4ypos'), marker_name_spec.iidatsource4ypos = []; end
      marker_name_spec.h_tmarker = h_tmarker;
      marker_name_str = get_marker_name_str(marker_name_spec,t);
      cur_hax = gca;
      axes(hax); % because the text() command only works with the current axes
      h_marker_name(i_marker_name) = text(t,tmarker_ydat(2),marker_name_str);
      axes(cur_hax);
      set(h_marker_name(i_marker_name),'VerticalAlignment',marker_name_spec.vert_align);
      if strcmp(marker_name_spec.color,'same')
        set(h_marker_name(i_marker_name),'Color',get(h_tmarker,'Color'));
      else
        set(h_marker_name(i_marker_name),'Color',marker_name_spec.color);
      end
      set(h_marker_name(i_marker_name),'UserData',marker_name_spec);
      update_marker_name_bgrect(h_marker_name(i_marker_name));
    end
  end
  set(h_tmarker,'UserData',h_marker_name);
  if ~yes_visible, set(h_tmarker,'Visible','off'); end
end

function update_tmarker(h_tmarker,t)
  if isempty(t)
    tmarker_xdat = get(h_tmarker,'XData');
    t = tmarker_xdat(1);
  end
  tmarker_xdat = t*[1 1];
  tmarker_ydat = get(get(h_tmarker,'Parent'),'YLim');
  set(h_tmarker,'XData',tmarker_xdat);
  set(h_tmarker,'YData',tmarker_ydat);
  h_marker_name = get(h_tmarker,'UserData');
  if ~isempty(h_marker_name)
    n_marker_names = length(h_marker_name);
    for i_marker_name = 1:n_marker_names
      marker_name_spec = get(h_marker_name(i_marker_name),'UserData');
      marker_name_str = get_marker_name_str(marker_name_spec,t);
      set(h_marker_name(i_marker_name),'String',marker_name_str);
      marker_name_xpos = tmarker_xdat(1);
      iidatsource4ypos = marker_name_spec.iidatsource4ypos;
      if isempty(iidatsource4ypos), iidatsource4ypos = 0; end
      switch iidatsource4ypos
        case 0, marker_name_ypos = tmarker_ydat(2);
        otherwise,
          datsources = get_marker_name_datsources(marker_name_spec,t);
          marker_name_ypos = datsources{iidatsource4ypos};
      end
      set(h_marker_name(i_marker_name),'Position',[marker_name_xpos marker_name_ypos 0]);
      update_marker_name_bgrect(h_marker_name(i_marker_name));
    end
  end 
end

function marker_name_str = get_marker_name_str(marker_name_spec,t)
  if any(marker_name_spec.name=='%') % is marker name a format string?
    datsources = get_marker_name_datsources(marker_name_spec,t);
    marker_name_str = sprintf(marker_name_spec.name,datsources{:});
  else
    marker_name_str = marker_name_spec.name;
  end
end

function datsources = get_marker_name_datsources(marker_name_spec,t)
  idatsources = marker_name_spec.idatsources;
  idatrows = marker_name_spec.idatrows;
  ndatsources = length(idatsources);
  if isempty(idatrows)
    idatrows = ones(1,ndatsources);
  else
    if length(idatrows) ~= ndatsources
      error('length(idatrows)(%d) ~= ndatsources(%d)',length(idatrows),ndatsources);
    end
  end
  for ii = 1:ndatsources
    switch idatsources(ii)
      case 0, datsources{ii} = t;
      otherwise,
        h_tmarker = marker_name_spec.h_tmarker;
        axinfo = get(get(h_tmarker,'Parent'),'UserData');
        the_dat = axinfo.dat{idatsources(ii)};
        the_taxis = axinfo.params{idatsources(ii)}.taxis;
        the_dat_idx = dsearchn(the_taxis',t);
        the_dat_irow = idatrows(ii);
        datsources{ii} = the_dat(the_dat_irow,the_dat_idx); % yes, this only works for dat's that are vectors
    end
  end
end  

function update_marker_name_bgrect(h_marker_name)
  marker_name_spec = get(h_marker_name,'UserData');
  if ~isempty(marker_name_spec.bgrect)
    m = get(h_marker_name,'Extent');
    xdat = [m(1) (m(1)+m(3)) (m(1)+m(3)) m(1)];
    ydat = [m(2) m(2) (m(2)+m(4)) (m(2)+m(4))];
    if ~isfield(marker_name_spec.bgrect,'color') || isempty(marker_name_spec.bgrect.color)
      marker_name_spec.bgrect.color = 'b';
    end
    bgrect_color = marker_name_spec.bgrect.color;
    if strcmp(bgrect_color,'same')
      h_tmarker = marker_name_spec.h_tmarker;
      bgrect_color = get(h_tmarker,'Color');
    end
    if ~isfield(marker_name_spec.bgrect,'h') || isempty(marker_name_spec.bgrect.h)
      marker_name_spec.bgrect.h = patch(xdat,ydat,bgrect_color);
      moveback(marker_name_spec.bgrect.h);
      set(marker_name_spec.bgrect.h,'LineStyle','none');
    else
      set(marker_name_spec.bgrect.h,'XData',xdat);
      set(marker_name_spec.bgrect.h,'YData',ydat);
      set(marker_name_spec.bgrect.h,'FaceColor',bgrect_color);
    end
  end
  set(h_marker_name,'UserData',marker_name_spec);
end

function t = get_tmarker_time(h_tmarker)
  tmarker_xdat = get(h_tmarker,'XData');
  t = tmarker_xdat(1);
end

function [t_low,t_spec,t_hi] = get_ax_tmarker_times(ax)
  axinfo = get(ax,'UserData');
  t_low = get_tmarker_time(axinfo.h_tmarker_low);
  t_spec = get_tmarker_time(axinfo.h_tmarker_spec);
  t_hi  = get_tmarker_time(axinfo.h_tmarker_hi);
end

function update_ax_tmarkers(ax,t_low,t_spec,t_hi)
  axinfo = get(ax,'UserData');
  update_tmarker(axinfo.h_tmarker_low,t_low);
  update_tmarker(axinfo.h_tmarker_spec,t_spec);
  update_tmarker(axinfo.h_tmarker_hi,t_hi);

  nevents = axinfo.nevents;
  if nevents
    h_tmarker_event = axinfo.h_tmarker_event;
    event_times = axinfo.event_params.event_times;
    for ievent = 1:nevents
      update_tmarker(h_tmarker_event(ievent),event_times(ievent));
    end
  end
  n_user_events = axinfo.n_user_events;
  if n_user_events
    h_tmarker_user_event = axinfo.h_tmarker_user_event;
    user_event_times = axinfo.event_params.user_event_times;
    for ievent = 1:n_user_events
      update_tmarker(h_tmarker_user_event(ievent),user_event_times(ievent));
    end
  end
  set(ax,'UserData',axinfo);
end

function ampl_thresh4voicing = get_ampl_thresh4voicing(the_ax,nax,ax)
  axinfo = get(the_ax,'UserData');
  if strcmp(axinfo.type,'ampl')
    ampl_ax = the_ax;
    ampl_axinfo = axinfo;
    cp = get(ampl_ax,'CurrentPoint');
    ampl_thresh4voicing = cp(1,2);
  else
    ampl_thresh4voicing = [];
  end
end

function add_user_event(the_ax,nax,ax)
  axinfo = get(the_ax,'UserData');
  t = get_tmarker_time(axinfo.h_tmarker_spec);
  if axinfo.yes_add_user_events
    for iax = 1:nax
      axinfo = get(ax(iax),'UserData');
      if axinfo.yes_add_user_events
        n_user_events = axinfo.n_user_events + 1;
        user_event_names = axinfo.event_params.user_event_names;
        user_event_times = axinfo.event_params.user_event_times;
        h_tmarker_user_event = axinfo.h_tmarker_user_event;

        n_prior_names = n_user_events - 1;
        for i_event_name = 1:n_user_events
          user_event_name = sprintf('%s%d',axinfo.event_params.user_event_name_prefix,i_event_name);
          name_taken = 0;
          for i_prior_names = 1:n_prior_names
            if strcmp(user_event_names(i_prior_names),user_event_name)
              name_taken = 1;
            end
          end
          if ~name_taken
            break;
          end
        end
        user_event_names{n_user_events} = user_event_name;
        user_event_times(n_user_events) = t;
        h_tmarker_user_event(n_user_events) = make_tmarker(ax(iax),'c-',user_event_names{n_user_events}); update_tmarker(h_tmarker_user_event(n_user_events),t);
        move2front(ax(iax),axinfo.h_tmarker_spec);
        
        axinfo.n_user_events = n_user_events;
        axinfo.event_params.user_event_names = user_event_names;
        axinfo.event_params.user_event_times = user_event_times;
        axinfo.h_tmarker_user_event = h_tmarker_user_event;
        set(ax(iax),'UserData',axinfo);
      end
    end
  end
end

function delete_user_event(the_ax,nax,ax)
  global max_dist_fract2del_event
  axinfo = get(the_ax,'UserData');
  t = get_tmarker_time(axinfo.h_tmarker_spec);
  if axinfo.yes_add_user_events
    user_event_times = axinfo.event_params.user_event_times;
    [ievent2del,dist2event2del] = dsearchn(user_event_times',t);
    the_ax_tlims = get(the_ax,'XLim');
    dist_fract = dist2event2del/(the_ax_tlims(2) - the_ax_tlims(1));
    if dist_fract < max_dist_fract2del_event
      for iax = 1:nax
        axinfo = get(ax(iax),'UserData');
        if axinfo.yes_add_user_events
          n_user_events = axinfo.n_user_events;
          user_event_names = axinfo.event_params.user_event_names;
          user_event_times = axinfo.event_params.user_event_times;
          h_tmarker_user_event = axinfo.h_tmarker_user_event;
          
          user_event_names(ievent2del) = [];
          user_event_times(ievent2del) = [];
          h_marker_name = get(h_tmarker_user_event(ievent2del),'UserData');
          delete(h_marker_name);
          delete(h_tmarker_user_event(ievent2del));
          h_tmarker_user_event(ievent2del) = [];
          n_user_events = n_user_events - 1;
          
          axinfo.n_user_events = n_user_events;
          axinfo.event_params.user_event_names = user_event_names;
          axinfo.event_params.user_event_times = user_event_times;
          axinfo.h_tmarker_user_event = h_tmarker_user_event;
          set(ax(iax),'UserData',axinfo);
        end
      end
    end
  end
end

function clear_all_user_events(nax,ax)
  for iax = 1:nax
    axinfo = get(ax(iax),'UserData');
    if axinfo.yes_add_user_events
      n_user_events = axinfo.n_user_events;
      h_tmarker_user_event = axinfo.h_tmarker_user_event;
      for ievent2del = 1:n_user_events
        h_marker_name = get(h_tmarker_user_event(ievent2del),'UserData');
        delete(h_marker_name);
        delete(h_tmarker_user_event(ievent2del));
      end
      axinfo.n_user_events = 0;
      axinfo.event_params.user_event_names = [];
      axinfo.event_params.user_event_times = [];
      axinfo.h_tmarker_user_event = [];
      set(ax(iax),'UserData',axinfo);
    end
  end
end

function cur_ax = cur_ax_from_curpt(nax,ax)
  cur_ax_found = 0;
  for iax = 1:nax
    the_ax = ax(iax);
    if ax_has_current_point(the_ax)
      cur_ax_found = 1;
      cur_ax = the_ax;
      break;
    end
  end
  if ~cur_ax_found, cur_ax = []; end
end

function yes_has_current_point = ax_has_current_point(ax)
  cp = get(ax,'CurrentPoint');
  x = cp(1,1); y = cp(1,2);
  xl = get(ax,'XLim');
  yl = get(ax,'YLim');
  yes_has_current_point = ((xl(1) <= x) && (x <= xl(2))) && ((yl(1) <= y) && (y <= yl(2)));
end

function h_captured_tmarker = capture_ax_tmarker(ax)
  axinfo = get(ax,'UserData');
  cp = get(ax,'CurrentPoint');
  t_pos = cp(1,1);
  [t_tmarker_low,t_tmarker_spec,t_tmarker_hi] = get_ax_tmarker_times(ax);
  absdiff_tmarker(1) = abs(t_pos - t_tmarker_low);
  absdiff_tmarker(2) = abs(t_pos - t_tmarker_spec);
  absdiff_tmarker(3)  = abs(t_pos - t_tmarker_hi);
  [duh,imin_tmarker] = min(absdiff_tmarker);
  switch imin_tmarker
   case 1, h_captured_tmarker = axinfo.h_tmarker_low;
   case 2, h_captured_tmarker = axinfo.h_tmarker_spec;
   case 3, h_captured_tmarker = axinfo.h_tmarker_hi;
  end
  update_tmarker(h_captured_tmarker,t_pos);
end

function move_tmarker2ax_curpt(ax,h_tmarker);
  cp = get(ax,'CurrentPoint');
  t_pos = cp(1,1);
  update_tmarker(h_tmarker,t_pos);
end

function output_interval_btw_ax_tmarkers(ax,fs);
  global yseg tseg yfs
  axinfo = get(ax,'UserData');
  taxis = get(axinfo.hply(1),'XData');
  y = get(axinfo.hply(1),'YData');
  [t_tmarker_low,t_tmarker_spec,t_tmarker_hi] = get_ax_tmarker_times(ax);
  [duh,ilow] = min(abs(taxis - t_tmarker_low));
  [duh,ihi]  = min(abs(taxis - t_tmarker_hi));
  yseg = y(ilow:ihi);
  tseg = taxis(ilow:ihi);
  yfs = fs;
end

function report_interval_btw_ax_tmarkers(ax,fs);
  axinfo = get(ax,'UserData');
  taxis = get(axinfo.hply(1),'XData');
  [t_tmarker_low,t_tmarker_spec,t_tmarker_hi] = get_ax_tmarker_times(ax);
  [duh,ilow] = min(abs(taxis - t_tmarker_low));
  [duh,ihi]  = min(abs(taxis - t_tmarker_hi));
  fprintf('t_low(%.3f sec), t_hi(%.3f sec), dur(%.3f sec, %d samples)\n', ...
          t_tmarker_low,t_tmarker_hi,t_tmarker_hi-t_tmarker_low,ihi-ilow+1);
end

function expand_btw_ax_tmarkers(ax)
  global tmarker_init_border;
  axinfo = get(ax,'UserData');
  [t_tmarker_low,t_tmarker_spec,t_tmarker_hi] = get_ax_tmarker_times(ax);
  t_tmarker_range = t_tmarker_hi - t_tmarker_low;
  new_t_low = t_tmarker_low - tmarker_init_border*t_tmarker_range;
  new_t_hi  = t_tmarker_hi  + tmarker_init_border*t_tmarker_range;
  new_ax_tlims(ax,new_t_low,new_t_hi);
  if t_tmarker_spec < new_t_low || t_tmarker_spec > new_t_hi
    update_tmarker(axinfo.h_tmarker_spec,(new_t_low + new_t_hi)/2);
  else
    update_tmarker(axinfo.h_tmarker_spec,[]);
  end  
end

function widen_ax_view(ax)
  axinfo = get(ax,'UserData');
  cur_tlims = get(axinfo.h,'XLim');
  cur_tlow = cur_tlims(1);
  cur_thi  = cur_tlims(2);
  cur_trange = cur_thi - cur_tlow;
  new_tlow = cur_tlow - 0.5*cur_trange;
  new_thi = cur_thi + 0.5*cur_trange;
  new_ax_tlims(ax,new_tlow,new_thi);
end

function new_ax_tlims(ax,new_tlow,new_thi)
  axinfo = get(ax,'UserData');
  t_llim = axinfo.t_llim;
  t_hlim = axinfo.t_hlim;
  if new_tlow < t_llim, new_tlow = t_llim; end
  if new_thi > t_hlim, new_thi = t_hlim; end
  set(ax,'XLim',[new_tlow new_thi]);
  update_tmarker(axinfo.h_tmarker_spec,[]);
end

function redistrib_ax(ax,nax)
  reinit_axfracts(ax,nax);
  reposition_ax(ax,nax);
end

function set_axfracts(ax,nax,axfracts)
  if nax ~= axfracts.n
    warning('nax(%d) ~= axfracts.n(%d)',nax,axfracts.n);
    reinit_axfracts(ax,nax);
  else
    if abs(sum([axfracts.y]) - 1) > 0.000001
      warning('sum([axfracts.y]) ~= 1');
      reinit_axfracts(ax,nax);
    else
      for iax = 1:nax
        set_axfract(ax(iax),axfracts.x(iax),axfracts.y(iax));
      end
    end
  end
end

function reinit_axfracts(ax,nax)
  for iax = 1:nax
    set_axfract(ax(iax),1.0,1.0/nax);
  end
end

function heighten_iax(iax2heighten,ax,nax)
  global ax_heighten_inc
  [the_axfract_x,the_axfract_y] = get_axfract(ax(iax2heighten));
  the_new_axfract_y = (1+ax_heighten_inc)*the_axfract_y;
  if the_new_axfract_y > 1, the_new_axfract_y = the_axfract_y; end
  set_axfract(ax(iax2heighten),the_axfract_x,the_new_axfract_y);
  axfract_left = 1.0 - the_new_axfract_y;
  reapportion_other_ax(iax2heighten,ax,nax,axfract_left);
  reposition_ax(ax,nax);
end

function unheighten_iax(iax2heighten,ax,nax)
  global ax_heighten_inc
  [the_axfract_x,the_axfract_y] = get_axfract(ax(iax2heighten));
  the_new_axfract_y = (1-ax_heighten_inc)*the_axfract_y;
  if the_new_axfract_y < 0, the_new_axfract_y = the_axfract_y; end
  set_axfract(ax(iax2heighten),the_axfract_x,the_new_axfract_y);
  axfract_left = 1.0 - the_new_axfract_y;
  reapportion_other_ax(iax2heighten,ax,nax,axfract_left);
  reposition_ax(ax,nax);
end

function reapportion_other_ax(iax2omit,ax,nax,axfract_left)
  if nax > 1
    axfract_y_total = 0;
    for iax = 1:nax
      if iax ~= iax2omit
        [duh,axfract_y(iax)] = get_axfract(ax(iax));
        axfract_y_total = axfract_y_total + axfract_y(iax);
      end
    end
    for iax = 1:nax
      if iax ~= iax2omit
        new_axfract_y = (axfract_y(iax)/axfract_y_total)*axfract_left;
        [axfract_x,duh] = get_axfract(ax(iax));
        set_axfract(ax(iax),axfract_x,new_axfract_y);
      end
    end
  end
end

function reposition_ax(ax,nax)
  [axarea_xo,axarea_yo,axarea_xw,axarea_yw] = get_axarea();
  axtile_xo = axarea_xo;
  axtile_xw = axarea_xw;
  axtile_yw_acc = 0;
  for iax = 1:nax
    [axfract_x,axfract_y] = get_axfract(ax(iax));
    axtile_yo = axarea_yo + axtile_yw_acc;
    axtile_yw = axfract_y*axarea_yw;
    set_ax_pos(ax(iax),axtile_xo,axtile_yo,axtile_xw,axtile_yw);
    axtile_yw_acc = axtile_yw_acc + axtile_yw;
  end
end

function [axarea_xo,axarea_yo,axarea_xw,axarea_yw] = get_axarea()
  global figborder_xl figborder_xr figborder_yl figborder_yu
  axarea_xo = figborder_xl;
  axarea_yo = figborder_yl;
  axarea_xw = 1.0 - figborder_xl - figborder_xr;
  axarea_yw = 1.0 - figborder_yl - figborder_yu;
end

function [axfract_x,axfract_y] = get_axfract(ax)
  axinfo = get(ax,'UserData');
  axfract = axinfo.axfract;
  axfract_x = axfract(1);
  axfract_y = axfract(2);
end

function set_axfract(ax,axfract_x,axfract_y);
  axinfo = get(ax,'UserData');
  axinfo.axfract = [axfract_x axfract_y];
  set(ax,'UserData',axinfo);
end

function set_ax_pos(ax,axtile_xo,axtile_yo,axtile_xw,axtile_yw)
  global axborder_xl axborder_xr axborder_yl axborder_yu
  axpos_xo  = axtile_xo + axborder_xl*axtile_xw;
  axpos_xw  = (1.0 - axborder_xl - axborder_xr)*axtile_xw;
  axpos_yo  = axtile_yo + axborder_yl*axtile_yw;
  axpos_yw  = (1.0 - axborder_yl - axborder_yu)*axtile_yw;
  set(ax,'Position',[axpos_xo axpos_yo axpos_xw axpos_yw]);
  axinfo = get(ax,'UserData');
  update_tmarker(axinfo.h_tmarker_spec,[]);
end

function iax = get_iax(the_ax,ax,nax);
  iax_found = 0;
  for iax = 1:nax
    if ax(iax) == the_ax
      iax_found = 1;
      break;
    end
  end
  if ~iax_found, error('could not find the_ax in ax list'); end
end

% generic wavefig stuff

function my_iwavefig = add_wavefig(hf,nax,ax)
  global wavefig nwavefigs
  if isempty(nwavefigs), nwavefigs = 0; end
  nwavefigs = nwavefigs + 1;
  my_iwavefig = nwavefigs;
  wavefig(my_iwavefig).i = my_iwavefig;
  wavefig(my_iwavefig).hf = hf;
  wavefig(my_iwavefig).nax = nax;
  wavefig(my_iwavefig).ax = ax;
  for iax = 1:nax
    axinfo = get(ax(iax),'UserData');
    wavefig(my_iwavefig).(sprintf('i_%s_ax',axinfo.type)) = axinfo.i;
  end
  wavefig(my_iwavefig).marked4tying = 0;
  wavefig(my_iwavefig).ntied2figs = 0;
  wavefig(my_iwavefig).tied2fig = [];
end

function remove_wavefig(my_iwavefig)
  global wavefig nwavefigs
  if ~isempty(wavefig) && ~isempty(nwavefigs) % wavefig and nwavefigs could be empty if user runs clear all first
    untie_wavefig(my_iwavefig);
    wavefig_idx = get_wavefig_idx(my_iwavefig);
    wavefig(wavefig_idx) = [];
    nwavefigs = nwavefigs - 1;
  end
end

function idx = get_wavefig_idx(iwavefig2get)
  global wavefig nwavefigs
  found_wavefig = 0;
  for idx = 1:nwavefigs
    if wavefig(idx).i == iwavefig2get
      found_wavefig = 1;
      break;
    end
  end
  if ~found_wavefig
    error(sprintf('wavefig.i(%d) not found',iwavefig2get));
  end
end  

function mark_wavefig4tying(i2mark)
  global wavefig nwavefigs
  for i = 1:nwavefigs
    wavefig(i).marked4tying = 0;
  end
  wavefig_idx = get_wavefig_idx(i2mark);
  wavefig(wavefig_idx).marked4tying = 1;
end

function iwavefig = find_wavefig4tying()
  global wavefig nwavefigs
  found_wavefig4tying = 0;
  for idx = 1:nwavefigs
    if wavefig(idx).marked4tying
      found_wavefig4tying = 1;
      break;
    end
  end
  if ~found_wavefig4tying
    iwavefig = 0;
  else
    iwavefig = wavefig(idx).i;
  end
end

function tie_wavefig4tying(iwavefig,iwavefig2tie)
  global wavefig nwavefigs
  wavefig_idx = get_wavefig_idx(iwavefig);
  ntied2figs = wavefig(wavefig_idx).ntied2figs;
  if ~ntied2figs || ~any(wavefig(wavefig_idx).tied2fig == iwavefig2tie)
    ntied2figs = ntied2figs + 1;
    wavefig(wavefig_idx).tied2fig(ntied2figs) = iwavefig2tie;
    wavefig(wavefig_idx).ntied2figs = ntied2figs;
  end
end

function untie_wavefig(iwavefig2untie)
  global wavefig nwavefigs
  for wavefig_idx = 1:nwavefigs
    ntied2figs = wavefig(wavefig_idx).ntied2figs;
    if ntied2figs || any(wavefig(wavefig_idx).tied2fig == iwavefig2untie)
      idx4del = find(wavefig(wavefig_idx).tied2fig == iwavefig2untie);
      wavefig(wavefig_idx).tied2fig(idx4del) = [];
      ntied2figs = ntied2figs - length(idx4del);
      wavefig(wavefig_idx).ntied2figs = ntied2figs;
    end
  end
  wavefig_idx2untie = get_wavefig_idx(iwavefig2untie);
  wavefig(wavefig_idx2untie).tied2fig = [];
  wavefig(wavefig_idx2untie).ntied2figs = 0;
end

function set_viewer_axlims(hax,t_min,t_max,dat4minmax,yax_fact2use)
  global yax_fact
  
  if nargin < 5 || isempty(yax_fact2use), yax_fact2use = yax_fact; end

  if ~any(~isnan(dat4minmax))
    y_low = 0; y_hi = 1;
  else
    y_low = min(dat4minmax); y_hi  = max(dat4minmax);
  end
  y_range = y_hi - y_low; if y_range == 0, y_range = 1; end
  
  axis(hax,[t_min t_max (y_low-yax_fact2use*y_range) (y_hi +yax_fact2use*y_range)]);
end
