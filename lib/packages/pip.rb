require 'which'
require 'utils'

# no operator precedence!
autoload :YAML, 'yaml'
module Packages
  module Pip
    include Utils
    extend self

    SYSTEM_PKGS = %w[Magic-file-extensions mercurial wsgiref]
    # --user install so it's local to the user, not the whole system
    # --install-option=--prefix= workaround for brewed python
    # --upgrade so packages are always up-to-date
    # --egg ???? probably for some package to avoid compiling
    SYSTEM_PIP_INSTALL = %w[install --user --upgrade]
           PIP_INSTALL = %w[install --user --install-option=--prefix= --upgrade]
    UNVERIFIED = %w[Pyrex]
    EXTERNAL = %w[Pyrex z3c.zcmlhook z3c.caching]
    FILES = ['/etc/pip.yaml', '/usr/local/etc/pip.yaml', File.join(HOME, 'bin', 'etc', 'pip.yaml')]

    def append_env(var, string_or_nil)
      return unless string_or_nil
      if ENV[var]
        ENV[var] += " #{string_or_nil}"
      else
        ENV[var] = string_or_nil
      end
    end

    def system_pip
      Dir[File.join(HOME, 'Library/Python/*/bin/pip')][0]
    end

    def system_python_config
      Dir['/usr/bin/python-config'][0]
    end

    def system_python
      Dir['/usr/bin/python'][0]
    end

    def ldflags_to_libdirs(ldflags)
      ldflags.split(' ')
             .select { |x| x =~ /\A-L/ }
             .map { |x| x =~ /\A-L(.+)\z/; $1 }
             .join(':')
    end

    PIP_EXES = { 'python2' => proc { resolve_exe 'pip2' },
                 'python3' => proc { resolve_exe 'pip3' },
                 'system'  => proc { system_pip } }

    PYTHON_CONFIG_EXES = { 'python2' => proc { resolve_exe 'python2-config' },
                           'python3' => proc { resolve_exe 'python3-config' },
                           'system'  => proc { system_python_config } }

    PYTHON_EXES = { 'python2' => proc { resolve_exe 'python2' },
                    'python3' => proc { resolve_exe 'python3' },
                    'system'  => proc { system_python } }

    ALL_ENGINES = 'system python2 python3'
    ALL_OSES = 'solaris freebsd openbsd netbsd linux osx windows'
    OR_OPERATORS = '|| | or'
    AND_OPERATORS = '&& & and'
    NOT_OPERATORS = '! ~ ^ - not'

    def show_env
      %w[CPPFLAGS CFLAGS CXXFLAGS LDFLAGS LINKFLAGS PYTHON PYTHON_CONFIG PYTHON_PREFIX PYTHONPATH PYTHON_VERSION PKG_CONFIG_PATH LD_LIBRARY_PATH].each do |x|
        debug "#{x}=#{ENV[x]}"
      end
    end

    def install_system_pip
      debug_dry 'install_system_pip'
      return if DRY_RUN
      require 'open-uri'
      get_pip = open('https://raw.github.com/pypa/pip/master/contrib/get-pip.py').path
      system 'python', get_pip, '--user'
      raise "" unless $?.success 
    rescue SocketError
      fail 'Unable to install system pip due to network error'
    rescue String
      fail 'Unable to install system pip due to pip installation script error'
    end

    def detect_os
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

    def readlink_abs(link)
      result = nil
      FileUtils.cd(File.dirname(link)) do
        real = `readlink "#{link}"`.chop!
        FileUtils.cd(File.dirname(real)) do
          result = File.join(Dir.pwd, File.basename(real))
        end
      end
      result
    end

    def os
      @os ||= detect_os
    end

    def detect_system_engine_ver
      result = case (%x[python --version 2>&1].chop rescue nil)
      when /\APython 3/
        3
      when /\APython 2/
        2
      when nil
        ''
      end
      debug "system version = #{result}"
      result
    end

    def system_engine_ver
      @system_engine_ver ||= detect_system_engine_ver
    end

    def detect_engines
      x = []
      x << 'python2' if Which('python2')
      x << 'python3' if Which('python3')
      x << 'system'  if system_engine_ver
      x
    end

    def all_engines
      @all_engines ||= detect_engines
    end

    def engines
      @engines ||= all_engines.select { |x| ARGV.size == 0 || ARGV.include?(x) }
    end

    def match?(string, engine)
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

        current = if ALL_OSES.include?(token)
          token == os
        elsif ALL_ENGINES.include?(token)
          token == engine
        elsif system_engine_ver == 2
          token == 'system_python2' && engine == 'system'
        elsif system_engine_ver == 3
          token == 'system_python3' && engine == 'system'
        else
          fail 'invalid os or python engine'
        end

        current = !current if invert

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

    def resolve_exe(x)
      return unless x
      x = Which(x)
      readlink_abs(x) if x && File.symlink?(x)
    end

    def pip_exe(engine)
      PIP_EXES[engine].call
    end

    def python_config_exe(engine)
      PYTHON_CONFIG_EXES[engine].call
    end

    def python_exe(engine)
      PYTHON_EXES[engine].call
    end

    def pip_install(*packages, engine)
      packages = packages.flatten - SYSTEM_PKGS
      if engine == 'system' && !DRY_RUN
        # check that system pip is available
        install_system_pip unless system_pip
      end
      args = [ pip_exe(engine) ]
      args += (engine == 'system') ? SYSTEM_PIP_INSTALL : PIP_INSTALL
      args += packages
      args += UNVERIFIED.select { |x| packages.any? { |z| /#{x}/i.match(z) } }
                        .map { |y| ['--allow-unverified', y]  }
                        .flatten

      args += EXTERNAL.select { |x| packages.any? { |z| /#{x}/i.match(z) } }
                      .map { |y| ['--allow-external', y] }
                      .flatten

      sh(*args)
    end

    def fix_shebangs(python_exe)
      debug_dry 'fix_shebangs'
      return if DRY_RUN
      Dir['**/*'].select { |x| File.file? x }
                 .each { |y| `sed -i '' '1s%^#!.*python.*$%#!#{python_exe}%g' #{y}` }
    end

    #def fix_wscript(python_exe)
    #  `sed -i '' "s/ctx.check_tool('python')/ctx.check_tool('#{python_exe}')/g" wscript`
    #  `sed -i '' "s/ctx.tool_options('python')/ctx.tool_options('#{python_exe}')/g" wscript`
    #end

    def manual_install(packages, engine)
      require 'open-uri'
      debug_dry "#{engine} manual install #{packages}"
      return if DRY_RUN
      packages.each do |url|
        tempfile = open(url)
        Dir.mktmpdir('manual_install') do |temppath|
          unless system "tar xf '#{tempfile.path}' -C '#{temppath}'"
            fail "Unable to extract #{url}"
          end

          python_prefix = %x[#{python_config_exe(engine)} --prefix].chomp
          python_exe = python_exe(engine)

          FileUtils.cd(temppath) do
            dirs = Dir['*'].select { |x| File.directory? x}
            FileUtils.cd(dirs[0]) do
              fix_shebangs(python_exe)
              cmd = case
              when File.exist?('setup.py')
                args = [python_exe, 'setup.py', 'install']
                args << '--user' if engine == 'system'
                args.join(' ')
              when File.exist?('waf')
                "./waf configure --prefix=#{python_prefix} && ./waf build && ./waf install"
              when File.exist?('configure')
                "./configure --prefix=#{python_prefix} && make && make install"
              else
                system 'bash'
                fail "Dont know how to install #{url}"
              end
              begin
                sh(cmd)
              rescue
                system 'bash'
                fail "Unable to install #{url}"
              end
            end
          end
        end
      end
    end

    def install_all_by_engine(engine)
      python_config_exe = python_config_exe(engine)
      unless python_config_exe
        $stderr.puts "no python config for engine=#{engine}"
        return
      end
      
      python_exe = python_exe(engine)
      unless python_exe
        $stderr.puts "no python for engine=#{engine}"
        return
      end

      # for Pillow
      more_CFLAGS = '-Qunused-arguments'
      # for py2cairo
      #more_LINKFLAGS = '' #'-search_dylibs_first'

      ENV.subenv do 
        debug "engine=#{engine}"
        ENV['PYTHON'] = python_exe
        ENV['PYTHON_CONFIG'] = python_config_exe
      #  ENV['PYTHON_PREFIX'] = %x(#{python_config_exe} --prefix).chop!
      #  ENV['LINKFLAGS'] = append_env(orig_LINKFLAGS) +
      #                     append_env(more_LINKFLAGS) +
      #                     %x(#{python_config_exe} --ldflags).chop!
        if File.basename(python_config_exe) =~ /-?[[:digit:]]+\.?[[:digit:]]*/
          ENV['PYTHON_VERSION'] = $&
        end
        append_env('CPPFLAGS', more_CFLAGS) # + %x(#{python_config_exe} --include).chop!
        append_env('CFLAGS', more_CFLAGS) # + %x(#{python_config_exe} --include).chop!
        append_env('CXXFLAGS', more_CFLAGS) # + %x(#{python_config_exe} --include).chop!
  #      append_env('LDFLAGS', %x(#{python_config_exe} --ldflags).chop!
        show_env

        FILES.each { |f| install_all_by_filename_and_engine(f, engine)  }
      end
    end

    def install_all
      debug "pip installer os=#{os}"
      ENV.subenv do

        ENV['PKG_CONFIG_PATH'] = '/opt/X11/lib/pkgconfig' # because brewed cairo .pc's are bad
        engines.map { |engine| install_all_by_engine(engine) }
      end
    end

    def install_all_by_filename_and_engine(filename, engine)
      return unless File.exist?(filename)
      debug "running #{filename}"
      YAML.load_file(filename).each { |item|
        if item.is_a? Hash
          item.each { |package, condition|
            if match? condition, engine
              if package =~ /:\/\//
                manual_install package, engine
              else
                pip_install package, engine
              end
            end
          }
        else
          if item =~ /:\/\//
            manual_install item, engine
          else
            pip_install item, engine
          end
        end
      }
    end

    # list all packages
    def raw_list(pip)
      list = %x(#{pip} freeze).chop.split("\n").map { |x| x.sub(/=.*/, '') }
      fail 'pip list failed' unless $?.success?
      list
    end

    # list all gems (except system gems)
    def list(pip)
      raw_list(pip) - SYSTEM_PKGS
    end

    def uninstall_all_by_engine(engine)
      pip = pip_exe(engine)
      return unless pip
      installed_pkgs = list(pip)
      return if installed_pkgs.empty?
      sh pip, 'uninstall', '--yes', *installed_pkgs
    end

    def uninstall_all
      engines.map { |engine| uninstall_all_by_engine(engine) }
    end

    def reinstall_all
      uninstall_all
      install_all
    end
  end
end
