#!/bin/bash

_vpath=.
[ -n "$VPATH" ] && _vpath=$VPATH

# Run the setup in the lib/fdict directory
VPATH="$_vpath/subprojects/fdict" $_vpath/subprojects/fdict/setup.sh $@
retval=$?

exit $retval
