# `require 'utils/platform'` adds the appropriate platform-specific methods to Utils
# 
#
dir = File.dirname(File.dirname(__FILE__))
$:.unshift dir unless $:.include? dir

require 'utils'

begin
  # determine platform
  platform = Utils.uname.downcase

  # require 'utils/{{platform}}'
  platform_module_file = File.join('utils', platform) 
  require platform_module_file

  # merge platform module methods into Utils
  ::Utils.module_exec do
    platform_module = Utils.const_get(platform[0].upcase + platform[1..-1])
    include platform_module 
    extend platform_module
  end
rescue LoadError # shit happens, get a helmet
  debug "Missing or problem requiring #{platform_module_file}"
end
