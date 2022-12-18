#!/usr/bin/env bash

# shellcheck shell=bash
# This script file does not run on its own, it must
# be "sourced" into an executable script.

is_gzip_file() { [ "${1##*.}" == "gz" ]; }

declare -i MT_LINE_COUNT=0
declare -a MT_LINES=()

# the fields are:
#   (string):   section title
#   (integer):  section level
#   (integer):  starting line index
#   (integer):  line count
declare -a MT_HEADLIST=( 4 0 )

declare MT_LIH_REGEX=^\([[:space:]]*\)\(\(.\)\\2\(.\)\)+$
declare MT_HEADS_REGEX='^\.(TH|Dt|SH|Sh|SS|Ss)\ (.*)'
declare MT_HEADS_DELIM=$'\x1F'

mt_clean_text()
{
    local -n mct_return="$1"
    local -a mct_arr=()
    IFS=$'\n' mct_arr=( $(xargs -n1 <<< "$2") )
    IFS=' ' mct_return="${mct_arr[*]}"
}

# Reads lines of a groff document using man or mdoc macros
# to detect header requests, which are saved to a file.
#
# Args
#    (string)  path to file to which the headers will be written
parse_heads()
{
    local ph_file="$1"

    local value
    local -i level
    local ph_reply
    while IFS= read -r "ph_reply"; do
        if [[ "$ph_reply" =~ $MT_HEADS_REGEX ]]; then
            mt_clean_text "value" "${BASH_REMATCH[2]}"

            case "${BASH_REMATCH[1]}" in
                SH|Sh) level=2 ;;
                SS|Ss) level=3 ;;
                TH|Dt) level=1 ;;
                *) level=0 ;;
            esac

            # ignore document header
            if [ "$level" -gt 1 ]; then
                echo "$level${MT_HEADS_DELIM}${value}" >> "$ph_file"
            fi
        fi
    done
}

# Read the contents of the file created by the parse_heads() function.
# It will write to a lui_list with empty fields that will later be
# filled with line positions of the header in the man page output.
#
# The array will be a two-dimensional array, with odd-number elements
# being the section's level and the even-number elements being the
# section's name.
#
# Args:
#    (name):   name of array of section level/section name elements
#    (string): path to headers file.
read_heads()
{
    local rh_array_name="$1"
    local -n rh_array="$rh_array_name"
    local rh_path="$2"

    rh_array=()

    local OIFS="$IFS"
    local IFS="$MT_HEADS_DELIM"

    local rh_reply
    while read -r "rh_reply"; do
        rh_array+=( $rh_reply )
    done < "$rh_path"

    IFS="$OIFS"
}

line_is_header()
{
    if [[ "$1" =~ $MT_LIH_REGEX ]]; then
        echo "'$1' determined to be a head, with '${BASH_REMATCH[2]}' and '${BASH_REMATCH[3]}'"
        return 0
    fi
    return 1
}

extract_header()
{
    local -n eh_head="$1"
    local eh_line="$2"

    if [[ "$2" =~ ^[[:space:]]+(.*) ]]; then
        eh_head="${BASH_REMATCH[1]}"
    fi
}

save_line()
{
    local sl_line="$1"
    MT_LINES+=( "$sl_line" )
    (( ++MT_LINE_COUNT ))
}

process_rendered_line()
{
    if line_is_header "$1"; then
        local prl_line
        extract_header "prl_line" "$1"gg41
        local -a prl_row=( "$prl_line" 0 0 0)
    fi

    save_line "$1"
}

# For stand-alone use.  Delete when done debugging:
source sources/small_stuff.sh

# Generate a less-recognized bold text string.
#
# Args:
#   (name):   variable for the result
#   (string): string to embolden
embolden_text()
{
    local bs=$'\b'
    local -n et_return="$1"
    local -a et_letters=()
    local et_reply
    while IFS= read -r -n1 "et_reply"; do
        if [ "$et_reply" == ' ' ]; then
            et_letters+=( " " )
        elif [ -n "$et_reply" ]; then
            et_letters+=( "$et_reply" "$bs" "$et_reply" )
        fi
    done <<< "$2"

    IFS= et_return="${et_letters[*]}"
}

# Walk through the headers list and the lines array to
# record the lines of the lines array that represent each
# section header identified in the headers list.  The results
# will be written to the lui_list named in $1.
#
# Args:
#   (name):   name of lui_list of section headers
#   (name):   array name of headers information
#   (name):   name of array of lines of rendered man page text
measure_sections()
{
    local -n ms_sections="$1"
    local -n ms_headers="$2"
    local -n ms_man_lines="$3"

    local -i ms_header_count="${#ms_headers[*]}"
    local -i ms_line_count="${#ms_man_lines[*]}"

    local -i section_start section_end
    local -i subsec_start subsec_end

    local -i line_ndx=0
    local -i ndx
    local -i ms_header_level=0
    local ms_header
    local ms_header_query
    local ms_man_line
    for ms_header in "${ms_headers[@]}"; do
        # alternate reading integer level and string line values
        if [ "$ms_header_level" -ne 0 ]; then

            # Ignore level==1 (TH/Dt requests)
            if [ "$ms_header_level" -gt 1 ]; then

                # build query
                embolden_text "ms_header_query" "$ms_header"
                if [ "$ms_header_level" -eq 3 ]; then
                    ms_header_query="[[:space:]]+$ms_header_query"
                fi
                echo "Level $ms_header_level: using query '$ms_header_query'"

                for (( line_ndx; line_ndx<ms_line_count; ++line_ndx )); do
                    ms_man_line="${ms_man_lines[@]:$line_ndx:1}"
                    if [[ "$ms_man_line" =~ $ms_header_query ]]; then
                        echo "Found head '$ms_header' at line $line_ndx"
                        break
                    fi
                done
            fi
            # reset so next element is interpreted as an integer level value
            ms_header_level=0
        else
            ms_header_level="$ms_header"
        fi
    done
}

# Build lui_list of section names and included lines using records
# from a list of headers and the rendered man page content.
#
# Args:
#    (name):   name of lui_list with section titles and line numbers
#    (name):   name of array of the levels and titles of the sections
#    (name):   name of an array of rendered man page lines
enumerate_sections()
{
    local -n es_sections="$1"
    local -n es_headers="$2"
    local -n es_man_lines="$3"

    local -i es_ndx=0
    local -i es_old_ndx=0
    local es_line

    update_

    id_next_section()
    {
        local -n ins_query="$1"
        local -i ins_level="${es_sections[$(( es_sections++ ))]}"
        local ins_title="${es_sections[$(( es_sections++ ))]}"

        embolden_text "ins_query" "$ins_title"
        if [ "$ins_level" -eq 3 ]; then
            ins_query="^[[:space:]]+$ins_query$"
        else
            ins_query="^$ins_query$"
        fi
    }


    for el_line in "${es_man_lines[@]}"; do
        if [ -z "$es_query" ]; then
            id_next_section "es_query"
        fi
        if [[ "$el_line" =~ $es_query ]]; then
            if
        
    done

}


process_source()
{
    local OIFS="$IFS"
    local IFS=''

    local headers_file=$( mktemp /tmp/iman.XXXXXX )

    local pl_line
    while read -r "pl_line"; do
        process_rendered_line "$pl_line"
    done < <( tee >( parse_heads "$headers_file" ) | groff -t -man -Tutf8 - )

    local -a array_heads
    read_heads "array_heads" "$headers_file"
    rm "$headers_file"

    local -a ll_sections
    measure_sections "ll_sections" "array_heads" "MT_LINES"

    read -n1 -p Pause\ before\ displays

    # Showing complete man page:
    # local -i pl_count=0
    # echo > man_tee.txt
    # for pl_line in "${MT_LINES[@]}"; do
    #     echo "$pl_line" >> man_tee.txt
    # done

    IFS=$'\n'
    less <<< "${MT_LINES[*]}"

    less <<< "${array_heads[*]}"

    IFS="$OIFS"
}

# Given a path to a man document, branches to appropriate
# decoding function according to the extension of the file.
#
# Args:
#    (string):   path to man document file
read_file()
{
    local rf_path="$1"
    local rf_line
    if is_gzip_file "$rf_path"; then
        process_source < <( gzip -dc "$rf_path" )
    else
        process_source < "$rf_path"
    fi

    local target="${rf_path##*/}.txt"
    local OIFS="$IFS"
    local IFS=$'\n'
    echo "${MT_LINES[*]}" > "$target"
}

if [ "$#" -lt 1 ]; then
    echo "USAGE:"
    echo "sh man_tee.sh /usr/share/man/man1/printf.1.gz"
    echo "sh man_tee.sh /usr/share/man/man1/bash.1"
    test_embolden amazon bogus man
else
    read_file "$1"
fi



