# do not load or require directly, use this instead:
#
#     require 'utils/platform'
#

module Utils::Darwin
  extend self

  def mac?
    mac = !!(uname =~ /arwin/i) 
    debug "Mac = #{mac}"
    mac
  end

  # are Xcode Command-Line Tools (CLT) installed?
  def clt?
    clt = File.directory? '/Library/Developer'
    debug "CLT = #{clt}"
    clt
  end

  def require_mac
    raise UnmetRequirement, 'Only OS X is currently supported' unless mac?
  end

  def require_clt
    raise UnmetRequirement, 'Xcode Commmand Line Tools (CLT) are required' unless clt?
  end
end

