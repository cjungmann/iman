#!/usr/bin/env bash

# shellcheck shell=bash
# This script file does not run on its own, it must
# be "sourced" into an executable script.

declare SUBHEAD_DELIM='|'
declare HOTKEY_PREFIX='#'

# Globally declare state variables:
declare -a ARR_LINES=()
declare -a ARR_DEFS=()
declare -a LIST_HEADS=( 4 0 )
declare -a LIST_SUBHEADS=( 3 0 )
declare -a ARR_HOTKEYS=()
declare OPEN_HEAD=""
declare -i OPEN_LINE=0
declare OPEN_SUBHEAD=""
declare -i OPEN_SUBLINE=0
declare INTRO_REQUEST=""
declare LINE_PROCESSOR=""

man_lines_init_state()
{
    ARR_LINES=()
    ARR_DEFS=()
    LIST_HEADS=( 4 0 )
    LIST_SUBHEADS=( 3 0 )
    ARR_HOTKEYS=()
    OPEN_HEAD=""
    OPEN_LINE=0
    OPEN_SUBHEAD=""
    OPEN_SUBLINE=0
    INTRO_REQUEST=""
    LINE_PROCESSOR="man_lines_read_file_type"
}

man_lines_clear_subheads()
{
    LIST_SUBHEADS=( 3 0 )
    OPEN_SUBHEAD=""
    OPEN_SUBLINE=0
}

man_lines_compress_subheads()
{
    local -n mlcs_compressed="$1"

    # More than 2 LIST_SUBHEADS elements indicates a populated
    # lui_list: compress the lui_list to the return argument
    if [ "${#LIST_SUBHEADS[*]}" -gt 2 ]; then
        local OIFS="$IFS"
        IFS="$SUBHEAD_DELIM"
        mlcs_compressed="${LIST_SUBHEADS[*]}"
        IFS="$OIFS"
    else
        mlcs_compressed=""
    fi
}

# Removes enclosing quotes/apostrophes, if found.
#
# Args:
#    (name):   name of string to modify, if necessary
man_lines_strip_quotes()
{
    local -n mlsq_title="$1"
    local -i len="${#mlsq_title}"
    if (( len > 2 )); then
        local firstchar="${mlsq_title:0:1}"
        if [[ \"\' =~ "$firstchar" ]]; then
            if [ "${mlsq_title: -1:1}" = "$firstchar" ]; then
                mlsq_title="${mlsq_title:1:$(( len-2 ))}"
            fi
        fi
    fi
}


# Adds a prefix character, identified by $HOTKEY_PREFIX, before the
# first acceptable character.  'Q' is the only unacceptable character
# for now.
#
# This function has side-effects: it adds to the global $ARR_HOTKEYS
# array the character before which the prefix is placed.
#
# Args:
#   (name):   name of string variable to modify
man_lines_add_hotkey_prefix()
{
    local -n mlahp_title="$1"
    local mlahp_lower="${mlahp_title,,}"
    local -i mlahp_len="${#mlahp_title}"
    local -i mlahp_ndx=0

    # Find first non-q letter:
    while (( mlahp_ndx < mlahp_len )) && [ "${mlahp_ndx:${mlahp_ndx}:1}" == "q" ]; do
        (( ++mlahp_ndx ))
    done

    # Only change title and add hotkey if we found a suitable character:
    if (( mlahp_ndx < mlahp_len )); then
        local -a mlahp_arr=(
            "${mlahp_title:0:$((mlahp_ndx))}"
            "$HOTKEY_PREFIX"
            "${mlahp_title:$((mlahp_ndx))}"
        )

        local OIFS="$IFS"
        IFS=""
        mlahp_title="${mlahp_arr[*]}"
        IFS="$OIFS"

        ARR_HOTKEYS+=( "${mlahp_lower:$(( mlahp_ndx )):1}" )
    fi
}

# Common (for both man and mdoc) function for updating global
# collecting and state variables to build up the target list
# LIST_HEADS and arrays ARR_HOTKEYS and ARR_LINES.
#
# Args:
#   (string):   Text portion of section head macro request
#   (integer):  Line index in source file for current request
man_lines_new_section()
{
    local mlns_title="$1"
    local -i mlns_line="$2"

    if [ -n "$OPEN_HEAD" ]; then
        local mlns_subheads
        man_lines_compress_subheads "mlns_subheads"
        man_lines_clear_subheads

        man_lines_strip_quotes "mlns_title"
        man_lines_add_hotkey_prefix "mlns_title"

        local -a mlns_row=(
            "$OPEN_HEAD"
            "$OPEN_LINE"
            $(( mlns_line - OPEN_LINE ))
            "$mlns_subheads"
        )

        lui_list_append_row "LIST_HEADS" "mlns_row"
    fi

    OPEN_HEAD="$mlns_title"
    OPEN_LINE="$mlns_line"
}

# Update temporary lui_list of subsections with current subsection.
#
# Args:
#   (string):   Text part of subsection request macro
#   (integer):  Line number in source file of request
man_lines_new_subsection()
{
    local mlnss_title="$1"
    local -i mlnss_number="$2"

    if [ -n "$OPEN_SUBHEAD" ]; then

        local -a mlnss_row=(
            "$mlns_title"
            "$OPEN_SUBLINE"
            $(( mlnss_line - OPEN_SUBLINE ))
        )

        lui_list_append_row "LIST_SUBHEADS" "mlnss_row"
    fi

    OPEN_SUBHEAD="$mlnss_title"
    OPEN_SUBLINE="$mlnss_line"
}

# For 'man' macro man files, called for each line read by
# man_lines_read_file_xxx after # man_lines_read_file_type() has
# determined which macro set is being used.
#
# Args:
#    (name):    name of variable containing lines' text
#    (integer): line number in source file
man_lines_read_man()
{
    local -n mlrm_line="$1"
    local -i mlrm_counter="$2"

    if [[ "$mlrm_line" =~ ^\.(SH)[[:space:]]+(.+)$ ]]; then
        man_lines_new_section "${BASH_REMATCH[2]}" "$mlrm_counter"
    elif [[ "$mlrm_line" =~ ^\.(SS)[[:space:]]+(.*)$ ]]; then
        man_lines_new_subsection "${BASH_REMATCH[2]}" "$mlrm_counter"
    fi
}

# For 'mdoc' macro man files, called for each line read by
# man_lines_read_file_xxx after # man_lines_read_file_type() has
# determined which macro set is being used.
#
# Args:
#    (name):    name of variable containing lines' text
#    (integer): line number in source file
man_lines_read_mdoc()
{
    local -n mlrm_line="$1"
    local -i mlrm_counter="$2"
    if [[ "$mlrm_line" =~ ^\.(Sh)[[:space:]]+(.*)$ ]]; then
        man_lines_new_section "${BASH_REMATCH[2]}" "$mlrm_counter"
    elif [[ "$mlrm_line" =~ ^\.(Sh)[[:space:]]+(.*)$ ]]; then
        man_lines_new_subsection "${BASH_REMATCH[2]}" "$mlrm_counter"
    fi
}

# Set global INTRO_REQUEST and LINE_PROCESSOR variables according
# to the macro-set used when either .TH or .Dt request is
# encountered.
#
# Args:
#   (name):   name of variable containing the current line
man_lines_read_file_type()
{
    local -n mlrft_line="$1"

    if [[ "$mlrft_line" =~ ^\.(TH|Dt)\  ]]; then
        local request="${BASH_REMATCH[1]}"
        if [ "$request" == "TH" ]; then
            INTRO_REQUEST="$request"
            LINE_PROCESSOR="man_lines_read_man"
        elif [ "$request" == "Dt" ]; then
            INTRO_REQUEST="$request"
            LINE_PROCESSOR="man_lines_read_mdoc"
        fi
    fi
}

man_lines_read_file_gzip()
{
    local mlrf_path="$1"
    local -i counter=0
    local mlrf_line
    while read -r "mlrf_line"; do
        ARR_LINES+=( "$mlrf_line" )
        "$LINE_PROCESSOR" "mlrf_line" "$counter"
        (( ++counter ))
    done < <( gzip -dc "$mlrf_path" )
    man_lines_new_section "" "$counter"
}

man_lines_read_file_plain()
{
    local mlrf_path="$1"
    local -i counter=0
    local mlrf_line
    while read -r "mlrf_line"; do
        ARR_LINES+=( "$mlrf_line" )
        "$LINE_PROCESSOR" "mlrf_line" "$counter"
        (( ++counter ))
    done < "$mlrf_path"
    man_lines_new_section "" "$counter"
}

# Get names of arrays and list needed to run lui_list
man_lines_get_variable_names()
{
    local -n mlgvn_lines="$1"
    local -n mlgvn_heads="$2"
    local -n mlgvn_hotkeys="$3"

    mlgvn_lines="ARR_LINES"
    mlgvn_heads="LIST_HEADS"
    mlgvn_hotkeys="ARR_HOTKEYS"
}

man_lines_read_file()
{
    local mlrf_file="$1"
    local -i mlrf_exit=1

    man_lines_init_state

    if [ "${mlrf_file##*.}" == "gz" ]; then
        man_lines_read_file_gzip "$mlrf_file"
        mlrf_exit="$?"
    else
        man_lines_read_file_plain "$mlrf_file"
        mlrf_exit="$?"
    fi

    return "$mlrf_exit"
}


###########################################
# TESTING CODE TO BE DELETED WHEN VERFIED #
###########################################

# declare APPFOLDER
# APPFOLDER=$( readlink -f "$0" )
# APPFOLDER="${APPFOLDER%/*}"
# source "$APPFOLDER"/sources/include
# source "$APPFOLDER"/man_seeker.sh
# source "$APPFOLDER"/man_heads.sh
# # source "$APPFOLDER"/man_lines.sh
# source "$APPFOLDER"/man_pager.sh
# # declare example_man="/usr/share/man/man1/bash.1"
# declare example_man="/usr/share/man/man1/printf.1.gz"
# declare example_mdoc="/usr/share/man/man7/markdown.7.gz"  # Markdown syntax manual

# man_lines_test()
# {
#     man_lines_init_state

#     read -n1 -p"Press key to start mdoc-macro man page"
#     man_lines_read_file "$example_mdoc"

#     # read -n1 -p"Press key to start man-macro man page"
#     # man_lines_read_file "$example_man"

#     local name_lines name_heads name_hotkeys
#     man_lines_get_variable_names "name_lines" "name_heads" "name_hotkeys"

#     lui_list_dump "$name_heads"
#     read -n1 -pPress\ a\ key.


# }

# man_lines_test
