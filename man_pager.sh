# This script file does not run on its own, it must
# be "sourced" into an executable script.

get_screen_dims()
{
    local -i high wide
    get_screen_size "high" "wide"
    echo "The screen is $high high and $wide wide."
}

# Display lines for man_pager
#
# Args:
#   (integer):  1 if target, 0 if not
#   (integer):  minimum width of line
#   (various:   remaining arguments are field values
mp_line_display()
{
    local -i mld_target="$1"
    local -i mld_width="$2"
    local  mld_title="$3"

    local mld_color=$'\e[m'

    if [ "$mld_target" -eq 1 ]; then
        mld_color=$'\e[44m'
    fi

    local mld_line
    hilite_prefixed_char "mld_line" "$mld_title" "" "$mld_color" "#"

    force_length "$mld_line" "$mld_width"
    echo
}

mp_line_expand()
{
    local mle_keyp="$1"
    local mle_list_name="$2"
    local -i mle_index="$3"
    # Extras:
    local mle_command="$4"
    local mle_section="$5"

    local -a mle_row
    if lui_list_copy_row "mle_row" "$mle_list_name" "$mle_index"; then
        echo "row contains: '${mle_row[*]}'"
    fi

    return 0
}

mp_topic_open()
{
    local -i mto_index="$1"
    local mto_list_name="$2"
    local mto_command="$3"
    local mto_section="$4"

    local -a mto_row=()
    if lui_list_copy_row "mto_row" "$mto_list_name" "$mto_index"; then
        local qrey='^'"${mto_row[1]}"
        man -P "less -p'${qrey}'" "$mlj_section" "$mlj_command"
    else
        echo "Failed to copy row index $mto_index in $mto_list_name."
        read -n1 -p Press\ a\ key
    fi
}

mp_line_jump()
{
    local mlj_keyp="$1"
    local mlj_list_name="$2"
    local -i mlj_index="$3"
    # Extras:
    local mlj_command="$4"
    local mlj_section="$5"

    mp_topic_open "$mlj_index" "$mlj_list_name" "$mlj_command" "$mlj_section"

    # local -a mlj_row
    # if lui_list_copy_row "mlj_row" "$mlj_list_name" "$mlj_index"; then
    #     local qrey='^'"${mlj_row[0]}"
    #     man -P "less -p'${qrey}'" "$mlj_section" "$mlj_command"
    # else
    #     echo "failed to copy row with $mlj_list_name and $mlj_index"
    # read -n1 -p Punch\ it
    # fi

    return 0
}

declare -a mp_keys_array=(
    $'\e|q:LUI_ABORT:Leave Context'
    $'\n:mp_line_jump:Goto topic'
    $'+:mp_line_expand:Open Subheadings'
)

mp_start_pager()
{
    local -n msp_return="$1"
    local -n msp_source="$2"
    local msp_command="$3"
    local msp_section="$4"

    msp_open_topic()
    {
        local keyp="$1"
        # ignore other arguments, which are available in the "closure"

        if progressive_letter_search "msp_return" "$msp_keys_string" "$keyp"; then
            mp_topic_open "$msp_return" "msp_source" "$msp_command" "$msp_section"
        fi

        return 0
    }

    local msp_keys_array=( "${mp_keys_array[@]}" )

    if [ "$#" -gt 4 ]; then
        local -n msp_hotkeys="$5"
        local msp_packed_keys
        local msp_keys_string
        concat_array "msp_packed_keys" "msp_hotkeys" "|"
        concat_array "msp_keys_string" "msp_hotkeys"
        msp_keys_array+=( "$msp_packed_keys":msp_open_topic:"View Topic" )
    fi

    local -a msp_paras=(
        "$msp_command($msp_section)"
        )

    local -a msp_args=(
        "msp_return"
        "msp_source"
        0 0 20 80
        "mp_line_display"
        "mp_keys_array"
        "msp_paras"

        # extra parameters
        "$msp_command"
        "$msp_section"
        )

    lui_list_generic "${msp_args[@]}"
}
