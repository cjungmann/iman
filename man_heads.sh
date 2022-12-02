# shellcheck shell=bash
# This script file does not run on its own, it must
# be "sourced" into an executable script.


man_heads_sub_IFS=$'|'
man_heads_hotkey_prefix=$'#'

# This regex works with grep, but not for Bash:
# declare re=^\\.\\\(TH\\\|SH\\\SS\\\Dt\\\Sh\\\Ss\\\)\ *\\\(\\\.*\\\)$

# declare man_heads_headers_regex=^\\.\(TH\|Dt\|SH\|Sh\|SS\|Ss\)\ \(.*\)
declare man_heads_headers_regex='^\.(TH|Dt|SH|Sh|SS|Ss)\ (.*)'

# Set hilited character to first non-q letter in title
# 
# Args:
#   (name)   name of string variable to which result is saved
#   (name)   name of simple array of hotkey characters
#   (string) section title
man_heads_set_hilite_letter()
{
    local -n mhshl_return="$1"
    local -n mhshl_hotkeys="$2"
    local mhshl_title="$3"

    local -i mhshl_len="${#mhshl_title}"
    local -i mhshl_index=0
    local mhshl_lower="${mhshl_title,,}"
    local mhshl_hotkey

    # use first non-q letter
    while (( mhshl_index < mhshl_len)) && [ "${mhshl_lower:${mhshl_index}:1}" == "q" ]; do
        (( ++mhshl_index ))
    done

    if (( mhshl_index < mhshl_len )); then
        mhshl_hotkeys+=( "${mhshl_lower:$mhshl_index:1}" )
        local -a mhshl_array=(
            "${mhshl_title:0:$mhshl_index}"
            "${man_heads_hotkey_prefix}"
            "${mhshl_title:${mhshl_index}}"
        )
        concat_array "mhshl_return" "mhshl_array"
    else
        # No appropriate letter, no highlight:
        mhshl_return="$mhshl_title"
    fi
}

# Saves the current section name to the lui_list named by $1,
# saving a concatenated subheads list along with the section name
#
# Args:
#   (name)    name of lui_list to which a new section element will be added
#   (name)    name of array of hotkey characters
#   (string)  section title name
#   (name)    name of an array of subsection names
#   (integer) line number of previous section head
#   (integer) line-index of current line in source file
man_heads_save_section()
{
    local -n mhss_return_list="$1"
    local mhss_hotkeys_name="$2"
    local mhss_name="$3"
    local -n mhss_subs="$4"
    local -i mhss_section_line="$5"
    local -i mhss_counter="$6"

    local mhss_label
    man_heads_set_hilite_letter "mhss_label" "$mhss_hotkeys_name" "$mhss_name"

    local mhss_sub_names
    concat_array "mhss_sub_names" "mhss_subs" "|"
    local -a mhss_row=( "$mhss_label" "$mhss_sub_names" "$mhss_section_line" $(( mhss_counter-1 )) )
    lui_list_append_row "mhss_return_list" "mhss_row"
}

# Processes a raw line of file input, saving header values found in
# the raw groff text.
#
# This function uses variable references so the saved values will
# persist between calls, especially for accumulating subheads that
# will be combined into a single string value for a section header
# lui_list row.
#
# Args:
#   (name):    name of lui_list to which results are saved
#   (name):    name of array of hotkeys
#   (name):    name of variable that contains the current line
#   (name):    name of variable to save or write header title
#   (name):    name of array of accumulated subhead names
#   (name):    name of integer preserving last section line number
#   (integer): line-index of current line in source file
man_heads_process_header()
{
    local -n mhph_return="$1"
    local -n mhph_hotkeys="$2"
    local -n mhph_line="$3"
    local -n mhph_section_name="$4"
    local -n mhph_subs="$5"
    local -n mhph_section_line="$6"
    local -i mhph_counter="$7"

    local mhph_value

    if [[ "$mhph_line" =~ $man_heads_headers_regex  ]]; then
        mhph_value="${BASH_REMATCH[2]}"
        if [ "${mhph_value:0:1}" == '"' ] && \
               [ "${mhph_value: -1:1}" == '"' ]; then
            mhph_value="${mhph_value:1}"
            mhph_value="${mhph_value%\"}"
        fi
        case "${BASH_REMATCH[1]}" in
            TH|Dt) ;;
            SH|Sh)
                if [ -n "$mhph_section_name" ]; then
                    man_heads_save_section "$1" "$2" \
                                           "$mhph_section_name" \
                                           "mhph_subs" \
                                           "$mhph_section_line"\
                                           "$mhph_counter"
                    mhph_subs=()
                fi
                mhph_section_name="$mhph_value"
                mhph_section_line="$mhph_counter"
                ;;
            SS|Ss)
                mhph_subs+=( "$mhph_value" )
                ;;
        esac
    fi
 }

# Process the contents of a gzipped man page soure file.
#
# Args:
#   (name):   name of lui list to which sections info will be saved
#   (name):   name of array of hotkeys
#   (name):   name of array of plain source lines
#   (string): path to man file to be processed
man_heads_read_headers_gzip()
{
    local mhrh_return_name="$1"
    local mhrh_hotkeys_name="$2"
    local -n mhrh_lines_array="$3"
    local mhrh_path="$4"

    local mhrh_section_title
    local -a mhrh_subs=()

    local -i mhrh_section_line=0
    local -i mhrh_counter=0
    local -a mhrh_line
    while read -r "mhrh_line"; do
        man_heads_process_header "$mhrh_return_name" \
                                 "$mhrh_hotkeys_name" \
                                 "mhrh_line" \
                                 "mhrh_section_title" \
                                 "mhrh_subs" \
                                 "mhrh_section_line" \
                                 "$mhrh_counter"

        mhrh_lines_array+=( "$mhrh_line" )
        (( ++mhrh_counter ))
    done < <( gzip -dc "$mhrh_path" )

    if [ -n "$mhrh_section_title" ]; then
        man_heads_save_section "$1" "$2" \
                               "$mhrh_section_title" \
                               "mhrh_subs" \
                               "$mhrh_section_line" \
                               "$mhrh_counter"
    fi
}

# Process the contents of a plain-text man page source file
#
# Args:
#   (name):   name of lui list to which sections info will be saved
#   (name):   name of array of hotkeys
#   (name):   name of array of plain source lines
#   (string): path to man file to be processed
man_heads_read_headers_plain()
{
    local mhrh_return_name="$1"
    local mhrh_hotkeys_name="$2"
    local -n mhrh_lines_array="$3"
    local mhrh_path="$4"

    local mhrh_section_title
    local -a mhrh_subs=()

    local -i mhrh_section_line=0
    local -i mhrh_counter=0
    local -a mhrh_line
    while read -r "mhrh_line"; do
        man_heads_process_header "$mhrh_return_name" \
                                 "$mhrh_hotkeys_name" \
                                 "mhrh_line" \
                                 "mhrh_section_title" \
                                 "mhrh_subs" \
                                 "mhrh_section_line" \
                                 "$mhrh_counter"
        mhrh_lines_array+=( "$mhrh_line" )
        (( ++mhrh_counter ))
    done < "$mhrh_path"

    if [ -n "$mhrh_section_title" ]; then
        man_heads_save_section "$1" "$2" \
                               "$mhrh_section_title" \
                               "mhrh_subs" \
                               "$mhrh_section_line" \
                               "$mhrh_counter"
    fi
}

# Calls appropriate head_headers function according to the file type.
#
# Args:
#   (name):   name of array in which to return the lui_list of sections
#   (string): path to man page source text to process
man_heads_read_headers()
{
    local -n mhrh_list="$1"
    local -n mhrh_hotkeys="$2"
    local mhrh_lines_array_name="$3"
    local mhrh_file="$4"

    mhrh_list=( 4 0 )
    mhrh_hotkeys=()

    if [ "${mhrh_file##*.}" == "gz" ]; then
        man_heads_read_headers_gzip "mhrh_list" "mhrh_hotkeys" "$mhrh_lines_array_name" "$mhrh_file"
    else
        man_heads_read_headers_plain "mhrh_list" "mhrh_hotkeys" "$mhrh_lines_array_name" "$mhrh_file"
    fi

    lui_list_init "mhrh_list"
}
