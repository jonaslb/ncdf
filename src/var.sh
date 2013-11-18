#!/bin/bash

# This code creates the underlying code for creating a dynamic variable
# which in principle can take on any form of intrinsic variable types in
# the FORTRAN language.
# It is based on a single type which contains pointers to each of the
#  - types
#    - dimensions
# and does only occupy a single 2 byte token for retaining information about
# the content of the dynamical variable.
# 
# In this regard we design the variable via these contstructs:
#   type(var) :: v
# We could overload the assignment operator and thus force de/con-struction
# of variables via normal: v = 'a' ; v = 1. However we don't for reasons of clarity.
#
# Some key-points to notice when using it:
#   - it behaves like normal fortran '=', '=>'
#   - it is to be considered a pointer in all regards
#
# However that poses a few questions and difficulties.
#
# Instead we do these few things:
#   subroutine assign(<intrinsic|type(var)>,<type(var)|intrinsic>,...)
#   subroutine associate(<intrinsic|type(var)>,<type(var)|intrinsic>,...)
#
# The default when 'assign' a variable is:
#   1. deallocate previous content
#   2. nullify previous content
#   3. allocate to present size
#   4. copy over content
# I.e. the default is equivalent to '='
#    opt-par 'dealloc':
#     - if .true. will behave as above (i.e. the default behaviour)
#     - if .false. it will assume that the memory address is saved somewhere else
#       so will follow these steps:
#       1. nullify previous content
#       2. allocate to present size
#       3. copy over content
#
# 
# For the 'associate' a variable is:
#   1. nullify previous content
#   2. point to new content
# I.e. the default is equivalent to '=>' (i.e. you have the possibility
# of leaving behind un-reachable memory).
#    opt-par 'dealloc':
#     - if .false. will behave as above (i.e. the default behaviour)
#     - if .true. it will assume that the memory address should be released
#       so will follow these steps:
#       1. deallocate previous content
#       2. nullify previous content
#       3. point to the new content
#
# This makes sense from a programmers point of view as the 
# work-flow should be strictly the same as regular '=' and '=>' for variables.
# 
# Take home message: THE PROGRAMMER SHOULD KEEP TRACK OF MEMORY, WE DON'T DO GARBAGE COLLECTING!
#
# However, one could imagine a case where one does not wish to deallocate,
# then one should do:
#   assign(<>,<>,dealloc=.false.)
# , for instance if we have done:
#   assign(v,integer(:))
#   associate(integer(:),v)
#   assign(v,real(:),dealloc=.false.)
# then the memory location of the 'integer(:)' variable is retained.

# So the available interfaces for accessing the variable are these routines:
# Note that the following translation table applies:
#   @ is either an intrinsic fortran type or 'type(var)'
#   * is the 'type(var)'
#   # is an intrinsic fortran type
#
# When an optional statement is present the left-most is the default
# behaviour
#
#  <T|F> assign(@,@,dealloc=<T|F>)
#  <T|F> associate(@,@,dealloc=<F|T>)
#  call delete(*)
#  call nullify(*)
#   @ <|>|<=|>=|==|/= @ (if * is not of type # returns .false. unless /=)
#



# Create the input for the var.f90
types="real complex integer logical"

# The type inclusion 
# type ::
type_file="var_type.inc"

# The routine declarations 
# interface <>
#   module procedure <1>
#   module procedure <1>
# end interface
mod_file="var_mods.inc"

# Functions under contains
func_file="var_funcs.inc"

# File for delete
delete_file="var_delete.inc"

# File for nullification
nullify_file="var_nullify.inc"

files="$type_file $mod_file $func_file $delete_file $nullify_file"

# Clean up
rm -f $files

source fortran.sh

function check_size {
    local v=$1
    local data=$2
    local dim=$3
    for i in `seq 1 $dim` ; do
	_ps "size($v,$i) == size($data,$i)"
	if [ $i -lt $dim ]; then
	    _psnl " .and. &"
	fi
    done
}


# First we create all the types
{
for typ in $types ; do
    for prec in $(get_precisions $typ) ; do

        # create the type
	add_var_declaration -$typ -precision $prec \
	    -nocheck -pointer -nonewline
	
	print_comma=0
	
	for dim in $(get_dimensions $typ) ; do
	    [ $print_comma -eq 1 ] && _ps ", " >> $type_file
	    _ps "$(get_variable_short $typ $prec)$dim$(var_dimension $dim)=>null()"
	    print_comma=1
	done
	
	_nl

    done
done
# We only allow 1D chars
_psnl "character, pointer :: a1(:)=>null()"
} >> $type_file



# Create the function interface for assign associate
{
for int in assign associate ; do
    _psnl "interface $int"
    for typ in character $types ; do
	for prec in $(get_precisions $typ) ; do
	    
	    for dim in $(get_dimensions $typ) ; do
		_psnl "  module procedure ${int}_get_$(get_variable_short $typ $prec)$dim"
		_psnl "  module procedure ${int}_set_$(get_variable_short $typ $prec)$dim"
	    done
	    
	done
    done
    _psnl 'end interface'
done
} >> $mod_file


####################### Routines ########################

# We want functions on the basis of
#   call assign(lhs,rhs,dealloc)
#   call associate(lhs,rhs,dealloc)

 ############ SET ##########
{
int=assign_set
for typ in $types ; do
 for prec in $(get_precisions $typ) ; do
  for dim in $(get_dimensions $typ) ; do

      tmp_func() {
          local i
          if [ $1 -eq 0 ]; then
              _ps "allocate(this%$v)" ; _nl
          else
              _ps "allocate(this%$v("
              for i in `seq 1 $1` ; do
                  _ps "size(rhs,$i)"
                  [ $i -lt $1 ] && _ps ","
              done
              _ps "))" ; _nl
          fi
      }

      v=$(get_variable_short $typ $prec)$dim
      sub_name=${int}_$(get_variable_short $typ $prec)$dim

      # ----- create the routine
      _psnl "subroutine $sub_name(this,rhs,dealloc)"
      
      # this variable
      add_var_declaration -type var -inout -name this
      # assignment variable
      add_var_declaration -nocheck -$typ -precision $prec \
	  -dimension $dim -in -name rhs

      add_var_declaration -logical -in -optional -name dealloc
      add_var_declaration -logical -name ldealloc

      # We have two scenarios:
      _psnl "ldealloc = .true."
      _psnl "if(present(dealloc))ldealloc = dealloc"

      _psnl "if (.not. ldealloc) then"
      # If the user has requested to not deallocate
      # we assume that the user wishes to retain the address-space
      _psnl "call nullify(this)"
      _psnl "this%t = '$v'"
      tmp_func $dim
      _psnl "this%$v = rhs"
      _psnl "return"
      _psnl "end if"
      # Else the variable should be de-allocated
      # We only deallocate if the type is not the same
      _psnl "ldealloc = this%t /= '$v'"
      if [ $dim -gt 0 ]; then
	  # We have that * == #
	  # we will only deallocate if the dimensions does not match
	  _psnl "if (.not.ldealloc) then"
	  _ps "ldealloc = "
	  check_size "this%$v" rhs $dim ; _nl
	  _psnl "end if"
      fi

      _psnl "if (ldealloc) then"
      # deallocate
      _psnl "call delete(this)" # we can safely delete
      _psnl "this%t = '$v'"
      tmp_func $dim
      _psnl "end if"
      
      # We know know that we may overwrite the data...
      _psnl "this%$v = rhs"

      _psnl "end subroutine $sub_name"
  done
 done
done

# ----- create the routine
sub_name=assign_var
_psnl "subroutine $sub_name(lhs,rhs,dealloc)"
# this variable
add_var_declaration -type var -inout -name lhs
add_var_declaration -type var -in    -name rhs
add_var_declaration -logical -in -optional -name dealloc
add_var_declaration -logical -name ldealloc
# We have two scenarios:
_psnl "ldealloc = .true."
_psnl "if(present(dealloc))ldealloc = dealloc"
_psnl "if (.not. ldealloc) then"
# If the user has requested to not deallocate
# we assume that the user wishes to retain the address-space
_psnl "call nullify(lhs)"
_psnl "lhs%t = rhs%t"
used=0
tmp_func() {
    local i
    if [ $1 -eq 0 ]; then
	_psnl "allocate(lhs%$v)"
    else
	_ps "allocate(lhs%$v("
	for i in `seq 1 $1` ; do
	    _ps "size(rhs%$v,$i)"
	    [ $i -lt $1 ] && _ps ","
	done
	_psnl "))"
    fi
}
for typ in $types ; do
  for prec in $(get_precisions $typ) ; do
    for dim in $(get_dimensions $typ) ; do
      v=$(get_variable_short $typ $prec)$dim
      if [ $used -eq 0 ]; then
	  used=1
      else
	  _ps "else "
      fi
      _psnl "if(rhs%t=='$v')then"
      tmp_func $dim
      _psnl "lhs%$v = rhs%$v"
      
    done
  done
done
_psnl "end if"
_psnl "return"
_psnl "end if"

_psnl "call delete(lhs)"
_psnl "lhs%t = rhs%t"
used=0
for typ in $types ; do
  for prec in $(get_precisions $typ) ; do
    for dim in $(get_dimensions $typ) ; do
      v=$(get_variable_short $typ $prec)$dim
      if [ $used -eq 0 ]; then
	  used=1
      else
	  _ps "else "
      fi
      _psnl "if(rhs%t=='$v')then"
      tmp_func $dim
      _psnl "lhs%$v = rhs%$v"
      
    done
  done
done
_psnl "end if"
_psnl "end subroutine $sub_name"


# Here we create the function for the assignment overload
typ=character
prec=$(get_precisions $typ)
dim=$(get_dimensions $typ)

int=assign_set
v=$(get_variable_short $typ $prec)$dim
sub_name=${int}_$(get_variable_short $typ $prec)$dim
_psnl "subroutine $sub_name(this,rhs,dealloc)"

add_var_declaration -type var -inout -name this
add_var_declaration -nocheck -$typ -precision $prec \
    -in -name rhs
add_var_declaration -logical -in -optional -name dealloc
add_var_declaration -logical -name ldealloc
add_var_declaration -int -name i

    # We have two scenarios:
_psnl "ldealloc = .true."
_psnl "if(present(dealloc))ldealloc = dealloc"

_psnl "if (.not. ldealloc) then"
    # If the user has requested to not deallocate
    # we assume that the user wishes to retain the address-space
_psnl "call nullify(this)"
_psnl "this%t = '$v'"
_psnl "allocate(this%$v(len_trim(rhs)))"
_psnl "do i = 1 , len_trim(rhs)"
_psnl "this%$v(i) = rhs(i:i)"
_psnl "end do"
_psnl "return"
_psnl "end if"
    # Else the variable should be de-allocated
    # We only deallocate if the type is not the same
_psnl "ldealloc = this%t /= '$v'"
if [ $dim -gt 0 ]; then
        # We have that * == #
        # we will only deallocate if the dimensions does not match
    _ps "if (.not.ldealloc) "
    _ps "ldealloc = len_trim(rhs)/=size(this%$v,1)"
    _nl
fi

_psnl "if (ldealloc) then"
_psnl "call delete(this)"
_psnl "this%t = '$v'"
    # Add allocation statement
_psnl "allocate(this%$v(len_trim(rhs)))"
_psnl "end if"

_psnl "do i = 1 , len_trim(rhs)"
_psnl "this%$v(i) = rhs(i:i)"
_psnl "end do"

_psnl "end subroutine $sub_name"

} >> $func_file

# Create the set functions
int=associate_set
{
    for typ in character $types ; do
     for prec in $(get_precisions $typ) ; do
      for dim in $(get_dimensions $typ) ; do
	  v=$(get_variable_short $typ $prec)$dim
	  sub_name=${int}_$(get_variable_short $typ $prec)$dim
	  _psnl "subroutine $sub_name(this,rhs,dealloc)"
	  
	   # this variable
	  add_var_declaration -type var -inout -name this
	  
	  add_var_declaration -nocheck -$typ -precision $prec \
	      -target -in -dimension $dim -name rhs

	  add_var_declaration -logical -in -optional -name dealloc
	  add_var_declaration -logical -name ldealloc

	  # We have two scenarios:
	  _psnl "ldealloc = .false."
	  _psnl "if(present(dealloc))ldealloc = dealloc"

	  _psnl "if (ldealloc) then"
	  _psnl "call delete(this)"
	  _psnl "else"
	  _psnl "call nullify(this)"
	  _psnl "end if"
	  _psnl "this%t = '$v'"
	  _psnl "this%$v => rhs"
	  
	  _psnl "end subroutine $sub_name"
      done
     done
    done
} >> $func_file

 ############ SET ##########

 ############ GET ##########

# Create the get
for int in assign_get ; do
{
    for typ in $types ; do
     for prec in $(get_precisions $typ) ; do
      for dim in $(get_dimensions $typ) ; do
	  v=$(get_variable_short $typ $prec)$dim
	  sub_name=${int}_$(get_variable_short $typ $prec)$dim
	  _psnl "subroutine $sub_name(lhs,this,success)"

	  add_var_declaration -nocheck -$typ -precision $prec \
	      -out -dimension $dim -name lhs
	  add_var_declaration -type var -in -name this
	  add_var_declaration -logical -out -optional -name success
	  add_var_declaration -logical -name lsuccess
	  
	  _psnl "lsuccess = this%t=='$v'"
	  _psnl "if (lsuccess) then"
	  for i in `seq 1 $dim` ; do
	      _psnl "lsuccess = lsuccess .and. size(this%$v,$i)==size(lhs,$i)"
	  done
	  _psnl "end if"
	  _psnl "if (present(success)) success = lsuccess"
	  _psnl "if (.not. lsuccess) return"
	  _psnl "lhs = this%$v"
	  
	  _psnl "end subroutine $sub_name"
      done
     done
    done
} >> $func_file
done

# Here we create the function for the assignment overload
typ=character
prec=$(get_precisions $typ)
dim=$(get_dimensions $typ)
# this is char(len=*) = (type(var)(i:i),i=1,N)
int=assign_get
{
    v=$(get_variable_short $typ $prec)$dim
    sub_name=${int}_$(get_variable_short $typ $prec)$dim
    _psnl "subroutine $sub_name(lhs,this,success)"
    add_var_declaration -nocheck -$typ -precision $prec \
	-out -name lhs
    add_var_declaration -type var -in -name this
    add_var_declaration -logical -out -optional -name success
    add_var_declaration -logical -name lsuccess
    add_var_declaration -int -name i

    _psnl "lsuccess = this%t=='$v'"
    _psnl "if (lsuccess) then"
    _psnl "lsuccess = lsuccess .and. size(this%$v,1)<=len(lhs)"
    _psnl "end if"

    _psnl "if (present(success)) success = lsuccess"
    _psnl "if (.not. lsuccess ) return"

    _psnl "lhs = ' '"
    _psnl "do i = 1 , size(this%$v,1)"
    _psnl "lhs(i:i) = this%$v(i)"
    _psnl "end do"

    _psnl "end subroutine $sub_name"
} >> $func_file


int=associate_get
{
    for typ in $types ; do
     for prec in $(get_precisions $typ) ; do
      for dim in $(get_dimensions $typ) ; do
	  v=$(get_variable_short $typ $prec)$dim
	  sub_name=${int}_$(get_variable_short $typ $prec)$dim
	  _psnl "subroutine $sub_name(lhs,this,dealloc,success)"
	  
	  add_var_declaration -nocheck -$typ -precision $prec \
	      -pointer -dimension $dim -name lhs
	  add_var_declaration -type var -in -name this
	  add_var_declaration -logical -in -optional -name dealloc
	  add_var_declaration -logical -out -optional -name success
	  add_var_declaration -logical -name ldealloc
	  add_var_declaration -logical -name lsuccess

	  _psnl "lsuccess = this%t=='$v'"
	  _psnl "if (lsuccess) then"
	  for i in `seq 1 $dim`  ; do
	      _psnl "lsuccess = lsuccess .and. size(this%$v,$i)>size(lhs,$i)"
	  done
	  _psnl "end if"
	  
	  _psnl "if (present(success)) success = lsuccess"
	  _psnl "if (.not. lsuccess ) return"
	  
	  _psnl "ldealloc = .false."
	  _psnl "if(present(dealloc))ldealloc = dealloc"
	  
	  _psnl "if (ldealloc.and.associated(lhs)) then"
	  _psnl "deallocate(lhs)"
	  _psnl "end if"
	  _psnl "lhs => this%$v"
	  
	  _psnl "end subroutine $sub_name"
      done
     done
    done
} >> $func_file

# Here we create the function for the assignment overload
typ=character
prec=$(get_precisions $typ)
dim=$(get_dimensions $typ)
# this is char(len=*) = (type(var)(i:i),i=1,N)
int=associate_get
{
    v=$(get_variable_short $typ $prec)$dim
    sub_name=${int}_$(get_variable_short $typ $prec)$dim
    _psnl "subroutine $sub_name(lhs,this,dealloc,success)"
    add_var_declaration -nocheck -$typ "(len=1)" -dimension $dim -precision $prec \
	-pointer -name lhs
    add_var_declaration -type var -in -name this
    add_var_declaration -logical -in -optional -name dealloc
    add_var_declaration -logical -out -optional -name success
    add_var_declaration -logical -name ldealloc
    add_var_declaration -logical -name lsuccess

    _psnl "lsuccess = this%t=='$v'"
    _psnl "if (lsuccess) then"
    _psnl "lsuccess = lsuccess .and. size(this%$v,1)>len(lhs)"
    _psnl "end if"

    _psnl "if (present(success)) success = lsuccess"
    _psnl "if (.not. lsuccess ) return"

    _psnl "ldealloc = .false."
    _psnl "if(present(dealloc))ldealloc = dealloc"
    
    _psnl "if (ldealloc.and.associated(lhs)) then"
    _psnl "deallocate(lhs)"
    _psnl "end if"
    _psnl "lhs => this%$v"
    
    _psnl "end subroutine $sub_name"
} >> $func_file


########## GET #######


# Create the delete function
int=delete
{
    used=0
    for typ in $types ; do
     for prec in $(get_precisions $typ) ; do
      for dim in $(get_dimensions $typ) ; do
	  v=$(get_variable_short $typ $prec)$dim
	  if [ $used -eq 0 ]; then
	      used=1
	  else
	      _ps "else "
	  fi
	  _psnl "if(this%t=='$v'.and.associated(this%$v))then"
	  _psnl "deallocate(this%$v)" 
	  _psnl "nullify(this%$v)"
      done
     done
    done
    _psnl "end if"
} >> $delete_file

# Create the nullify function
int=nullify
{
    for typ in $types ; do
     for prec in $(get_precisions $typ) ; do
      for dim in $(get_dimensions $typ) ; do
	  v=$(get_variable_short $typ $prec)$dim
	  _psnl "nullify(this%$v)"
      done
     done
    done
    _psnl "this%t='  '"
} >> $nullify_file


#################### We create all comparisons operators ###############

# Notice that
# /= '==' .not. ==
# <= '==' .not. >
# >= '==' .not. <
declare -A opName
opName["=="]=eq
opName["=="]=eq
opName[">"]=gt
opName[">="]=ge
opName["<"]=lt
opName["<="]=le
for op in "==" ">" "<" ">=" "<=" ; do
{
 int=${opName[$op]}
 for typ in ${types//complex/} ; do
  for prec in $(get_precisions $typ) ; do
   for dim in $(get_dimensions $typ) ; do
       v=$(get_variable_short $typ $prec)$dim
       sub_name=${int}_l_$(get_variable_short $typ $prec)$dim
       
       _psnl "function $sub_name(this,rhs) result(ret)"
       add_var_declaration -type var -in -name this
       add_var_declaration -nocheck -$typ -precision $prec \
	   -in -dimension $dim -name rhs
       add_var_declaration -logical -name ret

       _psnl "ret = this%t=='$v'"
       _psnl "if (.not. ret) return"
       
       if [ $dim -gt 0 ]; then
	   _psnl "ret = all(this%$v $op rhs)"
       else
	   _psnl "ret = this%$v $op rhs"
       fi
       _psnl "end function $sub_name"

       sub_name=${int}_r_$(get_variable_short $typ $prec)$dim

       _psnl "function $sub_name(lhs,this) result(ret)"
       add_var_declaration -nocheck -$typ -precision $prec \
	   -in -dimension $dim -name lhs
       add_var_declaration -type var -in -name this
       add_var_declaration -logical -name ret

       _psnl "ret = this%t=='$v'"
       _psnl "if (.not. ret) return"

       if [ $dim -gt 0 ]; then
	   _psnl "ret = all(lhs $op this%$v)"
       else
	   _psnl "ret = lhs $op this%$v"
       fi

       _psnl "end function $sub_name"

   done
  done
 done
} >> $func_file
done