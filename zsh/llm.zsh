# Local AI helpers moved to frozename/llamactl.
# This shim sources the library from $LLAMACTL_HOME so the prior function
# names stay available in any shell that loads this file. The library is
# skipped silently when the clone is not present.

: "${LLAMACTL_HOME:=$DEV_STORAGE/repos/personal/llamactl}"

if [ -f "$LLAMACTL_HOME/shell/llamactl.zsh" ]; then
  source "$LLAMACTL_HOME/shell/llamactl.zsh"
fi
