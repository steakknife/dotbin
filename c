#!/usr/bin/env bash
set -e

die() {
  echo "$@" >&2
  exit 1
}

# gem install puppet
check_puppet() {
  puppet parser validate "$1"
}

check_ruby() {
  ruby -c "$1"
}

# gem install bundler
check_gemfile_lock() {
  ruby -rrubygems -rbundler -e "
  begin
    Bundler::LockfileParser.new(Bundler.read_file(File.expand_path('$1')))
    puts \"Gemfile.lock $1 OK\"
  rescue Exception
    \$stderr.puts\"Failed parsing Gemfile.lock = $1\"
    exit 1
  end
  "
}

# gem install haml
check_haml() {
  haml -c "$1"
}

check_json() {
  echo "checking JSON $1"
  json_verify -uc < "$1"
}

# gem install yaml
check_yaml() {
  ruby -ryaml -e "
  begin
    YAML::parse(File.read(File.expand_path('$1')))
    puts \"YAML OK\"
  rescue Exception
    \$stderr.puts\"Failed parsing YAML file $1\"
    exit 1
  end
  "
}

# gem install multi_xml
check_xml() {
  ruby -rmulti_xml -e "
  begin
    MultiXml.parse(File.read(File.expand_path('$1')))
    puts \"XML OK\"
  rescue Exception
    \$stderr.puts\"Failed parsing XML file $1\"
    exit 1
  end
  "
}

# gem install sass
check_sass() {
  echo "checking sass $1"
  sass -c --stop-on-error --no-cache --line-numbers "$1"
}

# gem install coffee-script
check_coffee() {
  ruby -rcoffee-script -e "
  begin
    CoffeeScript.compile(File.read(File.expand_path('$1')))
    puts \"CoffeeScript OK\"
  rescue Exception
    \$stderr.puts \"Parse error in CoffeeScript $1\"
    exit 1
  end
  "
}

# gem install iced-coffee-script-source --pre &&  gem install iced-coffee-script
check_iced_coffee() {
  ruby -riced-coffee-script -e "
  begin
    IcedCoffeeScript.compile(File.read(File.expand_path('$1')))
    puts \"Iced (CoffeeScript) OK\"
  rescue Exception
  \$stderr.puts \"Parse error in Iced (CoffeeScript) $1\"
    exit 1
  end
  "
}

# brew install https://github.com/robinhouston/wdg-html-validator/raw/master/homebrew-formula/wdg-html-validator.rb
check_html() {
  validate "$1"
}

check_png() {
  pngcheck "$1"
}

# brew install jslint
check_javascript() {
  jsl -process "$1"
}

# brew install pngcheck
check_png() {
  pngcheck -q "$1"
}

# brew install css-crush
check_css() {
  echo "checking css $1"
  csscrush --trace "$1"
}

# brew install jpeg
check_jpeg() {
  djpeg "$1" >/dev/null
}

check_gif() {
  true
}

unknown() {
  die "Dont know how to check $1"
}

check() {
  case "$1" in
  *.pp)          check_puppet         "$1" ;;

  *.rb)          check_ruby           "$1" ;;
  */Gemfile.lock)check_gemfile_lock   "$1" ;;
  */Gemfile)     check_ruby           "$1" ;;
  *.gemspec)     check_ruby           "$1" ;;
  */config.ru)   check_ruby           "$1" ;;
  */Vagrantfile) check_ruby           "$1" ;;
  */Rakefile)    check_ruby           "$1" ;;

  *.haml)        check_haml           "$1" ;;
  *.sass|*.scss) check_sass           "$1" ;;
  *.css)         check_css            "$1" ;;
  *.coffee)      check_coffee         "$1" ;;
  *.iced)        check_iced_coffee    "$1" ;;
  *.js)          check_javascript     "$1" ;;
  *.html)        check_html           "$1" ;;

  *.png)         check_png            "$1" ;;
  *.gif)         check_gif            "$1" ;;
  *.jpg|*.jpeg)  check_jpeg           "$1" ;;

  *.json)        check_json           "$1" ;;
  *.yaml|*.yml)  check_yaml           "$1" ;;
  */config)        check_yaml           "$1" ;;
  *.xml)         check_xml            "$1" ;;

  *)             unknown              "$1" ;;
  esac
}

filter() {
  egrep -v '/\.git' | egrep -v '(\.rbenv-version|\.rspec|\.rvmrc|\.vagrant|\.DS_Store)'
}

for filename in "$@"; do
  [ "$filename" = '.git' ] && continue

  if [ -d "$filename" ]; then
    find "$filename" -type f
  else
    echo "$filename"
  fi
done | filter | while read -r check_filename ; do
  echo "Checking $check_filename" >&2
  check "$check_filename"
done
