# Interactive checkbox picker for choosing repositories on the terminal.
# Plain ANSI escapes and `read -rsn1` only (no tput; stty only to turn echo off): works on bash 3.2 and newer.
# shellcheck disable=SC2154,SC2034 # select_* inputs are set by the caller; select_chosen is read by it

# Show the cursor again and put the terminal settings back.
_select_restore() {
    printf '\033[?25h' > /dev/tty
    if [ -n "${select_saved_stty:-}" ]; then
        stty "$select_saved_stty" < /dev/tty 2> /dev/null
    fi
    return 0
}

# Show a checkbox list on /dev/tty and let the user tick items. Nothing is ticked at first.
# Keys: Up/Down or k/j move, Space toggles the current item, a toggles all available items,
# Enter confirms, q or Esc cancels. An unavailable item is drawn dimmed with its reason and
# cannot be ticked. Returns 1 (cancelled, or Enter with nothing ticked); otherwise returns 0
# and fills select_chosen with the indexes of the ticked items, in order.
#
# Input (globals, because bash 3.2 has no namerefs):
#   select_title     heading line
#   select_labels    array of item labels
#   select_reasons   array, same length: "" when the item is available, else why it is not
select_repos() {
    local count=${#select_labels[@]} i cursor=0 key key2 key3 ticked=() frame mark first_draw=true any pointer
    local esc=$'\033' lines=$((2 + ${#select_labels[@]}))
    select_chosen=()
    for ((i = 0; i < count; i++)); do
        ticked[i]=""
    done
    for ((i = count - 1; i >= 0; i--)); do
        if [ -z "${select_reasons[$i]}" ]; then cursor=$i; fi # ends on the first available row
    done

    printf '%s[?25l' "$esc" > /dev/tty # hide the cursor; always show it again on the way out
    select_saved_stty="$(stty -g < /dev/tty 2> /dev/null)" # keys typed while redrawing must not echo
    stty -echo < /dev/tty 2> /dev/null
    trap '_select_restore' EXIT
    trap '_select_restore; exit 130' INT TERM

    while true; do
        frame="$select_title"$'\n'"  Up/Down or k/j: move, Space: tick, a: all, Enter: confirm, q: cancel"$'\n'
        for ((i = 0; i < count; i++)); do
            pointer="  "
            [ "$i" -eq "$cursor" ] && pointer="> "
            if [ -n "${select_reasons[$i]}" ]; then
                frame+="${esc}[2m${pointer}[-] ${select_labels[$i]} (${select_reasons[$i]})${esc}[0m"
            else
                mark=" "
                [ -n "${ticked[$i]}" ] && mark="x"
                frame+="${pointer}[$mark] ${select_labels[$i]}"
            fi
            frame+=$'\n'
        done
        if $first_draw; then
            first_draw=false
        else
            printf '%s[%dA' "$esc" "$lines" > /dev/tty # back to the top of the list
        fi
        # clear each line before it is redrawn
        printf '%s' "$frame" | while IFS= read -r mark || [ -n "$mark" ]; do
            printf '%s[2K%s\n' "$esc" "$mark"
        done > /dev/tty

        key=""
        IFS= read -rsn1 key < /dev/tty || key="q" # end of input: cancel
        case "$key" in
        "$esc")
            key2=""
            read -rsn1 -t 1 key2 < /dev/tty || true
            if [ "$key2" = "[" ] || [ "$key2" = "O" ]; then
                key3=""
                read -rsn1 -t 1 key3 < /dev/tty || true
                case "$key3" in
                A) [ "$cursor" -gt 0 ] && cursor=$((cursor - 1)) ;;
                B) [ "$cursor" -lt $((count - 1)) ] && cursor=$((cursor + 1)) ;;
                esac
            else
                break # a lone Esc cancels
            fi
            ;;
        k) [ "$cursor" -gt 0 ] && cursor=$((cursor - 1)) ;;
        j) [ "$cursor" -lt $((count - 1)) ] && cursor=$((cursor + 1)) ;;
        " ")
            if [ -z "${select_reasons[$cursor]}" ]; then
                if [ -n "${ticked[$cursor]}" ]; then ticked[cursor]=""; else ticked[cursor]="x"; fi
            fi
            ;;
        a)
            any=""  # tick everything available, or untick all when everything available is ticked
            for ((i = 0; i < count; i++)); do
                if [ -z "${select_reasons[$i]}" ] && [ -z "${ticked[$i]}" ]; then any="x"; fi
            done
            for ((i = 0; i < count; i++)); do
                if [ -z "${select_reasons[$i]}" ]; then ticked[i]="$any"; fi
            done
            ;;
        "") # Enter
            for ((i = 0; i < count; i++)); do
                [ -n "${ticked[$i]}" ] && select_chosen+=("$i")
            done
            break
            ;;
        q) break ;;
        esac
    done

    _select_restore
    trap - EXIT INT TERM
    [ "${#select_chosen[@]}" -gt 0 ]
}
