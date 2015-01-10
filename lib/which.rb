# https://gist.github.com/steakknife/88b6c3837a5e90a08296
# Copyright (c) 2014 Barry Allard <barry.allard@gmail.com>
# License: MIT
#
# inspiration: https://stackoverflow.com/questions/2889720/one-liner-in-ruby-for-displaying-a-prompt-getting-input-and-assigning-to-a-var
#
# Which Bourne shell?
#
#     require 'which'
#
#     Which 'sh'
#
#
#  Or all zsh(es)
#
#     require 'which'
#
#     WhichAll 'zsh'
#
module Which
  # similar to `which {{cmd}}`, except relative paths *are* always expanded
  # returns: first match absolute path (String) to cmd (no symlinks followed),
  #          or nil if no executable found
  def which(cmd)
    which0(cmd) do |abs_exe|
      return abs_exe
    end
    nil
  end

  # similar to `which -a {{cmd}}`, except relative paths *are* always expanded
  # returns: always an array, or [] if none found
  def which_all(cmd)
    results = []
    which0(cmd) do |abs_exe|
      results << abs_exe
    end
    results
  end

  def real_executable?(f)
    File.executable?(f) && !File.directory?(f)
  end

  def executable_file_extensions
    ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
  end

  def search_paths
    ENV['PATH'].split(File::PATH_SEPARATOR)
  end

  def find_executable(path, cmd, &_block)
    executable_file_extensions.each do |ext|
      # rubocop:disable Lint/AssignmentInCondition
      if real_executable?(abs_exe = File.expand_path(cmd + ext, path))
        yield(abs_exe)
      end
      # rubocop:enable Lint/AssignmentInCondition
    end
  end

  # internal use only
  # +_found_exe+ is yielded to on *all* successful match(es),
  #              with path to absolute file (String)
  def which0(cmd, &found_exe)
    # call expand_path(f, nil) == expand_path(f) for relative/abs path cmd
    find_executable(nil, cmd, &found_exe) if File.basename(cmd) != cmd

    search_paths.each do |path|
      find_executable(path, cmd, &found_exe)
    end
  end

  module_function(*public_instance_methods) # `extend self`, sorta
end

# make Which() and WhichAll() work
module Kernel
  # rubocop:disable Style/MethodName
  # return abs-path to +cmd+
  def Which(cmd)
    Which.which cmd
  end
  module_function :Which

  # return all abs-path(s) to +cmd+ or [] if none
  def WhichAll(cmd)
    Which.which_all cmd
  end
  module_function :WhichAll
  # rubocop:enable Style/MethodName
end
