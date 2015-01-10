module Shell

  def append_dir_to_env(v, d)
    d = normalize_path(d)
    raise "Cannot append nonexistent '#{d}' to #{v}" unless dir? d
    backend.append_dir_to_env(v, d)
  end

  def prepend_path_to_env(v, d)
    d = normalize_path(d)
    raise "Cannot prepend nonexistent '#{d}' to #{v}" unless dir? d
    backend.prepend_dir_to_env(v, d)
  end

  module Backend
    module Base
      def prepend_dir_to_env(var, d)
        raise 'Must use prepand_path or add_path to set PATH' if FORBIDDEN_PATH_SETENV.include? var
        raise "Cannot prepend_dir_to_env '#{d}' to #{var} containing '#{PATH_SEP}'" if d.include? PATH_SEP
        if old = ENV[var]
          # prepend to existing var
          unless old.split(PATH_SEP).include? d
            setenv(var, d + PATH_SEP + old)
          end
        else
          setenv(var, d)
        end
      end

      def append_dir_to_env(var, d)
        raise "Cannot append_dir_to_env '#{d}' to #{var} containing '#{PATH_SEP}'" if d.include? PATH_SEP
        if old = ENV[var]
          # append to existing var
          unless old.split(PATH_SEP).include? d
            setenv(var, old + PATH_SEP + d)
          end
        else
          setenv(var, d)
        end
      end
    end
  end
end
