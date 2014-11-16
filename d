#!/bin/sh -ex

COMMAND=echo

description() {
  PARSED_ARGUMENTS="$PARSED_ARGUMENTS -d '$*'"
}


while [ $# -gt 0 ]; do
  case "$1" in
    -*) # stacked options   
      OPTS="`echo $1 | sed 's/^-//'`"
      while [ -n "$OPTS" ]; do
        OPTION="`echo $OPTS | sed 's/^\\(-\\).*/\1/'`"
        case "$OPTION" in
          d) shift ; description "$1" ;;
        esac
        OPTS="`echo $OPTS | sed 's/^.//'`"
      done
      ;;
    *) FILE_ARGUMENTS="$FILE_ARGUMENTS '$1'"
  esac
  shift
done

# grab everything after -- as file arguments
while [ $# -gt 0 ]; do
  FILE_ARGUMENTS="$FILE_ARGUMENTS '$1'"
  shift
done


# Do it 
$COMMAND $PARSED_ARGUMENTS -- `echo hi` | cat
