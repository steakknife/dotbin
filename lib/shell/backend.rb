# 1:1 Backend <--> shell (Shell::Backend::Sh <--> sh)
module Shell
  # is +be+ a valid backend?
  def backend?(be)
    Backend.const_get(be).respond_to? :output_setenv
  end

  # list of all possible backends
  def backends
    Backend.constants.select { |be| backend? be }
  end

  # list of all possible shells
  def shells
    backends.map { |be| backend_to_shell be }
  end

  # +be+ is a Symbol, constant or String
  # returns String
  def backend_to_shell(be)
    raise "Unrecognized backend #{be}" unless backend?(be)
    be.to_s.downcase
  end

  # +shell+ String
  # returns String
  def shell_to_backend(shell)
    shell = shell.to_s
    be = shell[0].upcase + shell[1..-1].downcase
    raise "Unrecognized shell #{shell}" unless backend?(be)
    Backend.const_get(be)
  end

  def backend
    shell_to_backend(SHELL)
  end
end
