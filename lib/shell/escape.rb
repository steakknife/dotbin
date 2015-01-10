
module Shell
  module Escape
    extend self

    SQ = "'"
    SQ_NEEDS_QUOTING = /[\$'";%~=#+*?&()<>\[\]!|\\ ]/
    SQ_ESCAPES = {
      SQ => "'\\\\''",
    }

    DQ = '"'
    DQ_NEEDS_QUOTING = /[";%~=#+*?&()<>\[\]!| ]/
    DQ_ESCAPES = {
      DQ => '\\"',
    }

    def escape_sq(value)
      return value unless value =~ SQ_NEEDS_QUOTING
      SQ_ESCAPES.each { |from, to| value.gsub!(from, to) }
      SQ + value + SQ
    end

    def escape_dq(value)
      return value unless value =~ DQ_NEEDS_QUOTING
      DQ_ESCAPES.each { |from, to| value.gsub!(from, to) }
      DQ + value + DQ
    end
  end

  module Backend
    module Sh
      def escape(value)
        raise 'Array environment variables are not allowed in Bourne shell' if value.is_a? Array
        Escape::escape_dq value
      end
    end

    module Bash
      def escape(value)
        if value.is_a? Array
          ARRAY_BEGIN +
             ( value.map{ |x| Escape::escape_dq(x) }.join(' ') ) +
          ARRAY_END
        else
          Escape::escape_dq value
        end
      end
    end

    module Csh
      def escape(value)
        raise 'Array environment variables are not allowed in C shell' if value.is_a? Array
        Escape::escape_dq value
      end
    end
  end
end
