export HISTFILE='/dev/null'
export INPUTRC='/etc/inputrc'
export PS1='[\[\e[1;31m\]\u\[\e[m\]@\[\e[1;32m\]\h\[\e[m\] \[\e[1;33m\]\w\[\e[m\]]\$ '
export TMPDIR='/var/tmp'
export TZ='UTC'

ulimit -c 0

# Unhide console cursor
echo -e -n "\e[?25h"
