require 'utils'
# no operator precedence!
autoload :YAML, 'yaml'
module Packages
  module Gems
    include Utils
    extend self

    SYSTEM_GEMS = %w[bigdecimal CFPropertyList minitest io-console json rake rdoc]
    FILES = ['/etc/gem.yaml', '/usr/local/etc/gem.yaml', File.join(HOME, 'bin', 'etc', 'gem.yaml')]

    ALL_ENGINES = 'jruby rubinius mri'
    ALL_OSES = 'solaris freebsd openbsd netbsd linux osx windows'
    OR_OPERATORS = '|| | or'
    AND_OPERATORS = '&& & and'
    NOT_OPERATORS = '! ~ ^ - not'

    def engine
      RUBY_ENGINE
    end

    def version
      RUBY_VERSION
    end

    def os
      case uname.downcase
      when 'solaris', 'freebsd', 'netbsd', 'openbsd', 'linux'
        uname
      when 'darwin'
        'osx'
      when 'cygwin', RUBY_PLATFORM =~ /win(32|dows|ce)|(ms|cyg|bcc)win|m  ingw32|djgpp/i || ENV['OS'] == 'Windows_NT'
        'windows'
      else
        'unknown'
      end
    end

    def match?(string)
      result = false
      first = true
      operator = :or
      tokens = string.downcase.split
      fail 'missing tokens' if tokens.empty?
      debug "processing #{tokens}"
      tokens.each {|token|
        if first
          return true if 'standard' == token
        else # not first
          if OR_OPERATORS.include? token
            operator = :or
            next
          elsif AND_OPERATORS.include? token
            operator = :and
            next
          elsif NOT_OPERATORS.include? token
            if operator == :and
              operator = :not_and
            elsif operator == :or
              operator = :not_or
            else
              fail 'Bad placement of a not operator'
            end
            next
          end
        end

        if '!^-~'.include? token[0]
          token = token[1..-1]
          invert = true
        else
          invert = false
        end

        current =
          if ALL_OSES.include?(token)
            os == token
          elsif ALL_ENGINES.include?(token)
            engine == token
          elsif token == 'rbx'
            engine == 'rubinius'
          elsif token =~ /\A[0-9][0-9\.]*\z/
            version.include?(token)
          else
            fail "invalid os or ruby engine: '#{token}'"
          end ^ invert

        case operator
        when :or
          result ||= current
        when :and
          result &&= current
        when :not_or
          result ||= !current
        when :not_and
          result &&= !current
        end

        operator = :or
        first = false
      }
      debug "match? #{string} = #{result}"
      result
    end

    def run_file(gem_exe, filename)
      debug "trying #{filename}"
      return unless File.exist?(filename)
      debug "running #{filename}"
      gems = []
      YAML.load_file(filename).each { |item|
        if item.is_a? Hash
          item.each { |gem, condition|
            gems << gem if match? condition
          }
        else
          gems << item
        end
      }
      install gem_exe, gems
    end

    def install(gem_exe, *gems)
      gems = gems.flatten - SYSTEM_GEMS
      return if gems.empty?
      sh gem_exe, 'install', *gems
    end

    def ruby_system_env(&_block)
      ENV.subenv do
        %w(RUBY_ROOT RUBY_ENGINE RUBY_VERSION GEM_ROOT GEM_HOME GEM_PATH).map do |k|
          ENV.delete k
        end
        path = ENV['PATH']
        path = path.split(':')
        path = path.reject { |x| x =~ ENV['RUBIES_ROOT'] }
        path = path.compact
        path = path.join(':')

        ENV['PATH'] = path
        yield
      end
    end

    def ruby_env(gem_exe, &_block)
      if gem_exe == '/usr/bin/gem'
        return ruby_system_env(&_block)
      end
      ruby_bin = File.dirname(gem_exe)
      ruby_root = File.dirname(ruby_bin)
      ruby = File.basename(ruby_root)
      ruby_engine, ruby_version = ruby.split '-'
      gem_root = ruby_root + '/lib/ruby/gems/shared'
      gem_home = File.join(HOME, '.gem', ruby_engine, ruby_version)
      ENV.subenv do
        ENV['RUBY_ROOT'] = ruby_root 
        ENV['RUBY_ENGINE'] = ruby_engine
        ENV['RUBY_VERSION'] = ruby_version
        ENV['GEM_ROOT'] = gem_root
        ENV['GEM_HOME'] = gem_home
        ENV['GEM_PATH'] = gem_home + ':' + gem_root
        ENV['PATH'] = ruby_bin + ':' + ENV['PATH']
        yield
      end
    end

    # list all gems
    def raw_list(gem_exe)
      list = ruby_env(gem_exe) do
        %x(#{gem_exe} list --no-versions).chop
      end
      fail 'gem list failed' unless $?.success?
      list.split("\n").reject { |x| x.empty? || x[0] == '*' }
    end

    # list all gems (except system gems)
    def list(gem_exe)
      raw_list(gem_exe) - SYSTEM_GEMS
    end

    def gem_exe_by_engine(engine)
      File.join(engine, 'bin', 'gem')
    end

    def gem(gem_exe, *args)
      ruby_env(gem_exe) do
        sh gem_exe, *args
      end
    end

    def uninstall_all_by_gem_exe(gem_exe)
      installed_gems = list(gem_exe)
      return if installed_gems.empty?
      gem gem_exe, 'uninstall', '-aIx', '--force', *installed_gems
    end

    def install_all_by_gem_exe(gem_exe)
      debug "gems installer os=#{os} engine=#{engine} version=#{version}"
      FILES.each { |f| run_file(gem_exe, f) }
    end

    def reinstall_all_by_engine(engine)
      gem_exe = gem_exe_by_engine(engine)
      return unless File.exist? gem_exe
      uninstall_all_by_gem_exe(gem_exe)
      install_all_by_gem_exe(gem_exe)
    end

    def engines
      fail "RUBIES_ROOT must be set" unless ENV['RUBIES_ROOT']
      Dir[File.join(ENV['RUBIES_ROOT'], '*')]
    end

    def uninstall_all
      engines.map { |e| uninstall_all_by_engine(e) }
    end

    def install_all
      engines.map { |e| install_all_by_engine(e) }
    end

    def reinstall_all
      engines.map { |e| reinstall_all_by_engine(e) }
    end
  end
end
