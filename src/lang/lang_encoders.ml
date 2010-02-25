(*****************************************************************************

  Liquidsoap, a programmable audio stream generator.
  Copyright 2003-2010 Savonet team

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details, fully stated in the COPYING
  file at the root of the liquidsoap distribution.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

 *****************************************************************************)

open Lang_values

(** Parsing locations. *)
let curpos ?pos () =
  match pos with
    | None -> Parsing.symbol_start_pos (), Parsing.symbol_end_pos ()
    | Some (i,j) -> Parsing.rhs_start_pos i, Parsing.rhs_end_pos j

(** Create a new value with an unknown type. *)
let mk ?pos e =
  let kind =
    T.fresh_evar ~level:(-1) ~pos:(Some (curpos ?pos ()))
  in
    if Lang_values.debug then
      Printf.eprintf "%s (%s): assigned type var %s\n"
        (T.print_pos (Utils.get_some kind.T.pos))
        (try Lang_values.print_term {t=kind;term=e} with _ -> "<?>")
        (T.print kind) ;
    { t = kind ; term = e }

let mk_wav params =
  let defaults = { Encoder.WAV.stereo = true } in
  let wav =
    List.fold_left
      (fun f ->
        function
          | ("stereo",{ term = Bool b }) ->
              { Encoder.WAV.stereo = b }
          | ("",{ term = Var s }) when String.lowercase s = "stereo" ->
              { Encoder.WAV.stereo = true }
          | ("",{ term = Var s }) when String.lowercase s = "mono" ->
              { Encoder.WAV.stereo = false }
          | _ -> raise Parsing.Parse_error)
      defaults params
  in
    mk (Encoder (Encoder.WAV wav))

let mk_mp3 params =
  let defaults =
    { Encoder.MP3.
        stereo = true ;
        samplerate = 44100 ;
        bitrate = Encoder.MP3.Bitrate 128 }
  in
  let mp3 =
    List.fold_left
      (fun f ->
        function
          | ("stereo",{ term = Bool b }) ->
              { f with Encoder.MP3.stereo = b }
          | ("samplerate",{ term = Int i }) ->
              { f with Encoder.MP3.samplerate = i }
          | ("bitrate",{ term = Int i }) ->
              { f with Encoder.MP3.bitrate = 
                       Encoder.MP3.Bitrate i }
          | ("quality",{ term = Int q }) ->
              { f with Encoder.MP3.bitrate = 
                       Encoder.MP3.Quality q }

          | ("",{ term = Var s }) when String.lowercase s = "mono" ->
              { f with Encoder.MP3.stereo = false }
          | ("",{ term = Var s }) when String.lowercase s = "stereo" ->
              { f with Encoder.MP3.stereo = true }

          | _ -> raise Parsing.Parse_error)
      defaults params
  in
    mk (Encoder (Encoder.MP3 mp3))

let mk_aacplus params =
  let defaults =
    { Encoder.AACPlus.
        channels = 2 ;
        samplerate = 44100 ;
        bitrate = 64 }
  in
  let aacplus =
    List.fold_left
      (fun f ->
        function
          | ("channels",{ term = Int i }) ->
              { f with Encoder.AACPlus.channels = i }
          | ("samplerate",{ term = Int i }) ->
              { f with Encoder.AACPlus.samplerate = i }
          | ("bitrate",{ term = Int i }) ->
              { f with Encoder.AACPlus.bitrate = i }
          | ("",{ term = Var s }) when String.lowercase s = "mono" ->
              { f with Encoder.AACPlus.channels = 1 }
          | ("",{ term = Var s }) when String.lowercase s = "stereo" ->
              { f with Encoder.AACPlus.channels = 2 }

          | _ -> raise Parsing.Parse_error)
      defaults params
  in
    mk (Encoder (Encoder.AACPlus aacplus))

let mk_external params =
  let defaults =
    { Encoder.External.
        channels = 2 ;
        samplerate = 44100 ;
        header  = true ;
        restart_on_crash = false ;
        restart = Encoder.External.No_condition ;
        process = "" }
  in
  let ext =
    List.fold_left
      (fun f ->
        function
          | ("channels",{ term = Int c }) ->
              { f with Encoder.External.channels = c }
          | ("samplerate",{ term = Int i }) ->
              { f with Encoder.External.samplerate = i }
          | ("header",{ term = Bool h }) ->
              { f with Encoder.External.header = h }
          | ("restart_on_crash",{ term = Bool h }) ->
              { f with Encoder.External.restart_on_crash = h }
          | ("",{ term = Var s })
            when String.lowercase s = "restart_on_new_track" ->
              { f with Encoder.External.restart = Encoder.External.Track }
          | ("restart_after_delay",{ term = Int i }) ->
              { f with Encoder.External.restart = Encoder.External.Delay  i }
          | ("process",{ term = String s }) ->
              { f with Encoder.External.process = s }
          | ("",{ term = String s }) ->
              { f with Encoder.External.process = s }

          | _ -> raise Parsing.Parse_error)
      defaults params
  in
    if ext.Encoder.External.process = "" then
      raise Encoder.External.No_process ;
    mk (Encoder (Encoder.External ext))

let mk_vorbis_cbr params =
  let defaults =
    { Encoder.Vorbis.
        mode = Encoder.Vorbis.ABR (128,128,128) ;
        channels = 2 ;
        samplerate = 44100 ;
    }
  in
  let vorbis =
    List.fold_left
      (fun f ->
        function
          | ("samplerate",{ term = Int i }) ->
              { f with Encoder.Vorbis.samplerate = i }
          | ("bitrate",{ term = Int i }) ->
              { f with Encoder.Vorbis.mode = Encoder.Vorbis.CBR i }
          | ("channels",{ term = Int i }) ->
              { f with Encoder.Vorbis.channels = i }
          | ("",{ term = Var s }) when String.lowercase s = "mono" ->
              { f with Encoder.Vorbis.channels = 2 }
          | ("",{ term = Var s }) when String.lowercase s = "stereo" ->
              { f with Encoder.Vorbis.channels = 1 }

          | _ -> raise Parsing.Parse_error)
      defaults params
  in
    Encoder.Ogg.Vorbis vorbis

let mk_vorbis params =
  let defaults =
    { Encoder.Vorbis.
        mode = Encoder.Vorbis.VBR 2. ;
        channels = 2 ;
        samplerate = 44100 ;
    }
  in
  let vorbis =
    List.fold_left
      (fun f ->
        function
          | ("samplerate",{ term = Int i }) ->
              { f with Encoder.Vorbis.samplerate = i }
          | ("quality",{ term = Float q }) ->
              { f with Encoder.Vorbis.mode = Encoder.Vorbis.VBR q }
          | ("quality",{ term = Int i }) ->
              let q = float i in
              { f with Encoder.Vorbis.mode = Encoder.Vorbis.VBR q }
          | ("channels",{ term = Int i }) ->
              { f with Encoder.Vorbis.channels = i }
          | ("",{ term = Var s }) when String.lowercase s = "mono" ->
              { f with Encoder.Vorbis.channels = 2 }
          | ("",{ term = Var s }) when String.lowercase s = "stereo" ->
              { f with Encoder.Vorbis.channels = 1 }

          | _ -> raise Parsing.Parse_error)
      defaults params
  in
    Encoder.Ogg.Vorbis vorbis

let mk_theora params =
  let defaults = 
    { 
      Encoder.Theora.
       bitrate_control    = Encoder.Theora.Quality 40 ;
       width              = Frame.video_width ;
       height             = Frame.video_height ;
       picture_width      = Frame.video_width ;
       picture_height     = Frame.video_height ;
       picture_x          = 0 ;
       picture_y          = 0 ;
       aspect_numerator   = 1 ;
       aspect_denominator = 1 ;
    } 
  in
  let theora =
    List.fold_left
      (fun f ->
        function
          | ("quality",{ term = Int i }) ->
              { f with
                  Encoder.Theora.bitrate_control = Encoder.Theora.Quality i }
          | ("bitrate",{ term = Int i }) ->
              { f with
                  Encoder.Theora.bitrate_control = Encoder.Theora.Bitrate i }
          | ("width",{ term = Int i }) ->
              { f with Encoder.Theora.
                    width = Lazy.lazy_from_val i;
                    picture_width = Lazy.lazy_from_val i }
          | ("height",{ term = Int i }) ->
              { f with Encoder.Theora.
                    height = Lazy.lazy_from_val i;
                    picture_height = Lazy.lazy_from_val i }
          | ("picture_width",{ term = Int i }) ->
              { f with Encoder.Theora.picture_width = Lazy.lazy_from_val i }
          | ("picture_height",{ term = Int i }) ->
              { f with Encoder.Theora.picture_height = Lazy.lazy_from_val i }
          | ("picture_x",{ term = Int i }) ->
              { f with Encoder.Theora.picture_x = i }
          | ("picture_y",{ term = Int i }) ->
              { f with Encoder.Theora.picture_y = i }
          | ("aspect_numerator",{ term = Int i }) ->
              { f with Encoder.Theora.aspect_numerator = i }
          | ("aspect_denominator",{ term = Int i }) ->
              { f with Encoder.Theora.aspect_denominator = i }
          | _ -> raise Parsing.Parse_error)
      defaults params
  in
    Encoder.Ogg.Theora theora

let mk_dirac params =
  let defaults =
    {
      Encoder.Dirac.
       quality            = 35. ;
       width              = Frame.video_width ;
       height             = Frame.video_height ;
       aspect_numerator   = 1 ;
       aspect_denominator = 1 ;
    }
  in
  let dirac =
    List.fold_left
      (fun f ->
        function
          | ("quality",{ term = Float i }) ->
              { f with Encoder.Dirac.quality = i }
          | ("width",{ term = Int i }) ->
              { f with Encoder.Dirac.
                    width = Lazy.lazy_from_val i }
          | ("height",{ term = Int i }) ->
              { f with Encoder.Dirac.
                    height = Lazy.lazy_from_val i }
          | ("aspect_numerator",{ term = Int i }) ->
              { f with Encoder.Dirac.aspect_numerator = i }
          | ("aspect_denominator",{ term = Int i }) ->
              { f with Encoder.Dirac.aspect_denominator = i }
          | _ -> raise Parsing.Parse_error)
      defaults params
  in
    Encoder.Ogg.Dirac dirac

let mk_speex params =
  let defaults =
    { Encoder.Speex.
        stereo = false ;
        samplerate = 44100 ;
        bitrate_control = Encoder.Speex.Quality 7;
        mode = Encoder.Speex.Narrowband ;
        frames_per_packet = 1 ;
        complexity = None
    }
  in
  let speex =
    List.fold_left
      (fun f ->
        function
          | ("stereo",{ term = Bool b }) ->
              { f with Encoder.Speex.stereo = b }
          | ("samplerate",{ term = Int i }) ->
              { f with Encoder.Speex.samplerate = i }
          | ("abr",{ term = Int i }) ->
              { f with Encoder.Speex.
                        bitrate_control = 
                          Encoder.Speex.Abr i }
          | ("quality",{ term = Int q }) ->
              { f with Encoder.Speex.
                        bitrate_control = 
                         Encoder.Speex.Quality q }
          | ("vbr",{ term = Int q }) ->
              { f with Encoder.Speex.
                        bitrate_control =
                         Encoder.Speex.Vbr q }
          | ("mode",{ term = Var s })
            when String.lowercase s = "wideband" ->
              { f with Encoder.Speex.mode = Encoder.Speex.Wideband }
          | ("mode",{ term = Var s })
            when String.lowercase s = "narrowband" ->
              { f with Encoder.Speex.mode = Encoder.Speex.Narrowband }
          | ("mode",{ term = Var s })
            when String.lowercase s = "ultra-wideband" ->
              { f with Encoder.Speex.mode = Encoder.Speex.Ultra_wideband }
          | ("frames_per_packet",{ term = Int i }) ->
              { f with Encoder.Speex.frames_per_packet = i }
          | ("complexity",{ term = Int i }) ->
              { f with Encoder.Speex.complexity = Some i }
          | ("",{ term = Var s }) when String.lowercase s = "mono" ->
              { f with Encoder.Speex.stereo = false }
          | ("",{ term = Var s }) when String.lowercase s = "stereo" ->
              { f with Encoder.Speex.stereo = true }

          | _ -> raise Parsing.Parse_error)
      defaults params
  in
    Encoder.Ogg.Speex speex
