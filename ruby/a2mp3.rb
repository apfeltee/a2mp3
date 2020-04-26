#!/usr/bin/ruby

require "ostruct"
require "fileutils"
require "shell"
require "optparse"

=begin
IO.popen(["cat", "-v"], "r+") do |pin, pid|
  pin.write("hello\nworld")
  pin.close_write
  puts pin.read
end
=end

DEFAULT_MEDIA_OPTIONS = OpenStruct.new(
  bitrate: "320k",
  samplingrate: "44100",
  vbr: "4",
)

# use $PATH defaults. most of these can be overridden anyway.
DEFAULT_PROGRAM_OPTIONS = OpenStruct.new(
  mplayer: "mplayer",
  lame: "lame"
)


class BaseConverter
  @@name = "base"

  def initialize(medopts)
  end
end

class MplayerConverter < BaseConverter
  @@name = "mplayer"

  def initialize(medopts)
    @convoptions = [
      "-vo", "null",
      "-vc", "dummy",
      "-af", "resample=#{medopts[:samplingrate]}",
    ]
  end
end

class AnyToMP3
  @@converters = [MplayerConverter]
  attr_accessor :converters

  def initialize(converter, options, files)
    @options = options
    @files = files
    @shell = Shell.new
  end

  def log(str)
    if @options.verbose then
      $stderr.puts("a2mp3: #{str}")
    end
  end
end

def get_converter(name, medopts)
  AnyToMP3.converters.each do |conv|
    if conv.name == name then
      return conv.new(medopts)
    end
  end
  return nil
end

def doit(converter, options, files)
  p options
  p files
  convinst = get_converter(converter, options.media)
  if convinst then
    hnd = AnyToMP3.new(convinst, options, files)
  else
    $stderr.puts("no converter named #{converter.dump} available")
    return 1
  end
end

begin
  converter = "mplayer"
  options = OpenStruct.new(
    media: DEFAULT_MEDIA_OPTIONS,
    verbose: false,
    outtemplate: "%{filename}.%{extname}",
  )
  OptionParser.new {|prs|
    prs.on("-v", "--[no-]verbose", "Toggle verbosity"){|val|
      options.verbose = val
    }
    prs.on("-o<path>", "--output=<path>", "Set output template instead of just replacing file extension") {|s|
      options.outtemplate = s
    }
    prs.on("-c<name>", "--converter=<name>", "select <name> to be the converter. use '-L' to see possible converters"){|s|
      converter = s
    }
  }.parse!
  files = ARGV
  exit(doit(converter, options, files))
end
