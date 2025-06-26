#!/usr/bin/env bash

# -eu aborts on command failure or undefined variables
# -o pipefail ensures we're not silently failing in pipelines
set -euo pipefail

log(){
    # writes to stdout
    echo -e "[*] $@" && return 0
}

log_bold(){ 
    # writes to stdout in bold
    log "\033[1m${@}\033[0m" && return 0
}

error(){
    # writes to stderr
    echo -e "[!] $@" >&2 && return 0
} 

error_exit(){
    # writes an error message and exits with a non-zero (bad) return code
    error "$@"
    exit 1
}

analyze_target(){
    # simple example function
    local target="$1"
    is_special "$target" && log_exec=log_bold || log_exec=log
    if [[ -f $1 ]]; then
        $log_exec "\t$target is a file." && return 0
    elif [[ -d $target ]]; then
        $log_exec "\t$target is a directory." && return 0
    elif [[ -L $target ]]; then
        $log_exec "\t$target is a symbolic link." && return 0
    fi
    error "\t$target is not a valid file or directory."
    return 1
}

is_special(){
    # checks if target is special
    for s in ${specials[@]}; do [[ $s == $1 ]] && return 0; done
    return 1
}

show_help(){
    # help function
    cat <<- ____EOF | sed -e 's/^    //';
    usage: $(basename $0) [-h] [-f] [-s SPECIAL] [targets ...]
    
    Simple automation sample script
    
    positional arguments:
      targets               positional arguments
    
    options:
      -h, --help            show this help message and exit
      -f, --flag            activate the demo flag
      -s SPECIAL, --special SPECIAL
                            highlight an argument
____EOF
    return 0
}

if [[ $BASH_SOURCE == $0 ]]; then

    # define our args
    targets=() specials=() demo_flag=

    # parse our args
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -h|--help)
            show_help && exit 0 ;;
        -f|--flag)
            demo_flag=true && shift ;;
        -s|--special)
            opt="$1" && shift
            [[ -z $1 || $1 == -* ]] && error_exit "$opt requires an argument"
            specials+=("$1") && shift ;;
        -*)
            error_exit "Invalid option: -$1" ;;
         *) 
            targets+=("$1") && shift ;;
      esac
    done
    targets+=("${specials[@]}")
    targets=($(printf "%s\n" "${targets[@]}" | LC_ALL=C sort -u))

    # where this script lives vs where it was called from
    script_dir="$(cd -- $(dirname -- "${BASH_SOURCE[0]}") &>/dev/null && pwd)"
    script_path="${script_dir}/$(basename $0)" call_dir="$(pwd)"
    log "Script lives at: $script_path"
    log "Called from:     $call_dir"

    # take some action based on some flag
    [[ -n $demo_flag ]] && log_bold '-f / --flag is active.'

    # do some stuff
    [[ ${#targets[@]} -gt 0 ]] || error_exit 'No targets provided.'
    log "${#targets[@]} targets provided."
    for target in ${targets[@]}; do
        analyze_target "$target"
    done

    # ensure successful runs leave a good (zero) return code
    exit 0
fi
