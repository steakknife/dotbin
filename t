#!/bin/sh

TARGET_FILE="$1"
[ -z "$TARGET_FILE" ] && exit 1

DIRNAME="`\dirname \"$TARGET_FILE\"`"
TARGET_FILE_PWD="$PWD/$TARGET_FILE"
LINK="`\readlink -- \"$TARGET_FILE_PWD\"`"

# if the target dirname does not exist, fail
[ ! -d "$DIRNAME" ] && exit 1

# if TARGET_FILE is a symlink pointing to a directory
if [ -h "$TARGET_FILE_PWD" ] && [ -d "$LINK" ]; then
  CWD="$TARGET_FILE_PWD"
else
  CWD="$DIRNAME"
fi

\cd -- "$CWD"

# if the target is a symlink, display it instead
if [ -h "$TARGET_FILE_PWD" ]; then
  RESULT="$LINK"
else
  RESULT="`pwd -P`/`\basename -- \"$TARGET_FILE_PWD\"`"
fi

echo $RESULT
