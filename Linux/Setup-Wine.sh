#!/bin/bash

# Modified version of https://github.com/kyechou/leagueoflegends/blob/b5ded8c3e324df0d4fa88bbc65482b9fdbacbc71/leagueoflegends

set -euo pipefail

msg() {
    echo -e "[+] ${1-}" >&2
}

die() {
    echo -e "[!] ${1-}" >&2
    exit 1
}

askQ() {
    count=1
    first_arg="$2"
    echo
    echo "    $1"
    for var in "${@:2}"; do
        echo "    #$count - $2"
        ((count++))
        shift
    done
    echo
}

check_depends() {
    echo "::group::Installing dependencies"
    sudo apt-add-repository "ppa:ondrej/php" -y # See https://github.com/actions/virtual-environments/issues/3339
    sudo dpkg --add-architecture i386
    sudo apt-get update > /dev/null
    depends=(wine wine32:i386 wineboot winecfg wineserver curl cabextract winbind)
    for dep in ${depends[@]}; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo "Missing $dep, installing it..."
            sudo apt-get install -y $dep > /dev/null
        fi
    done
    echo "::endgroup::"

    install_winetricks

    optdepends=(zenity)
    for dep in ${optdepends[@]}; do
        if command -v "$dep" >/dev/null 2>&1; then
            export "HAS_$(echo $dep | awk '{ print toupper($0) }')"=1
        fi
    done
}

install_winetricks() {
    # From https://github.com/Winetricks/winetricks#installing

    echo "::group::Installing dependency winetricks (latest, from source)"

    ## Create and switch to a temporary directory writeable by current user. See:
    ##   https://www.tldp.org/LDP/abs/html/subshells.html
    #cd "\$(mktemp -d)"

    # Download the latest winetricks script (master="latest version") from Github.
    wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks

    # Mark the winetricks script (we've just downloaded) as executable. See:
    #   https://www.tldp.org/LDP/GNU-Linux-Tools-Summary/html/x9543.htm
    chmod +x winetricks

    # Move the winetricks script to a location which will be in the standard user PATH. See:
    #   https://www.tldp.org/LDP/abs/html/internalvariables.html
    sudo mv winetricks /usr/bin

    # Download the latest winetricks BASH completion script (master="latest version") from Github.
    wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks.bash-completion

    # Move the winetricks BASH completion script to a standard location for BASH completion modules. See:
    #   https://www.tldp.org/LDP/abs/html/tabexpansion.html
    sudo mv winetricks.bash-completion /usr/share/bash-completion/completions/winetricks

    # Download the latest winetricks MAN page (master="latest version") from Github.
    wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks.1

    # Move the winetricks MAN page to a standard location for MAN pages. See:
    #   https://www.pathname.com/fhs/pub/fhs-2.3.html#USRSHAREMANMANUALPAGES
    sudo mv winetricks.1 /usr/share/man/man1/winetricks.1

    echo "::endgroup::"
}

export_env_variables() {
    export PATH="/opt/wine-lol/bin:$PATH"
    export CACHE_DIR="$HOME/.cache/leagueoflegends"

    export WINEARCH=win32
    export WINEDEBUG=fixme-all
    export WINEDLLOVERRIDES="mscoree,mshtml=;winemenubuilder.exe="
    export WINE_REQ_MOD=(win10 d3dcompiler_43 d3dx9 vcrun2019)
    export WINEPREFIX="$HOME/.local/share/leagueoflegends"
    export RCS_DIR="$WINEPREFIX/drive_c/Riot Games"
    export RCS_EXE="$RCS_DIR/Riot Client/RiotClientServices.exe"

    export MESA_GLTHREAD=true
    export STAGING_SHARED_MEMORY=1
    export WINE_LARGE_ADDRESS_AWARE=1
    export __GL_SHADER_DISK_CACHE=1
    export __GL_SHADER_DISK_CACHE_PATH="$WINEPREFIX"
    export __GL_THREADED_OPTIMIZATIONS=1
}

create_wineprefix() {
    echo "::group::Creating Wine prefix"
    if [ -e "$WINEPREFIX" ]; then
        die "Wineprefix $WINEPREFIX already exists"
    fi

    msg "Creating wineprefix: $WINEPREFIX"
    mkdir -p "$WINEPREFIX"
    wineboot --init
    msg "Installing winetricks verbs: ${WINE_REQ_MOD[*]}"
    winetricks -q --optout --force "${WINE_REQ_MOD[@]}"
    for link in "$WINEPREFIX/dosdevices"/*; do
        [[ "$link" =~ 'c:' ]] && continue # for drive_c
        [[ "$link" =~ 'z:' ]] && continue # for /
        msg "Removing unnecessary device $(basename $link)"
        unlink "$link"
    done
    msg "Waiting for wine processes..."
    wineserver --wait
    msg "Wineprefix created: $WINEPREFIX"

    echo "::endgroup::"
}

install_LoL() {
    if [ ! -d "$WINEPREFIX" ]; then
        create_wineprefix
    elif [ -f "$RCS_EXE" ]; then
        while :; do
            echo -n "[!] The game has been installed. Remove it and reinstall? [Y/n] "
            read remove
            remove="$(echo "$remove" | tr '[:upper:]' '[:lower:]')"
            if [ -z "${remove##y*}" ]; then
                rm -rf "$RCS_DIR"
                break
            elif [ -z "${remove##n*}" ]; then
                exit 1
            fi
        done
    fi

    echo "::group::Installing League Client"
    INSTALLER="$CACHE_DIR/installer.${LOL_REGION,,}.exe"
    INSTALLER_URL="https://lol.secure.dyn.riotcdn.net/channels/public/x/installer/current/live.${LOL_REGION,,}.exe"

    if [ ! -e "$INSTALLER" ]; then
        msg "Downloading installer..."
        mkdir -p "$CACHE_DIR"
        curl --silent --show-error -Lo "$INSTALLER" "$INSTALLER_URL"
    fi
    msg "Installing League of Legends..."
    wine "$INSTALLER"
    msg "Waiting for wine processes..."
    wineserver --wait
    msg "The game is installed at $RCS_DIR"
    echo "::endgroup::"
}

#
# https://www.reddit.com/r/leagueoflinux/comments/j07yrg/starting_the_client_script/
#
port_waiting_daemon() {
    # Find PID
    process=LeagueClientUx.exe
    uxpid=$(timeout 2m sh -c "until ps -C $process -o pid=; do sleep 1; done | sed 's/[[:space:]]*//g'")
    if [ -z "$uxpid" ]; then
        die "Could not find process ${process}"
    fi

    # Get the app-port parameter
    port=$(xargs -0 <"/proc/${uxpid}/cmdline" | sed -n 's/.*--app-port=\([[:digit:]]*\).*/\1/p')
    if [ -z "$port" ]; then
        die "Could not find --app-port of LeagueClientUx.exe"
    fi

    # Suspend the league client until app-port gets available
    kill -STOP ${uxpid}
    timeout 5m bash -c "
    until openssl s_client -connect :${port} <<< Q >/dev/null 2>&1; do
        sleep 1
    done"
    kill -CONT ${uxpid}
}

loading_screen() {
    if [ ${HAS_ZENITY-0} -eq 1 ]; then
        zenity --progress --pulsate --auto-close --no-cancel \
            --title="League of Legends" --window-icon="$ICON" \
            --text="Waiting for the League client port to open..."
    fi
}

start_LoL() {
    # prelaunch helper
    ( port_waiting_daemon ) | loading_screen &

    msg "Starting..."
    wine "$RCS_EXE" \
        --launch-product=league_of_legends \
        --launch-patchline=live \
        --region=${LOL_REGION,}
    wineserver --wait
    wait
}

check_depends
export_env_variables

create_wineprefix

#install_LoL
#start_LoL

# vim: set ts=4 sw=4 et: