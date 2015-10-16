#/usr/bin/env ruby

require_relative 'lib/everyday_cmd'

include EverydayCmd::Builder

root_command[:path] = command(short_desc: 'path', desc: 'display the path of this file') { puts __FILE__ }

run!(ARGV)