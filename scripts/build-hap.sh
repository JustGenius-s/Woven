#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
deveco_root=${DEVECO_STUDIO_HOME:-/Applications/DevEco-Studio.app/Contents}
hvigor_bin="$deveco_root/tools/hvigor/bin/hvigorw"

if [ ! -x "$hvigor_bin" ]; then
  echo "DevEco Studio was not found at: $deveco_root" >&2
  echo "Set DEVECO_STUDIO_HOME to the DevEco Studio Contents directory." >&2
  exit 1
fi

cd "$project_dir"
exec /usr/bin/env \
  DEVECO_SDK_HOME="$deveco_root/sdk" \
  JAVA_HOME="$deveco_root/jbr/Contents/Home" \
  NODE_HOME="$deveco_root/tools/node" \
  PATH="$deveco_root/jbr/Contents/Home/bin:$deveco_root/tools/node/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  "$hvigor_bin" assembleHap --mode module -p product=default --no-daemon
