# universal shell environment setter
#
# supported shells: Shell.shells
#
# wanted: pdksh ksh fish ...
#
dir = File.dirname(__FILE__); $:.unshift dir unless $:.include? dir
require 'which'
require 'utils'
require 'shell/append_dir_to_env'
require 'shell/backend'
require 'shell/escape'
require 'shell/manpath'
require 'shell/output'
require 'shell/path'
require 'shell/setenv'

module Shell
  include Utils
  extend self

  SHELL = File.basename(ENV['SHELL']).downcase

  def dir?(d)
    Dir.exist?(normalize_path(d))
  end

  # current shell detection: Shell.bash? Shell.zsh? ....
  def respond_to_missing?(m, include_private)
    if m.to_s =~ /\A(.+)\?\z/
      return true if shells.include? $1
    end
    super
  end

  # current shell detection: Shell.bash? Shell.zsh? ....
  def method_missing(m, *args)
    if m.to_s =~ /\A(.+)\?\z/
      return SHELL == $1 if shells.include? $1
    end
    super
  end

  module Backend
    module Base
      extend self

      def env
        @env ||= {}
      end
    end # Base

    module Sh
      include Base
      extend self
    end # Sh

    module Bash
      include Sh
      extend self
    end # Bash

    module Csh
      include Base
      extend self
    end # Csh

    Tcsh = Csh.dup
    Zsh = Bash.dup

  end # Backend
end # Shell
