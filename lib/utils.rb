# influenential environment variables
#
# DEBUG  - show extra debug-info (doesnt set $DEBUG)
# DRY_RUN - don't modify anything, just show what would happen
#
module Utils
  extend self

  HOME = ENV['HOME'] || ENV['HOMEDIR'] || (fail "HOME and HOMEDIR unset")
  DEBUG = !!ENV['DEBUG']
  DRY_RUN = !!ENV['DRY_RUN']
  FILE_TYPES = %w[file directory symlink chardev blockdev].map(&:to_sym)
  EXPAND_REGEX = /`((?:[^`'\\]|'[^']*'|\\.)*)`|\$\(((?:[^`'\\]|'[^']*'|\\.)*)\)|\$([a-zA-Z_]+[a-zA-Z0-9_]*)|\$\{(.+)\}/

  class ShellCommandFailed < StandardError; end
  class UnmetRequirement < StandardError; end

  def debug(*args)
    $stderr.puts(args.join(' ')) if DEBUG
  end

  # based on https://gist.github.com/steakknife/4606598
  def expand_shell_string(string)
    string.gsub(EXPAND_REGEX) {
      if cmd = ($1 || $2)
       %x{#{cmd}}.chop
      elsif var = ($3 || $4)
        ENV[var]
      end
    }
  end

  def normalize_path(dir)
    dir = expand_shell_string(dir)
    dir = File.expand_path(dir)
    dir
  end

  # +opts+ 
  #    :regex => /some regex/  # that which the contents of var must match
  #    :file  => true          # var must be a regular file
  #    :directory  => true     # var must be a directory
  #    :symlink  => true       # var must be a symbolic link
  #    :chardev => true        # var must be a character device
  #    :blockdev => true       # var must be a block device
  def require_env(var, opts = {})
    value = ENV[var]
    raise UnmetRequirement, "Missing required environment variable #{var}" unless value
    regex = opts[:matches]
    raise UnmetRequirement, "Required environment variable #{var} does not match regex #{regex}" unless !!(value =~ regex)

    FILE_TYPES.map do |opt|
      if opts.include? opt
        raise UnmetRequirement, "Environment variable #{var} does not reference a file of the required type: #{opt}" unless File.__send__("#{opt}?".to_sym, value)
      end
    end
  end

  def debug_dry(*args)
    if DRY_RUN
      debug('[dry run] (skipped) ', *args)
    else
      debug(*args)
    end
  end

  def yes_no?(prompt)
    print prompt + ' ? [Yn] > '
    !!(gets.strip! =~ /\Ay|yes\z/i)
  end

  def uname
    @@uname ||= `uname`.chop
  end


  # run a shell command
  # if the exit status is nonzero, raise ShellCommandFailed
  def sh(*args)
    cmd = "'#{args.join "', '"}'" # almost
    debug_dry "sh #{cmd}"
    return if DRY_RUN # if DRY_RUN, dont actually do it
    unless system(*args)
      raise ShellCommandFailed, "#{cmd} returned #{$?.exitstatus}" 
    end
  end

  # remove files, unconditionally
  def rm_f(*args)
    debug_dry "rm -f #{args.join ' '}"
    require 'fileutils'
    return if DRY_RUN # if DRY_RUN, dont actually do it
    FileUtils.rm_f(*args)
  end
 
  # remove files and dirs, unconditionally
  def rm_rf(*args)
    debug_dry "rm -rf #{args.join ' '}"
    require 'fileutils'
    return if DRY_RUN # if DRY_RUN, dont actually do it
    FileUtils.rm_rf(*args)
  end

  # returns: fetches contents of +url+ 
  def download(url)
    debug_dry "download #{url}"
    require 'open-uri'
    return if DRY_RUN # if DRY_RUN, dont actually do it
    open(url).read
  end

  ENV.instance_eval do
    # make a deep copy of ENV
    def push
      Hash[map { |k,v| [k.dup, v.dup] }]
    end

    # restore ENV completely to +old_env+
    def pop!(old_env)
      # add / change
      old_env.map { |k,v| self[k] = v unless self[k] == v }
      # remove
      (self.keys - old_env.keys).map { |k| self.delete k }
    end

    # wrap some code in push/pop! (not thread-safe)
    def subenv(&_block)
      old_env = push
      yield
    ensure
      pop!(old_env)
    end
  end
end
