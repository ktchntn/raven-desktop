# RAVEN prompt for bash. Loaded by one line at the end of ~/.bashrc
# (remove that line to get Kali's prompt back; the original is in ~/.bashrc.kali-backup).
#
#   ┌─(user@host)─[~/path]─[tun0 192.168.45.181]     <- VPN part only while a tunnel is up
#   └─$                                               <- └─[1]$ in lime after a failed command

__raven_vpn() {
    ip -4 -o addr show 2>/dev/null |
        awk '$2 ~ /^(tun|tap|wg|ppp|ipsec|vpn|tailscale|nordlynx|proton)/ { split($4, a, "/"); print $2 " " a[1]; exit }'
}

__raven_prompt() {
    local status=$?
    local frame='\[\e[38;2;94;94;94m\]' dim='\[\e[38;2;122;122;122m\]' ink='\[\e[38;2;242;242;242m\]'
    local path='\[\e[1;38;2;242;242;242m\]' lime='\[\e[38;2;198;255;0m\]' reset='\[\e[0m\]'

    local who="${dim}\u@\h" sym='$'
    if [ "$EUID" -eq 0 ]; then
        who="${lime}\u@\h"
        sym='#'
    fi

    local env=""
    [ -n "$VIRTUAL_ENV" ] && env="${frame}(${dim}${VIRTUAL_ENV##*/}${frame})─"

    local vpn seg=""
    vpn=$(__raven_vpn)
    [ -n "$vpn" ] && seg="${frame}─[${lime}${vpn}${frame}]"

    local mark="${frame}└─${ink}${sym}"
    [ "$status" -ne 0 ] && mark="${frame}└─${lime}[${status}]${sym}"

    # A blank line before every prompt but the first, as Kali does.
    local gap=""
    [ -n "$__raven_started" ] && gap="\n"
    __raven_started=1

    PS1="\[\e]0;\u@\h: \w\a\]${gap}${frame}┌─${env}(${who}${frame})─[${path}\w${frame}]${seg}\n${mark}${reset} "
    return "$status"
}

VIRTUAL_ENV_DISABLE_PROMPT=1
PROMPT_COMMAND=__raven_prompt

# Warp's native prompt (honor_ps1 = false) can't run custom commands, but its
# Conda chip shows $CONDA_DEFAULT_ENV, re-read before every prompt. Conda isn't
# installed here, so the VPN goes in that variable. Prepended to precmd_functions
# so it runs before Warp's own hook reads the value.
if [ "$TERM_PROGRAM" = WarpTerminal ]; then
    __raven_vpn_chip() {
        local status=$? vpn
        vpn=$(__raven_vpn)
        if [ -n "$vpn" ]; then CONDA_DEFAULT_ENV="$vpn"; else unset CONDA_DEFAULT_ENV; fi
        return "$status"
    }
    precmd_functions=(__raven_vpn_chip "${precmd_functions[@]}")
fi

# The RAVEN session header, once per new terminal (not for shells started inside it).
# The stock Debian/Kali login text is silenced by ~/.hushlogin.
if [ -z "$RAVEN_HEADER_SHOWN" ] && [ -x ~/.local/bin/raven-header ]; then
    ~/.local/bin/raven-header
fi
export RAVEN_HEADER_SHOWN=1

# RAVEN rec (bin/raven-rec): record terminals into ~/engagements/<name>/logs.
# `rec stop` has to end this shell, so it lives here; everything else is raven-rec.
rec() {
    if [ "${1:-}" = stop ] && [ -z "${2:-}" ]; then
        if [ -n "$RAVEN_REC" ]; then
            # Tell the recorder it was stopped (not closed): an auto-recorded tab then stays open.
            [ -n "$RAVEN_REC_PID" ] && : > "${XDG_RUNTIME_DIR:-/tmp}/raven-rec/$RAVEN_REC_PID.stop"
            exit
        fi
        echo "rec: this terminal isn't being recorded" >&2
        local others; others=$(~/.local/bin/raven-rec status | grep '●')
        [ -n "$others" ] && printf '%s\n%s\n' \
            "recording in other tabs (rec stop PID, quick settings > Log, or switch off for auto ones):" \
            "$others" >&2
        return 1
    fi
    ~/.local/bin/raven-rec "$@"
}

# The Log switch (quick settings, `rec on`): new terminals start recorded. Only interactive
# Warp/kitty shells that aren't recorded already; it waits for the first prompt so Warp has
# finished setting the tab up, then replaces this shell (exit then closes the tab).
if [[ $- == *i* ]] && [ -z "$RAVEN_REC" ] && [ -z "$RAVEN_REC_OFF" ] && [ -e ~/.local/state/raven/rec-auto ] && [ -x ~/.local/bin/raven-rec ] &&
    { [ "$TERM_PROGRAM" = WarpTerminal ] || [ -n "$KITTY_WINDOW_ID" ]; }; then
    __raven_rec_auto() {
        unset -f __raven_rec_auto
        precmd_functions=("${precmd_functions[@]/__raven_rec_auto}")
        PROMPT_COMMAND=${PROMPT_COMMAND/__raven_rec_auto; /}
        exec ~/.local/bin/raven-rec start --auto
    }
    if [ "$TERM_PROGRAM" = WarpTerminal ]; then
        precmd_functions+=(__raven_rec_auto)
    else
        PROMPT_COMMAND="__raven_rec_auto; ${PROMPT_COMMAND}"
    fi
fi

# RAVEN done alerts (bin/raven-done): a command that ran 30 s or more sends a notification when
# it ends (skipped for interactive things and Ctrl-C), with a button that focuses this terminal.
# Warp: bash-preexec's hooks (Warp keeps ours). Others: PS0 notes the start time.
if [[ $- == *i* ]] && [ -x ~/.local/bin/raven-done ]; then
    __raven_done_t0=
    __raven_done_cmd=
    __raven_done_start() { __raven_done_t0=$SECONDS; __raven_done_cmd=$1; }
    __raven_done_end() {
        local code=$?
        if [ -n "$__raven_done_t0" ] && [ $((SECONDS - __raven_done_t0)) -ge 30 ]; then
            [ -n "$__raven_done_cmd" ] || __raven_done_cmd=$(HISTTIMEFORMAT= history 1 | sed 's/^ *[0-9]* *//')
            ( ~/.local/bin/raven-done "$code" "$((SECONDS - __raven_done_t0))" "$__raven_done_cmd" "$PWD" "$$" >/dev/null 2>&1 & )
        fi
        __raven_done_t0=
        __raven_done_cmd=
        return "$code"
    }
    if [ "$TERM_PROGRAM" = WarpTerminal ]; then
        preexec_functions+=(__raven_done_start)
        precmd_functions=(__raven_done_end "${precmd_functions[@]}")
    else
        PS0+='${__raven_done_nil[__raven_done_t0=SECONDS]}'
        PROMPT_COMMAND="__raven_done_end; ${PROMPT_COMMAND}"
    fi
fi

# RAVEN dctime (bin/raven-dctime): clock to a domain controller's for Kerberos, `dctime off` after.
dctime() { ~/.local/bin/raven-dctime "$@"; }
