# This script file does not run on its own, it must
# be "sourced" into an executable script.

man_heads_sub_IFS=$'|'

# This regex works with grep, but not for Bash:
# declare re=^\\.\\\(TH\\\|SH\\\SS\\\Dt\\\Sh\\\Ss\\\)\ *\\\(\\\.*\\\)$

# declare man_heads_headers_regex=^\\.\(TH\|Dt\|SH\|Sh\|SS\|Ss\)\ \(.*\)
declare man_heads_headers_regex='^\.(TH|Dt|SH|Sh|SS|Ss)\ (.*)'

# Saves the current section name to the lui_list named by $1,
# saving a concatenated subheads list along with the section name
#
# Args:
#   (name)   name of lui_list to which a new section element will be added
#   (string) section title name
#   (name)   name of an array of subsection names
man_heads_save_section()
{
    local -n mhss_return="$1"
    local mhss_name="$2"
    local -n mhss_subs="$3"

    local OIFS="$IFS"
    IFS='|'
    mhss_return+=( "$mhss_name" "${mhss_subs[*]}" 0 )
    IFS="$OIFS"
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
#   (name):   name of lui_list to which results are saved
#   (name):   name of variable that contains the current line
#   (name):   name of variable to save or write header title
#   (name):   name of array of accumulated subhead names
man_heads_process_header()
{
    local -n mhph_return="$1"
    local -n mhph_line="$2"
    local -n mhph_section_name="$3"
    local -n mhph_subs="$4"

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
                    man_heads_save_section "$1" "$mhph_section_name" "mhph_subs"
                    mhph_subs=()
                fi
                mhph_section_name="$mhph_value"
                ;;
            SS|Ss)
                mhph_subs+=( $"mhph_value" )
                ;;
        esac
    fi
 }

# Process the contents of a gzipped man page soure file.
#
# Args:
#   (name):   name of lui list to which sections info will be saved
#   (string): path to man file to be processed
man_heads_read_headers_gzip()
{
    local mhrh_return_name="$1"
    local mhrh_path="$2"

    local mhrh_section_title
    local -a mhrh_subs=()

    local -a mhrh_line
    while read -r "mhrh_line"; do
        man_heads_process_header "$mhrh_return_name" "mhrh_line" "mhrh_section_title" "mhrh_subs"
    done < <( gzip -dc "$mhrh_path" )

    if [ -n "$mhrh_section_name" ]; then
        man_heads_save_section "$1" "$mhrh_section_title" "mhrh_subs"
    fi
}

# Process the contents of a plain-text man page source file
#
# Args:
#   (name):   name of lui list to which sections info will be saved
#   (string): path to man file to be processed
man_heads_read_headers_plain()
{
    local mhrh_return_name="$1"
    local mhrh_path="$2"

    local mhrh_section_title
    local -a mhrh_subs=()

    local -a mhrh_line
    while read -r "mhrh_line"; do
        man_heads_process_header "$mhrh_return_name" "mhrh_line" "mhrh_section_title" "mhrh_subs"
    done < "$mhrh_path"

    if [ -n "$mhrh_section_name" ]; then
        man_heads_save_section "$1" "$mhrh_section_title" "mhrh_subs"
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
    local mhrh_file="$2"

    mhrh_list=( 3 0 )

    if [ "${mhrh_file##*.}" == "gz" ]; then
        man_heads_read_headers_gzip "mhrh_list" "$mhrh_file"
    else
        man_heads_read_headers_plain "mhrh_list" "$mhrh_file"
    fi

    lui_list_init "mhrh_list"
}
