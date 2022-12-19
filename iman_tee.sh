# shellcheck shell=bash
# This script file does not run on its own, it must
# be "sourced" into an executable script.

# This file used to be many free-standing variables and functions.
# They have been enclosed in a wrapper function to provide a scope for
# otherwise global variables.

# Returns a lui_list of section information and an array of rendered
# man page lines, given the path to a man page.
#
# The fields of the section lui_list are:
#   (string):   section title
#   (integer):  section level
#   (integer):  starting line index
#   (integer):  line count
#
# Args:
#    (name):   name of lui_list for section information
#    (name):   name of array to fill with rendered man page lines
#    (string): path to the man page file
iman_read_file()
{
    local -n irf_list_sections="$1"
    local -n irf_lines="$2"
    local irf_path="$3"

    # Clear output arrays:
    irf_lines=()
    irf_list_sections=( 4 0 )

    is_gzip_file() { [ "${1##*.}" == "gz" ]; }

    local -i MT_LINE_COUNT=0

    local MT_LIH_REGEX=^\([[:space:]]*\)\(\(.\)\\2\(.\)\)+$
    local MT_HEADS_REGEX='^\.(TH|Dt|SH|Sh|SS|Ss)\ (.*)'
    local MT_HEADS_DELIM=$'\x1F'

    # Clean up text following a (sub)section request, removing
    # unnecessary quotes, etc.
    #
    # Args
    #    (name):   variable to which result is written
    #    (string): text following section request request
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
    mt_parse_heads()
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

    # Read the contents of the file created by the mt_parse_heads() function.
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
    mt_read_heads()
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

    # Save submitted line to the rendered lines array
    # Arg
    #   (string):   contents of rendered line
    mt_save_line()
    {
        local sl_line="$1"
        irf_lines+=( "$sl_line" )
        (( ++MT_LINE_COUNT ))
    }

    # Generate a less-recognized bold text string.
    #
    # Args:
    #   (name):   variable for the result
    #   (string): string to embolden
    mt_embolden_text()
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
                    mt_embolden_text "ms_header_query" "$ms_header"
                    if [ "$ms_header_level" -eq 3 ]; then
                        ms_header_query="[[:space:]]+$ms_header_query"
                    fi

                    for (( line_ndx; line_ndx<ms_line_count; ++line_ndx )); do
                        ms_man_line="${ms_man_lines[@]:$line_ndx:1}"
                        if [[ "$ms_man_line" =~ $ms_header_query ]]; then
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
    mt_enumerate_sections()
    {
        local -n es_sections="$1"
        local -n es_headers="$2"
        local -n es_man_lines="$3"

        local -i es_headers_count="${#es_headers[@]}"
        local -i es_headers_ndx=0

        local es_title
        local -i es_level=0
        local -i es_old_ndx=0
        local -i es_old_level=0
        local es_old_title

        # "lambda" function to use local closure variables to retrieve
        # title, level for each "row" in the headers file, and to retrieve
        # a regex for finding the (sub)section line.
        es_id_next_section()
        {
            local -n ins_title="$1"
            local -n ins_level="$2"
            local -n ins_query="$3"

            if (( es_headers_ndx+1 < es_headers_count )); then
                ins_level="${es_headers[$(( es_headers_ndx++ ))]}"
                ins_title="${es_headers[$(( es_headers_ndx++ ))]}"

                mt_embolden_text "ins_query" "$ins_title"
                if [ "$ins_level" -eq 3 ]; then
                    ins_query="^[[:space:]]+$ins_query$"
                else
                    ins_query="^$ins_query$"
                fi
                return 0
            fi

            return 1
        }

        # Using closure variables, create a new row in the sections lui_list
        es_save_section()
        {
            local -i ess_count
            (( ess_count = es_ndx - es_old_ndx - 1 ))
            es_sections+=( "$es_old_title" "$es_old_level" "$es_old_ndx" "$ess_count" )
        }

        local -i es_ndx=0
        local es_line

        for el_line in "${es_man_lines[@]}"; do
            if [ -z "$es_query" ]; then
                if ! es_id_next_section "es_title" "es_level" "es_query"; then
                    es_ndx="${#es_man_lines[*]}"
                    break
                fi
            fi
            if [[ "$el_line" =~ $es_query ]]; then
                if [ "$es_old_ndx" -ne 0 ]; then
                    es_save_section
                fi
                es_old_title="$es_title"
                es_old_level="$es_level"
                es_old_ndx="$es_ndx"
                # clear to trigger seeking next section name
                es_query=
            fi
            (( ++es_ndx ))
        done

        es_save_section

        lui_list_init "es_sections"

    }  # end of mt_enumerate_sections


    mt_process_source()
    {
        local OIFS="$IFS"
        local IFS=''

        local headers_file=$( mktemp /tmp/iman.XXXXXX )

        local pl_line
        while read -r "pl_line"; do
            mt_save_line "$pl_line"
        done < <( tee >( mt_parse_heads "$headers_file" ) | groff -t -man -Tutf8 - )

        # Read the file create by the mt_parse_heads() process
        local -a array_heads
        mt_read_heads "array_heads" "$headers_file"
        rm "$headers_file"

        # measure_sections "irf_list_sections" "array_heads" "irf_lines"
        mt_enumerate_sections "irf_list_sections" "array_heads" "irf_lines"
    }

    # Given a path to a man document, branches to appropriate
    # decoding function according to the extension of the file.
    #
    # Args:
    #    (string):   path to man document file
    mt_read_file()
    {
        local rf_path="$1"
        local rf_line
        if is_gzip_file "$rf_path"; then
            mt_process_source < <( gzip -dc "$rf_path" )
        else
            mt_process_source < "$rf_path"
        fi
    }

    mt_read_file "$irf_path"
}

# For stand-alone use.  Delete when done debugging:
# source sources/include

# if [ "$#" -lt 1 ]; then
#     echo "USAGE:"
#     echo "sh man_tee.sh /usr/share/man/man1/printf.1.gz"
#     echo "sh man_tee.sh /usr/share/man/man1/bash.1"
# else

#     declare -a mt_sections
#     declare -a mt_lines
#     iman_read_file "mt_sections" "mt_lines" "$1"

#     IFS=$'\n'
#     less <<< "${mt_sections[*]}"
#     less <<< "${mt_lines[*]}"
#     IFS="$OIFS"
# fi


