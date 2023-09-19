export HISTFILE='/dev/null'
export INPUTRC='/etc/inputrc'
export LANG='en_US'
export LC_ALL='C'
export PATH=$PATH':/usr/local/bin:/usr/local/sbin'
export PS1='[\[\e[1;31m\]\u\[\e[m\]@\[\e[1;32m\]\h\[\e[m\] \[\e[1;33m\]\w\[\e[m\]]\$ '
export TERM='vt102'
export TMPDIR='/var/tmp'
export TZ='UTC'

ulimit -c 0

# Unhide console cursor
echo -e -n "\e[?25h"
