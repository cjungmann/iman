# This script file does not run on its own, it must
# be "sourced" into an executable script.

man_heads_sub_IFS=$'|'

man_heads_groff_request_to_int()
{
    local -n igrti_return="$1"
    case "$2" in
        TH|Dt ) igrti_return=0 ;;
        SH|Sh ) igrti_return=1 ;;
        SS|Ss ) igrti_return=2 ;;
        * )
            igrti_return=-1
            echo "Unexpected request value '$2'"
            exit
            ;;
    esac
}

# This regex works with grep, but not for Bash:
# declare re=^\\.\\\(TH\\\|SH\\\SS\\\Dt\\\Sh\\\Ss\\\)\ *\\\(\\\.*\\\)$

# declare man_heads_headers_regex=^\\.\(TH\|Dt\|SH\|Sh\|SS\|Ss\)\ \(.*\)
declare man_heads_headers_regex='^\.(TH|Dt|SH|Sh|SS|Ss)\ (.*)'

man_heads_read_headers_gzip()
{
    local mhrhg_path="$1"

    local mhrhg_line
    while read -r "mhrhg_line"; do
        if [[ "$mhrhg_line" =~ $man_heads_headers_regex  ]]; then
           echo "${BASH_REMATCH[1]} value is ${BASH_REMATCH[2]}"
        fi
    done < <( gzip -dc "$mhrhg_path" )
    # done < <( zcat "$mhrhg_path" )
}

man_heads_read_headers_plain()
{
    local mhrhp_path="$1"

    local mhrhp_line
    while read -r "mhrhp_line"; do
        if [[ "$mhrhp_line" =~ $man_heads_headers_regex  ]]; then
           echo "${BASH_REMATCH[1]} value is ${BASH_REMATCH[2]}"
        fi
    done < "$mhrhp_path"
}

man_heads_read_headers()
{
    local mhrh_file="$1"
    if [ "${mhrh_file##*.}" == "gz" ]; then
        man_heads_read_headers_gzip "$mhrh_file"
    else
        man_heads_read_headers_plain "$mhrh_file"
    fi
}

man_heads_extract_headers()
{
    local -n mheh_headers="$1"
    local mheh_path="$2"

    local -a mheh_args

    if [ "${mheh_path##*.}" == "gz" ]; then
        mheh_args=( gzip -dc "$mheh_path" )
    else
        mheh_args=( cat "$mheh_path" )
    fi

    "${mheh_path[@]}"
}

man_heads_extract_headers_man()
{
    local -n fehm_headers="$1"
    local fehm_path="$2"
    mapfile -t "$1" < <( zgrep ^\\.\\\(TH\\\|SH\\\|SS\\\) "$fehm_path" )
    [ "${#fehm_headers[@]}" -gt 0 ]
}

man_heads_extract_headers_mdoc()
{
    local -n fehmd_headers="$1"
    local fehmd_path="$2"
    mapfile -t "$1" < <( zgrep '^\.\(Dt\|Sh\|Ss\)' "$fehmd_path" )
    [ "${#fehmd_headers[@]}" -gt 0 ]
}

declare man_heads_regex='\.([[:alpha:]]{2}) *(.*)$'

man_heads_classify_head()
{
    local -n mhc_return="$1"
    local mhc_string="$2"

    if [[ "$mhc_string" =~ $man_heads_regex ]]; then
        local -i mhc_level
        local mhc_req mhc_str

        mhc_req="${BASH_REMATCH[1]}"
        mhc_str="${BASH_REMATCH[2]}"
        case "$mhc_req" in
            "TH"|"Dt" ) mhc_level=0 ;;
            "SH"|"Sh" ) mhc_level=1 ;;
            "SS"|"Ss" ) mhc_level=2 ;;
            * )
                echo "Unexpected request"
                exit 1
                ;;
        esac

        # Special TH handling: only use first argument
        if [ "mhc_req" == "TH" ]; then
            local -a mhc_th_arr=( $mhc_str )
            mhc_str="${mhc_th_arr[0]}"
        fi

        mhc_return=( "$mhc_level" "$mhc_str" )
        return 0
    fi

    return 1
}

man_heads_listify()
{
    local -n mhl_return="$1"
    local -n mhl_heads="$2"

    local OIFS="$IFS"

    local -a mhl_section
    local -a mhl_subheads

    local mhl_head
    local -a mhl_entry
    local -i mhl_entry_count=0

    # "Closure" function for code needed twice in function
    mhl_save_section()
    {
        if [ "${#mhl_section[@]}" -gt 0 ]; then
            if [ "${#mhl_subheads[@]}" -gt 0 ]; then
                IFS="$man_heads_sub_IFS"
                mhl_section+=( "${mhl_subheads[*]}" 0 )
                IFS="$OIFS"
            else
                mhl_section+=( "" 0 )
            fi

            mhl_return+=( "${mhl_section[@]}" )
            (( ++mhl_entry_count ))

            mhl_section=()
            mhl_subheads=()
        fi
    }

    mhl_return=( 3 0 )

    for mhl_head in "${mhl_heads[@]}"; do
        if man_heads_classify_head "mhl_entry" "$mhl_head"; then
            case "${mhl_entry[0]}" in
                0 ) ;;
                1 ) mhl_save_section
                    mhl_section=( "${mhl_entry[1]}" )
                    ;;
                2 ) mhl_subheads+=( "${mhl_entry[1]}" )
                   ;;
            esac
        else
            echo "classification failed."
        fi
    done

    # Process unfinished section
    mhl_save_section

    # Update rows count
    mhl_return[1]="$mhl_entry_count"
}

man_heads_read()
{
    local -n mhr_return="$1"
    local mhr_path="$2"

    local -a mhr_heads

    if man_heads_extract_headers_man "mhr_heads" "$mhr_path" || \
            man_heads_extract_headers_mdoc "mhr_heads" "$mhr_path"; then
        man_heads_listify "mhr_return" "mhr_heads"
        return 0
    fi

    return 1
}

