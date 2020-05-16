#!/usr/bin/env ruby
require "yaml"
$LOAD_PATH << File.expand_path("../", File.realpath(__FILE__))
require "gmt-tools-lib"
require "gmt-tools-config"

def usage
  STDERR.print <<EOS
#{$0} yaml_file
EOS
end

if ARGV.length < 1
  usage
  exit 1
end

tool = GmtToolsLib.new()
tool.load_from_file ARGV[0]
tool.run
