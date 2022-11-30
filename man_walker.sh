# shellcheck shell=bash
# This script file does not run on its own, it must
# be "sourced" into an executable script.

# Following path order from command manpath and the section order,
# visit each file until the callback function returns 0.
#
# Args:
#   (name)  name of callback to which fresh paths will be passed.
#
# Returns:
#   0 if the callback returns 0 (successful search)
#   1 if all directories processed without success.
#   extra parameters are packaged and sent to the callback function
# shellcheck disable=SC2154 # man_seeker_search_order and man_seeker_paths are global
man_seeker_walk_paths()
{
    local wmp_callback="$1"
    shift
    local -a wmp_extra=( "${@}" )

    local wmp_root wmp_subdir wmp_path
    for wmp_root in "${man_seeker_paths[@]}"; do
        for wmp_subdir in "${man_seeker_search_order[@]}"; do
            wmp_path="${wmp_root}/${wmp_subdir}"
            if [ -d "$wmp_path" ]; then
                if "$wmp_callback" "$wmp_path" "${wmp_extra[@]}"; then
                    return 0
                fi
            fi
        done
    done

    return 1
}

# Called by man_seeker_walk_files() for every man file
# on the system.
man_seeker_file_callback()
{
    local msfc_path="$1"
    local msfc_file_callback="$2"

    shift 2
    local -a msfc_extra=( "${@}" )

    local OIFS="$IFS"
    local IFS=$'\n'
    local -a msfc_files=( "$msfc_path"/* )
    IFS="$OIFS"

    local msfc_file
    for msfc_file in "${msfc_files[@]}"; do
        if "$msfc_file_callback" "$msfc_file" "${msfc_extra[@]}"; then
            return 0
        fi
    done

    return 1
}

# Start process that results in a callback for every man file
# found.  The arguments passed to this function are passed on
# to the builtin man_seeker_man_file_callback() function.
#
# Args:
#  (name)   function name to call for each file
#  (extra)  extra arguments to be used by the $1 callback function.
man_seeker_walk_files()
{
    man_seeker_walk_paths "man_seeker_file_callback" "$@"
}

man_seeker_find_man_callback()
{
    local fmc_filepath="$1"

    local -n fmc_return="$2"
    local fmc_name_sought="$3"
    local fmc_section_sought="$4"

    local -a fmc_args=( "fmc_name" "fmc_section" "$fmc_filepath" )

    if man_seeker_path_extract_name_and_section "${fmc_args[@]}"; then
        if [ "$fmc_name" == "$fmc_name_sought" ]; then
            if ! [ "$fmc_section_sought" ] || \
                   [ "$fmc_section_sought" != "$fmc_section" ]; then
                return 1
            fi
            fmc_return="$fmc_filepath"
            return 0
        fi
    fi

    return 1
}

