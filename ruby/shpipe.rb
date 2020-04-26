#!/usr/bin/ruby

require "shell"

sh = Shell.new
sh.system("ls", "-la") | sh.system("cat", "-v")

## also...
=begin
sh.echo(my_string) | sh.system("wc") > "file_path"
xml = (sh.echo(html) | sh.system("tidy", "-q")).to_s
=end

