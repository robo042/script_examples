#!/usr/bin/env bash

log(){
    # writes to stdout
    echo -e "[*] $*" && return 0
}

error(){
    # writes to stderr
    echo -e "[!] $*" >&2 && return 0
}

error_exit(){
    # writes an error message and exits with a non-zero (bad) return code
    error "$@"
    exit 1
}

show_help(){
    # help function
    cat <<- ____EOF | sed -e 's/^    //';
    usage: $(basename "$0") [-h] [targets ...]

    blah blah I'm a help method

    positional arguments:
      targets               input arguments

    options:
      -h, --help            show this help message and exit

    examples:
      go here
____EOF
    return 0
}


if [[ ${BASH_SOURCE[0]} == $0 ]]; then

    # -e  aborts on command failure
    # -u  aborts on undefined variables
    # -o pipefail ensures we're not silently failing in pipelines
    set -euo pipefail

    # define our args
    had_error=0
    targets=()

    # parse our args
    # TODO - we need:
    # - an scf.in file to act as a template
    # - a list of numbers to cycle through
    # - (maybe) an alternate location to store the output_dir
    while [[ $# -gt 0 ]]; do
        case "$1" in
          -h|--help)
              show_help && exit 0 ;;
          -*)
              error_exit "Invalid option: $1" ;;
          *)
              targets+=("$1") && shift ;;
        esac
    done

    # do the thing
    for target in "${targets[@]}"; do
        # TODO: Ok so first thing is that there's a pseudopotential file 
        # that we an assume lives someplace indicated by `pseudo_dir`. So we 
        # want to create a bunch of new scf.in files but in a subdirectory of
        # the original scf.in. The new scf.in files should be numbered and
        # their `pseudo_dir` values should be updated accordingly.  
        # 
        # TODO: The next thing is to read our list of numbers to cycle through.
        # We need some type of structured way to store the data... perhaps with
        # a header row like:
        #       ibrav ntyp ecutwfc
        # and then each row after is a list of 3 numbers corresponding to the
        # thing that should be updated in the resulting scf.in.
        log "Done: $target"
    done

    # nonzero exit if anything went wrong
    exit $had_error
fi
