module Shell
  FORBIDDEN_SETENV = %w[SHELL UID GID USER LOGNAME PWD]
  FORBIDDEN_PATH_SETENV = %w[PATH path]
  FORBIDDEN_MANPATH_SETENV = %w[MANPATH]

  def setenv(var, value, export=true)
    raise "Cannot use setenv to set any of #{FORBIDDEN_SETENV.join ', '}" if FORBIDDEN_SETENV.include? var
    raise 'Must use prepand_manpath or add_manpath to set MANPATH' if FORBIDDEN_MANPATH_SETENV.include? var
    backend.setenv(var, value, export)
  end

  def setenv_expanded(var, value, export=true)
    value = expand_shell_string(value)
    backend.setenv(var, value, export)
  end

  module Backend
    module Base

      def setenv(var, value, export=true)
        raise 'Must use prepand_path or add_path to set PATH' if FORBIDDEN_PATH_SETENV.include? var
        ENV[var] = value.to_s # keep ENV of this process in-sync so dir? var expansion works
        env[var] = [value, export]
        value
      end
    end

    module Sh
      def output_setenv(var, value, export=true)
        value = escape(value)
        if export
          "#{var}=#{value}; export #{var}"
        else
          "#{var}=#{value}"
        end
      end
    end

    module Bash
      ARRAY_BEGIN = '('
      ARRAY_END   = ')'

      def output_setenv(var, value, export=true)
        value_escaped = escape(value)
        if export && !value.is_a?(Array)
          "export #{var}=#{value_escaped}"
        else
          "#{var}=#{value_escaped}"
        end
      end
    end

    module Csh
      def output_setenv(var, value, export=true)
        raise 'Unexported values are not allowed in C shell' unless export
        value = escape(value)
        "setenv #{var} #{value}"
      end
    end
  end
end
