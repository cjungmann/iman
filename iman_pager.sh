# shellcheck shell=bash
# This script file does not run on its own, it must
# be "sourced" into an executable script.

get_screen_dims()
{
    local -i high wide
    get_screen_size "high" "wide"
}

iman_start_ui()
{
    local isu_page="$1"
    local isu_section="$2"
    local isu_sections_name="$3"
    local isu_lines_name="$4"

    local -n isu_sections="$isu_sections_name"
    local -n isu_lines="$isu_lines_name"

    isu_action_show_section()
    {
        local keyp="$1"
        local list_name="$2"
        local -i row_ndx="$3"
        local -a extra=( "${@:3}" )

        local -a row
        if lui_list_copy_row "row" "$list_name" "$row_ndx"; then
            local OIFS="$IFS"
            local IFS=$'\n'
            local -i start="${row[2]}"
            local -i count="${row[3]}"
            less -c <<< "${isu_lines[@]:${start}:${count}}"
            IFS="$OIFS"

            return 0
        fi

        return 1
    }

    declare -a isu_key_list=(
        $'\e|q:LUI_ABORT:Leave context'
        $'\n:isu_action_show_section:Show section'
        )

    isu_display_line()
    {
        local -i marked="$1"
        local -i width="$2"

        local sec_name="$3"
        local sec_level="$4"

        if [ "$marked" -eq 1 ]; then
            echo -n $'\e[44m'
        fi

        # Indent subsections
        if [ "$sec_level" -eq 3 ]; then
            sec_name="   $sec_name"
        fi

        force_length "$sec_name" "$width"

        echo $'\e[m'
    }

    local -a paras_array
    local -a lines_array

    bind_paragraphs "paras_array" <<EOF
Man page topics for ${isu_page}(${isu_section})

Select one of the following topics to read about it.
EOF

    format_paragraphs "lines_array" "paras_array" 60

    local -a lui_list_args=(
        ""
        "$isu_sections_name"
        0 0 50 60
        "isu_display_line"
        "isu_key_list"
        "lines_array"
        )

    lui_list_generic "${lui_list_args[@]}"
}
