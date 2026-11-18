#!/bin/sh
[ "$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/raven/glass" 2>/dev/null)" = on ] && echo "background_opacity 0.8"
exit 0
