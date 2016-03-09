#!/bin/bash

####
# todo: maybe use timidity instead of fluidsynth?
# i.e.:
# $ timidity -Ow -o output.wav input.mid
# $ timidity -Ow -o - input.mid | lame - output.mp3
####

##
## note: most of these variables are set dynamically through commandline options!
##

# handles verbosity. 0 disables any verbose output.
cfg_verbose=0

# 1 means converting files even if the destination output file already exists.
cfg_force=0

# "output destination" is ignored in the default batch mode;
# but, when it is set, a2mp3 will only accept a single file.
cfg_outputfile=""

# the preferred conversion method.
# "mplayer" is the default.
# all possibilities:
#
#   mplayer:
#     the default, and STRONGLY recommended setting.
#     more likely to produce optimized output, and less error-prone.
#     requires the 'lame' utility from liblame.
#
#   ffmpeg:
#     depending on your distribution, this may not work properly.
#     additionally, it tends to create mp3 files that are often
#     3 times as large as those created by mplayer.
#     also requires liblame (but only the library, not the executable).
#
# <more to come eventually>
#
cfg_convmethod="mplayer"

# bitrate; applies to ffmpeg only.
cfg_bitrate="320k"

# sampling rate; applies to mplayer only.
cfg_samplingrate="44100"

# liblame VBR setting. '4' is a responsible, and recommended default.
# '9' is highest quality, but also results in VERY large files.
# '0' is lowest quality, and smallest file size.
# applies to mplayer conv only.
cfg_lamevbr="4"

# the soundfile for fluidsynth.
# there's a good chance you may have to change this line!
cfg_fluidsynth_file="/usr/share/sounds/sf2/default.sf2"

#################################
#################################
## edit below at your own risk ##
#################################
#################################

selfname="$(basename "$0")"

function log
{
  echo "$selfname: $@" >&2
}

function note
{
  log "note: $@"
}

function error
{
  log "error: $@"
}

function fatal
{
  log "fatal error: $@"
  exit 1
}

function verbose
{
  if [[ $cfg_verbose == 1 ]]; then
    log "verbose: $@"
  fi
}

## if you want to add a new conversion method, make sure to prefix it with 'conv_'!
## this pattern is necessary for current_conv, which uses bash's builtin inspection to call it.


# ironically, conv_mplayer is already set to accept alternative converters at this point...
# maybe it'd be a good idea to ditch ffmpeg altogether? 
function conv_mplayer
{
  filepath="$1"
  destination="$2"
  audiodump="tmp.audiodump.wav"
  mpargs=(
    # less verbose output, plz
    -quiet
    -msglevel all=2
    # conv args
    -vo null
    -vc dummy
    -af resample="$cfg_samplingrate"
  )

  verbose "\${filepath#*.} = ${filepath#*.}"
  case "${filepath#*.}" in
    mid)
      #verbose "using sox to convert midi file"
      #if ! sox -t raw -r 44100 -e signed -b 16 -c 1 "$filepath" "$audiodump" || [[ -f "$audiodump" ]]; then
      #  return 1
      #fi
      verbose "using fluidsynth to convert midi file"
      if ! fluidsynth -F "$audiodump" "$cfg_fluidsynth_file" "$filepath" || [[ ! -f "$audiodump" ]]; then
        return 1
      fi
      ;;
    *)
      verbose "using mplayer to convert file (args: ${mpargs[@]} -ao pcm:waveheader:file=\"$audiodump\" \"$filepath\")"
      if ! mplayer ${mpargs[@]} -ao pcm:waveheader:file="$audiodump" "$filepath" || [[ ! -f "$audiodump" ]]; then
        return 1
      fi
      ;;
  esac
  log "converter finished successfully, starting lame"
  #####
  #####
  ##### retrieve tags using gettags and set additional options
  #####
  #####
  more_options=("--add-id3v2" -V $cfg_lamevbr -m s "$audiodump" -o "$destination")
  # check if we can even use gettags
  if type gettags &>/dev/null; then
    # okay, time to get to work
    verbose "found gettags, will try to adopt tags"
    artist="$(gettags -c "artist" "$filepath")"
    title="$(gettags -c "title" "$filepath")"
    album="$(gettags -c "album" "$filepath")"
    year="$(gettags -c "year" "$filepath")"
    comment="$(gettags -c "comment" "$filepath")"
    genre="$(gettags -c "genre" "$filepath")"
    [[ "$artist"  != "" ]] && more_options+=("--ta" "$artist")
    [[ "$title"   != "" ]] && more_options+=("--tt" "$title")
    [[ "$album"   != "" ]] && more_options+=("--tl" "$album")
    [[ "$year"    != "" ]] && more_options+=("--ty" "$year")
    [[ "$comment" != "" ]] && more_options+=("--tc" "$comment")
    [[ "$genre"   != "" ]] && more_options+=("--tg" "$genre")
  fi
  # pass options forward
  verbose "running lame with arguments: (lame ${more_options[@]})"
  if lame "${more_options[@]}"; then
    log "lame finished successfully"
    verbose "deleting audiodump \"$audiodump\""
    rm -f "$audiodump"
    return 0
  fi
  return 1
}

function conv_ffmpeg
{
  filepath="$1"
  destination="$2"
  if ffmpeg -i "$filepath" -acodec libmp3lame -ab "$cfg_bitrate" "$destination"; then
    return 0
  fi
  return 1
}

function current_conv
{
  filepath="$1"
  destination="$2"
  funcname="conv_${cfg_convmethod}"
  # this is such a weird hack
  if ! type -t "$funcname" >/dev/null; then
    fatal "conversion method '$cfg_convmethod' (from \$cfg_convmethod) is unknown!"
  fi
  "$funcname" "$filepath" "$destination"
  return $?
}


function handle_file
{
  filepath="$1"
  # extract the raw name without the file extension
  # this is literally the best solution i have found so far, that is,
  # the only one that actually works properly
  rawname="$(sed 's/\.[^.]*$//' <<< "$filepath")"
  [[ -n $2 ]] && destination="$2" || destination="${rawname}.mp3"
  # can't convert something that doesn't exist...
  if [[ ! -f "$filepath" ]]; then
    fatal "file '$filepath' doesn't exist!"
  else
    if [[ -f "$destination" ]] && [[ $cfg_force == 0 ]]; then
      note "skipping '$filepath' because '$destination' already exists"
    else
      log "converting '$filepath' to '$destination' ..."
      if ! current_conv "$filepath" "$destination"; then
        error "failed to convert '$filepath'!"
        error "review the error message(s) produced by the converters to figure out what went wrong."
        fatal "will abort now"
      fi
    fi
  fi
}

function showhelp
{
  echo -ne \
    "usage: $selfname [<options>] <audio-file> ..." \
    "\n" \
    "supported options:\n" \
    "  -h               show this help and exit\n" \
    "  -o<val>          write MP3 file to <val>. can only be used with ONE file argument!\n" \
    "  -v               toggle verbose, additional output\n" \
    "  -f               force convert, even if the destination file already exists\n" \
    "  -b<val>          set bitrate (applies to ffmpeg only). defaults to '$cfg_bitrate'\n" \
    "  -s<val>          set sampling rate (applies to mplayer only). defaults to '$cfg_samplingrate'\n" \
    "  -l<val>          set VBR (applies to lame only). defaults to '$cfg_lamevbr'\n" \
    "  -c<method>       set conversion method to <method>. available methods: ffmpeg, mplayer. defaults to '$cfg_convmethod'\n" \
    "\n" \
    "example:\n" \
    "   # writes the MP3 file to <wmafile>.mp3, where '.wma' is replaced with '.mp3'\n" \
    "   # audio files are only deleted if $selfname converted them successfully!\n" \
    "   cd /directory/with/lots/of/wma/files && $selfname *.wma && rm *.wma\n" \
    "\n" \
    "   # write output to 'mysong.mp3' instead of 'thatsong.mp3'\n" \
    "   $selfname -o mysong.mp3 thatsong.wma\n" \
    "\n"
}

if [[ "$1" ]]; then
  while getopts "c:b:s:l:o:vfh" opt; do
    case $opt in
      c)
        cfg_convmethod="$OPTARG"
        ;;
      b)
        cfg_bitrate="$OPTARG"
        ;;
      s)
        cfg_samplingrate="$OPTARG"
        ;;
      l)
        cfg_lamevbr="$OPTARG"
        ;;
      o)
        cfg_outputfile="$OPTARG"
        ;;
      v)
        cfg_verbose=1
        ;;
      f)
        cfg_force=1
        ;;
      h)
        showhelp
        exit 1
        ;;
      \?)
        fatal "Invalid option: -$OPTARG"
        ;;
    esac
  done
  shift $((OPTIND-1))
  # print values of global config variables
  verbose "config:"
  verbose "  cfg_verbose=$cfg_verbose"
  verbose "  cfg_confmethod=$cfg_convmethod"
  verbose "  cfg_bitrate=$cfg_bitrate"
  verbose "  cfg_samplingrate=$cfg_samplingrate"
  verbose "  cfg_lamevbr=$cfg_lamevbr"
  if [[ -n "$cfg_outputfile" ]]; then
    if [[ $# > 1 ]]; then
      fatal "option '-o' can only be used with one file"
    fi
    echo "writing output file to '$cfg_outputfile'"
  fi
  for argument in "$@"; do
    if [[ -n "$cfg_outputfile" ]]; then
      handle_file "$argument" "$cfg_outputfile"
    else
      handle_file "$argument"
    fi
  done
else
  showhelp
fi
