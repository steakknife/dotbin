require 'fileutils'
dir = File.dirname(File.dirname(__FILE__)); $:.unshift dir unless $:.include? dir
require 'utils'
require 'shell/escape'

# appends to ~/.man.conf by default, so alias man='man -C ~/.man.conf' is needed
module Shell
  include Utils
  include Escape
  extend self

  def reset_manpath(manpath_conf = '~/.man.conf')
    manpath_conf = normalize_path(manpath_conf)
    FileUtils.rm_f(manpath_conf)
  end

  def add_manpath(m, manpath_conf = '~/.man.conf')
    manpath_conf = normalize_path(manpath_conf)
    lines = (File.read(manpath_conf) rescue '').split("\n")

    m = normalize_path(m)
    m = escape_dq(m)
    new_line = "MANPATH #{m}\n"

    return if lines.include? new_line # nothing to do

    File.open(manpath_conf, 'a+') { |f| f.write(new_line) }
  end

  # prepends to ~/.man.conf by default, so alias man='man -C ~/.man.conf' is needed
  def prepend_manpath(m, manpath_conf = '~/.man.conf')
    manpath_conf = normalize_path(manpath_conf)
    lines = File.read(manpath_conf).split("\n")

    m = normalize_path(m)
    m = escape_dq(m)
    new_line = "MANPATH #{m}"

    return if lines.include? new_line # nothing to do
    lines.unshift new_line
    File.open(manpath_conf, 'w') { |f| f.write(lines.join "\n") }
  end
end # Shell
