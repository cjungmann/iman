# This script file does not run on its own, it must
# be "sourced" into an executable script.

# Values set below when execution starts
declare -a man_seeker_paths=()
declare -a man_seeker_search_order=()

# Development resources:
#   manpath(1):       where local man pages are stored
#   /etc/man_db.conf: SECTION line for directory search order


# Returns an array of paths through which man pages are sought.
#
# Args:
#   (name of array):  name of array where paths will be returned
man_seeker_get_man_paths()
{
    local -n gmp_return="$1"
    local OIFS="$IFS"
    local IFS=:
    gmp_return=( $( manpath ) )
    IFS="$OIFS"
}

# Returns an array of subdirectory names (of man pages) defining
# the location and order to search for a given man pages.
#
# The sections order is taken from the environment variable $MANSECT
# or the SECTION directive of the /etc/man_db.conf.
#
# Args:
#    (name of array): name of array where subdirs will be returned
man_seeker_get_search_order()
{
    local -n gso_return="$1"
    local -a strimmed
    local sorder

    if [ "$MANSECT" ]; then
        strimmed="$MANSECT"
    else
        sorder=$( grep -o ^SECTION\ \*.\*$ /etc/man_db.conf )
        if [[ "$sorder" =~ ^SECTION[[:space:]]+(.*) ]]; then
            local OIFS="$IFS"
            local IFS=$' '
            strimmed=( ${BASH_REMATCH[1]} )
            IFS="$OIFS"
        fi
    fi

    local suffix
    gso_return=()
    for suffix in "${strimmed[@]}"; do
        gso_return+=( "${suffix}" )
    done
}

# Waste no time: call getter functions as soon as they are defined:
man_seeker_get_man_paths "man_seeker_paths"
man_seeker_get_search_order "man_seeker_search_order"

# Get root name of file path (stripped of path and extensions).
# This is used to strip the path and extensions from man page files
# in order to match a requested man page.
#
# Args:
#   (name):   name of string variable in which result is returned
#   (string): string value of file path
man_seeker_path_extract_root()
{
    local -n per_return="$1"
    local per_root="$2"
    local per_trimmed="${per_root##*/}"
    per_return="${per_trimmed%%.*}"
}

# Parse both name and section from a man page name that
# indicates the section in parentheses after the name
# (i.e. bash(1)).
#
# Args:
#   (name):    name of variable in which the name value is returned
#   (name):    name of variable in which the section value is returned
#   (string):  man page name, with or without parentheses
#
# Returns:
#   0 (success): if parsing successful
#   1 (failed):  if parsing failed
man_seeker_path_extract_name_and_section()
{
    local -n pen_name="$1"
    local -n pen_section="$2"
    local pen_path="$3"
    local pen_trimmed="${pen_path##*/}"
    local pen_re='^([^.]+)\.([^.]+)'
    if [[ "$pen_trimmed" =~ $pen_re ]]; then
        pen_name="${BASH_REMATCH[1]}"
        pen_section="${BASH_REMATCH[2]}"
        return 0
    fi

    return 1
}

# Confirm that requested section name is a recognized section name
#
# Args:
#  (string)  section name to confirm
#
# Return
#  0 (success) if requested section name is valid
#  1 (failed)  if requested section name is not value
man_seeker_is_section()
{
    local msis_needle="$1"
    local msis_section
    for msis_section in "${man_seeker_search_order[@]}"; do
        if [ "$msis_section" == "$msis_needle" ]; then
            return 0
        fi
    done

    return 1
}

# Seek a give name in a specific section.  This function will search
# all of the man paths (as defined in MANPATH environment variable)
# where the section is found.
#
# Args:
#   (name)   variable ref to which the found filepath will be written
#   (string) man page to be sought
#   (string) section to search for man page
#
# Return
#   0 (success):  if found, $1 reference will then contain file path
#   1 (failed):   not found, $1 reference will be empty
man_seeker_find_file_by_section()
{
    local -n msffbs_return="$1"
    local msffbs_name="$2"
    local msffbs_section="$3"

    local msffbs_root msffbs_path
    local -a msffbs_files
    local msffbs_file msffbs_trim
    for msffbs_root in "${man_seeker_paths[@]}"; do
        msffbs_path="${msffbs_root}/man${msffbs_section}"
        if [ -d "$msffbs_path" ]; then
            msffbs_files=( "${msffbs_path}/"* )
            for msffbs_file in "${msffbs_files[@]}"; do
                msffbs_trim="${msffbs_file##*/}"
                msffbs_trim="${msffbs_trim%%.*}"
                if [ "$msffbs_trim" == "$msffbs_name" ]; then
                    msffbs_return="$msffbs_file"
                    return 0
                fi
            done
        fi
    done

    msffbs_return=""
    return 1
}

# Break-down, then concatenate regular expression
# for parsing a man page reference like printf(3):
declare -a man_seeker_page_re_arr=(
    '^'
    '('      # begin group 1
    '[^(]+'  # characters up until first open parenthesis
    ')'      # end of group 1

    '('      # begin group 2
    '\('     # escaped parenthesis to match as character

    '('      # begin group 3
    '[^)]+'  # characters up until closing parenthesis
    ')'      # end of group 3

    '\)'     # escape to match parenthesis character
    ')'      # end of group 2

    '?'      # group 2 is optional
)
declare OIFS="$IFS"
IFS=''
declare man_seeker_page_re="${man_seeker_page_re_arr[*]}"
IFS="$OIFS"
unset man_seeker_page_re_arr

# Parse optional number of arguments for requested man page name
# and section.  The section, if specified, may come before the page
# name or as a parenthesised suffix of the page name.
#
# Args:
#  (name):    variable ref to which the full path to the man page will be stored.
#  (name):    variable ref to which the parsed command name will be found.
#  (name):    variable ref to which the parsed section name will be found.
#  (various): section names and man page name
#
# Return:
#   0 (success)  if found, variable reference $1 will contain the full path
#   1 (failed)   not found, variable reference will be empty
man_seeker_find_man_file()
{
    local -n fmf_return="$1"
    local -n fmf_command="$2"
    local -n fmf_section="$3"
    shift 3

    # Ensure cleared to use as flag
    fmf_section=""

    # Parse for name and section
    while [ "$#" -gt 0 ]; do
        if man_seeker_is_section "$1"; then
            if [ -z "$fmf_section" ]; then
                fmf_section="$1"
            fi
            shift
        else
            if [[ "$1" =~ $man_seeker_page_re ]]; then
                fmf_command="${BASH_REMATCH[1]}"
                if [ "${BASH_REMATCH[3]}" ]; then
                    fmf_section="${BASH_REMATCH[3]}"
                fi
            else
                fmf_command="$1"
            fi
            break
        fi
    done

    if [ -n "$fmf_section" ]; then
        if man_seeker_find_file_by_section "fmf_return" "$fmf_command" "$fmf_section"; then
            return 0
        fi
    else
        local fmf_loc_section
        for fmf_loc_section in "${man_seeker_search_order[@]}"; do
            if man_seeker_find_file_by_section "fmf_return" "$fmf_command" "$fmf_loc_section"; then
                fmf_section="$fmf_loc_section"
                return 0
            fi
        done
    fi

    fmf_return=""
    return 1
}



