# universal shell environment setter
#
# supported shells: Shell.shells
#
# wanted: pdksh ksh fish ...
#

module Shell
  PATH_VAR = 'PATH'
  PATH_SEP = ':'

  def add_path?(d)
    d = normalize_path(d)
    add_path(d) if dir? d
  end

  def prepend_path?(d)
    d = normalize_path(d)
    prepend_path(d) if dir? d
  end

  def add_path(m)
    m = normalize_path(m)
    raise "Cannot append nonexistent path '#{m}'" unless dir? m
    backend.add_path(m)
  end

  def prepend_path(m)
    m = normalize_path(m)
    raise "Cannot prepend nonexistent path '#{m}'" unless dir? m
    backend.prepend_path(m)
  end

  module Backend
    module Base
      def prepend_path(new_dir)
        raise "Cannot prepend_path '#{new_dir}' containing '#{PATH_SEP}'" if new_dir.include? PATH_SEP
        return new_dir if path.include? new_dir # already in path
        path.unshift new_dir 
        path_sync
        new_dir
      end

      def add_path(new_dir)
        raise "Cannot add_path '#{new_dir}' containing '#{PATH_SEP}'" if new_dir.include? PATH_SEP
        return new_dir if path.include? new_dir # already in path
        path << new_dir
        path_sync
        new_dir
      end

      # the actual PATH/path as an Array of String
      def path
        @path ||= ENV[PATH_VAR].split PATH_SEP
      end

      def path_sync
        # tc/csh search path is not a process environment variable, but a shell variable (path), so we dont update env
        env[PATH_VAR] = ENV[PATH_VAR] = path.join PATH_SEP # keep our PATH in sync
      end
    end # Base

    module Csh
      # keep our process'es PATH variable synchronized
      # returns current path as String
      def path_sync
        ENV[PATH_VAR] = path.join PATH_SEP 
      end

      # returns Array of String
      def output_path
        if path.size > 1 # not just ['$path']
          ['set path = (' + path.map{ |dir| escape(dir) }.join(' ') + ')'] 
        else
          [] # path unchanged
        end
      end
    end # Csh
  end # Backend
end # Shell
