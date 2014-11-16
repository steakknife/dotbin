#!/bin/sh
set -e
qsgrep() {
  grep $@ >/dev/null 2>&1
}

ised() {
  sed -i '' $@
}

set_setting_ssh_style() {
  if SETTING="`grep \"^[[:blank:]]*$1[[:blank:]]*\" \"$3\"`"; then
    # if the actual is different than the desired (no match), change it
    if echo "$SETTING" | qsgrep "^[[:blank:]]*$1[[:blank:]]*\$"; then
      echo "mod 1"
      echo "s#^[[:blank:]]*$1[[:blank:]]*\$#$1 $2#" "$3"
    elif echo "$SETTING" | qsgrep -v "^[[:blank:]]*$1[[:blank:]]+$2[[:blank:]]*\$"; then
      echo "mod 2"
      echo "'s#^\($1\)[[:blank:]]+.*\$#\1 $2#'" "$3"
    else
      echo "correct"
    fi
  else # setting not present, add it
    echo "$1 $2" >> "$3"
  fi
}

set_setting_ssh_style "$1" "$2" "blah"
