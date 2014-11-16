# SECURITY NOTICE: downloads are INSECURE and UNTRUSTWORTHY because Apple's SSL cert doesn't seem to work with ruby
#
# copyright (c) 2014 Barry Allard
#
# license: MIT
#


require 'fileutils'
require 'open-uri'
require 'openssl'
require 'time'

Signal.trap('INT') {
   $stderr.puts "\n\n  ! User aborted\n"
   exit 1
}

module AppleOSS
  TOP_DIR = 'appleoss' # files will be downloaded here
  ERASE = "\b" * 12

  OSX_VERSIONS_ENDPOINT = 'https://opensource.apple.com/'
  OSX_VERSIONS_REGEX = /<a href="(\/release\/(?:mac-)?os-x-[0-9]+\/)">[^0-9<]*([0-9][0-9.]*)/m
  OSX_VERSIONS_START_LINE = /product-name">OS X</
  OSX_VERSIONS_END_LINE = /product release-list/

  TARBALLS_ENDPOINT = 'https://opensource.apple.com/tarballs/'
  TARBALLS_START_LINE = /<table>/
  TARBALLS_END_LINE = /<\/table>/
  DIR_REGEX = /<a href="([^"]+)">([^\/]*)\/<\/a>/
  PACKAGE_TARBALL_REGEX = /<td valign="top"><a href="([^"\/]+)">.*<\/a><\/td>/


  def self.fetch_uncached(url)
    $stderr.puts "Fetching #{ENDPOINT}"
    open(url).read
  end

  def self.fetch(url)
    (@fetched ||= {})[url] ||= self.fetch_uncached
  end

  def self.fetch_between(url, start_regex, stop_regex)
    started, stopped = false, false
    self.fetch(url).split("\n").map { |line|
      next if stopped
      if started
        if line =~ stop_regex
          stopped = true
          next
        end
        line
      else
        started = true if line =~ start_regex
      end 
    }.compact.join("\n")
  end

  def self.check_file(fn)
    Zlib::GzipReader.open(fn).read rescue false
  end


  def self.relative_release_urls
    Hash[self.fetch_between(OSX_VERSIONS_ENDPOINT, OSX_VERSIONS_START_LINE, OSX_VERSIONS_END_LINE).scan(RELEASE_REGEX).map { |x, y| [y, x] }]
  end

  def self.absolute_release_urls
    Hash[self.relative_release_urls.map { |version, relative_url|
      [version, URI.join(OSX_VERSIONS_ENDPOINT, relative_url).to_s ]
    }]
  end

  def self.osx_versions
    self.relative_release_urls.keys
  end

  def self.release_index_for_version(version)
    self.fetch(self.absolute_release_urls[version])
  end

  def self.relative_tarball_urls_for_version(version)
    (@relative_tarball_urls_for_version ||= {})[version] ||= self.release_index_for_version(version).scan(TARBALL_REGEX).flatten
  end

  def self.tarball_filenames_for_version(version)
    (@tarball_filenames_for_version ||= {})[version] ||= self.relative_tarball_urls_for_version(version).map { |uri| File.basename(uri) } 
  end

  def self.absolute_tarball_urls_for_version(version)
    (@absolute_tarball_urls_for_version ||= {})[version] ||= self.relative_tarball_urls_for_version(version).map { |relative_url|
      URI.join(ENDPOINT, relative_url).to_s
    }
  end

  def self.download_tarball(uri, fn)
    size = nil
    needs_erase = false
    content_length_proc = proc { |content_length|
      size = content_length
      $stderr.puts "  | Downloading #{size} byte(s) from #{uri}"
    }
    progress_proc = proc { |bytes_read_so_far| 
      $stderr.print ERASE + "    %.2f %" % percent = 100.0 * bytes_read_so_far / size 
      needs_erase = true
    }
    options = {
         content_length_proc: content_length_proc,
               progress_proc: progress_proc
    }
    options['If-Modified-Since'] = File.stat(fn).mtime.httpdate if File.exists? fn
    tries = 3
    begin
      open(uri, options) { |r| File.open(fn, 'wb') { |w| w.write(r.read) } }
      raise OpenURI::HTTPError.new "Bad download" unless self.check_file fn
    rescue OpenURI::HTTPError => e
      if needs_erase
        $stderr.print ERASE 
        needs_erase = false
      end
      if e.io.status[0].to_i == 304 && self.check_file(fn)
        $stderr.puts "  | Already downloaded #{uri}"
        return
      end
      options.delete 'If-Modified-Since'
      $stderr.puts "  | Retrying #{uri}"
      retry if (tries -= 1) > 0
      raise
    end
    if needs_erase
      $stderr.print ERASE 
      needs_erase = false
    end
  end

# ---- package downloader

  def self.relative_package_dir_urls
    Hash[self.fetch(TARBALLS_ENDPOINT).scan(DIR_REGEX).map { |dir, package| [package, dir] }]
  end

  def self.absolute_package_dir_urls
    Hash[self.relative_package_dir_urls.map { |package, relative_url|
      [package, URI.join(ENDPOINT, relative_url).to_s]
    }]
  end

  def self.package_index_for_package(package)
    (@package_indicies ||= {})[package] ||= self.package_index_for_package_uncached(package)
  end

  def self.relative_tarball_urls_for_package(package)
    (@relative_tarball_urls_for_package ||= {})[package] ||= self.package_index_for_package(package).scan(PACKAGE_TARBALL_REGEX).flatten
  end

 def self.tarball_filenames_for_package(package)
    (@tarball_filenames_for_version ||= {})[package] ||= self.relative_tarball_urls_for_package(package).map { |uri| File.basename(uri) }
  end

  def self.absolute_tarball_urls_for_package(package)
    (@absolute_tarball_urls_for_package ||= {})[package] ||= self.relative_tarball_urls_for_package(package).map { |relative_url|
      URI.join(TARBALLS_ENDPOINT, self.relative_package_dir_urls[package], relative_url).to_s
    }
  end

  def self.download_package(package)
    $stderr.puts "Downloading source tarballs for package #{package}"

    tarball_urls = self.absolute_tarball_urls_for_package(package)
    filenames = self.tarball_filenames_for_package(package)
    FileUtils.mkdir_p(TOP_DIR)
    Dir.chdir(TOP_DIR) do
      FileUtils.mkdir_p(package)
      Dir.chdir(package) do
        tarball_urls.zip(filenames).each { |uri, fn| self.download_tarball(uri, fn) }
      end
    end
  end

  def self.download_packages_all
    self.packages.each { |package| self.download_package(package) }
  end

# ---- osx downloader

  def self.download_osx_version(version)
    $stderr.puts "Downloading source tarballs for osx #{version}"

    tarball_urls = self.absolute_tarball_urls_for_version(version)
    filenames = self.tarball_filenames_for_version(version)
    FileUtils.mkdir_p(TOP_DIR)
    Dir.chdir(TOP_DIR) do
      FileUtils.mkdir_p(version)
      Dir.chdir(version) do
        tarball_urls.zip(filenames).each { |uri, fn| self.download_tarball(uri, fn) }
      end
    end
  end

  def self.download_osx_all
    self.osx_versions.each { |osx_version| self.download_osx_version(osx_version) }
  end
end

if ARGV.empty?
  AppleOSS.download_packages_all
  AppleOSS.download_osx_all
else
  if ARGV.delete('-l') || ARGV.delete('--list-osx-versions')
    puts AppleOSS.osx_versions
    exit
  end 
  if ARGV.delete('-p') || ARGV.delete('--list-packages')
    puts AppleOSS.packages
    exit
  end
  # check input
  ARGV.map { |arg|
    unless AppleOSS.packages.include?(arg) || AppleOSS.versions.include?(arg)
      fail "Unknown package or osx version #{package}"
    end
  }
  ARGV.map { |arg|
    if AppleOSS.version.include?(arg)
      AppleOSS.download_osx_version(arg)
    else
      AppleOSS.download_package(arg)
    end
  }
end
