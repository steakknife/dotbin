module Shell
  # returns an Array of String's that can be sourced into shell
  def output
    backend.output
  end

  def to_s
    output.join "\n"
  end

  module Backend
    module Base

      def output_env
        env.map do |var, value_and_export|
          output_setenv(var, *value_and_export)
        end
      end

      def output
        output_env
      end
    end # Base

    module Csh
      # output_path from 'shell/path'
      def output
        output_path + output_env
      end
    end # Csh
  end
end

module Kernel
  def Shell
    Shell.to_s
  end
  module_function :Shell
end
