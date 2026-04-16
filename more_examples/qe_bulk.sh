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
    usage: $(basename "$0") [-h] [-x qe_executable] [targets ...]

    Run Quantum ESPRESSO on each input file in sequence.

    Each target is passed to the QE executable with:
      <qe_executable> -in <target> > <target-derived-output>

    Output naming:
      - if input ends in ".in", replace that suffix with ".out"
      - otherwise append ".out"

    positional arguments:
      targets               input files to run sequentially

    options:
      -h, --help            show this help message and exit
      -x, --exe EXE         QE executable to use (default: pw.x)
      -f, --force           overwrite existing output files

    examples:
      $(basename "$0") scf.in nscf.in bands.in
      $(basename "$0") -x ph.x ph1.in ph2.in
      $(basename "$0") foo bar.in baz.input

____EOF
    return 0
}

outfile_from_target(){
    # names the outfile based on infile
    local target="$1"
    if [[ $target == *.in ]]; then
        printf '%s\n' "${target%.in}.out"
    else
        printf '%s\n' "${target}.out"
    fi
}

if [[ ${BASH_SOURCE[0]} == $0 ]]; then

    # ensures this is done already
    [[ ${SETVARS_COMPLETED:-} == 1 ]] || source /opt/intel/oneapi/setvars.sh 

    # -e  aborts on command failure
    # -u  aborts on undefined variables
    # -o pipefail ensures we're not silently failing in pipelines
    set -euo pipefail

    # define our args
    force=
    had_error=0
    qe_exe="pw.x"
    targets=()

    # parse our args
    while [[ $# -gt 0 ]]; do
        case "$1" in
          -h|--help)
              show_help && exit 0 ;;
          -f|--force)
              force=1 && shift ;;
          -x|--exe)
              shift
              [[ $# -gt 0 ]] || error_exit 'Option requires an argument: --exe'
              qe_exe="$1" && shift ;;
          --)
              shift && while [[ $# -gt 0 ]]; do
                  targets+=("$1") && shift
              done ;;
          -*)
              error_exit "Invalid option: $1" ;;
          *)
              targets+=("$1") && shift ;;
        esac
    done

    [[ ${#targets[@]} -gt 0 ]] || error_exit 'No input files provided.'

    # where this script lives vs where it was called from
    script_dir="$(cd -- $(dirname -- "${BASH_SOURCE[0]}") &>/dev/null && pwd)"
    script_path="${script_dir}/$(basename "$0")"
    call_dir="$(pwd)"

    # verify executable exists
    command -v "$qe_exe" >/dev/null 2>&1 ||{
        error_exit "Could not find QE executable in PATH: $qe_exe"
    }

    # do the thing
    for target in "${targets[@]}"; do

        # make sure the file we were given is a actual file
        if [[ ! -f $target ]]; then
            error "Input file does not exist: $target"
            had_error=1
            continue
        elif [[ ! -r $target ]]; then
            error "Input file is not readable: $target"
            had_error=1
            continue
        fi

        target_dir="$(cd -- "$(dirname -- "$target")" &>/dev/null && pwd)"
        target_name="$(basename -- "$target")"
        outfile_name="$(outfile_from_target "$target_name")"
        outfile="${target_dir}/${outfile_name}"

        # make sure we're not clobbering existing files
        if [[ -e $outfile && -z ${force:-} ]]; then
            error "Output file already exists: $outfile"
            error "Skipping '${target}' (use -f/--force to overwrite)"
            had_error=1
            continue
        fi

        log "Running: $qe_exe -in $target_name"
        log "Working directory: $target_dir"
        log "Writing: $outfile"

        # ensures the executable is run from within the same dir as the infile
        if ! (
            cd -- "$target_dir" && 
            "$qe_exe" -in "$target_name" > "$outfile_name")
        then
            error "QE run failed for input: $target"
            had_error=1
            continue
        fi

        log "Done: $target"
    done

    # nonzero exit if anything went wrong
    exit $had_error
fi
