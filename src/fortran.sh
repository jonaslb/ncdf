#!/bin/bash

# Takes four arguments
# $1 Routine name
# $2 variable type
# $3 variable precision
# $4 variable dimension
function get_routine_name {
    local name="ncdf"
    [ ! -z "$1" ] && name="${_ROUTINE_NAME}_$1"
    [ ! -z "$2" ] && name="${_ROUTINE_NAME}_${2:0:1}"
    [ ! -z "$3" ] && name="${_ROUTINE_NAME}_$3"
    [ ! -z "$4" ] && name="${_ROUTINE_NAME}_$4D"
    _ps "$name"
}

function _ps {
    printf "%s" "$@"
}

function _nl {
    printf '\n'
}

function get_precisions {
    if [ "$1" == "complex" ]; then
	_ps "dp"
    elif [ "$1" == "real" ]; then
	_ps "sp dp"
    elif [ "$1" == "integer" ]; then
	_ps "is il"
    elif [ "$1" == "logical" ]; then
	_ps "none"
    else
	exit 1
    fi
}

declare -A _var
_var[complex]=cz 
_var[real]=sd 
_var[integer]=il 
_var[logical]=b
_var[character]=s

function get_variable_short {
    if [ "$2" == "dp" ]; then
	local p=1
    elif [ "$2" == "il" ]; then
	local p=1
    else
	local p=0
    fi
    local a="${_var[$1]}"
    _ps "${a:$p:1}"
}

function get_dimensions {
    if [ "$1" == "complex" ]; then
	_ps "0 1 2"
    elif [ "$1" == "real" ]; then
	_ps "0 1 2"
    elif [ "$1" == "integer" ]; then
	_ps "0 1 2"
    elif [ "$1" == "logical" ]; then
	_ps "0 1 2"
    else
	exit 1
    fi
}

function var_dimension {
    local d=$1
    if [ "$d" -gt 0 ]; then
	local tmp=""
	for i in `seq 1 $d` ; do
	    tmp="$tmp,:"
	done
	_ps "(${tmp:1})"
    fi
    _ps ""
}

function add_var_declaration {
    local n="" ; local t=""
    local d="0" ; local p=""
    local s="" ; local p=""
    local extra="" ; local alloc=0
    local newline=1 ; local check=1
    while [ $# -gt 0 ]; do
	# Process what is requested
	local opt="$1"
	case $opt in
	    --*) opt=${opt:1} ;;
	esac
	shift
	case $opt in
	    -nocheck)         check=0 ;;
	    -nonewline)       newline=0 ;;
            -name)            n="$1" ; shift ;;
            -logical|-log)    t="logical" ;;
            -int|-integer)    t="integer" ;;
            -r|-real)         t="real"  ;;
            -c|-complex)      t="complex" ;;
            -char|-character) t="character(len=*)"  ;;
            -type)            t="type($1)" ; shift ;;
            -dimension)  [ "$1" != "0" ] && d="$1" ; shift ;;
            -size)       [ "$1" != "0" ] && s="$1" ; shift ;;
            -precision)  [ "$1" != "none" ] && p="$1" ; shift ;;
            -opt|-optional)   extra="$extra, optional" ;;
            -alloc|-allocatable)   alloc=1 ; extra="$extra, allocatable" ;;
            -pointer)   alloc=1 ; extra="$extra, pointer" ;;
	    -target)   extra="$extra, target" ;;
            -in)   extra="$extra, intent(in)"  ;;
            -out)   extra="$extra, intent(out)"  ;;
            -inout)   extra="$extra, intent(inout)"  ;;
	esac
    done
    d=$(var_dimension $d)
    if [ -z "$d" -a $check -eq 1 ]; then
	# If the dimension is zero...
	extra="${extra//, allocatable/}"
	extra="${extra//, pointer/}"
    fi
    if [ ! -z "$s" ]; then
	d="($s)"
    fi	
    [ ! -z "$p" ] && \
	p="($p)"
    _ps "    $t$p$extra :: $n$d"
    [ $newline -eq 1 ] && printf "\n"
}
    