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

escape_ere(){
    printf '%s\n' "$1" | sed 's/[][(){}.^$*+?|\\/]/\\\\&/g'
}

count_template_param_matches(){
    local file="$1" param="$2" pat
    pat="$(escape_ere "${param,,}")"
    awk -v pat="$pat" '
    function strip_comment(line, out, i, c, sq, dq){
        out = ""
        sq = dq = 0
        for(i = 1; i <= length(line); i++){
            c = substr(line, i, 1)
            if(c == "'"'"'" && !dq){ sq = !sq }
            else if(c == "\"" && !sq){ dq = !dq }
            else if(c == "!" && !sq && !dq){ break }
            out = out c
        } return out
    }{
        line = tolower(strip_comment($0))
        while(match(line, "(^|[^[:alnum:]_])" pat "[[:space:]]*=")){
            count++
            line = substr(line, RSTART + RLENGTH)
        }
    }END{ print count + 0 }' "$file"
}

is_valid_csv(){
    local file="$1"
    [[ -f $file && -r $file ]] || return 1
    awk -F ','  'BEGIN { ok = 1 }
      /^[[:space:]]*$/ { ok = 0; next }
               NR == 1 { n = NF; if (n < 1) ok = 0 }
               NF != n { ok = 0 } 
                   END { exit ok ? 0 : 1}' "$file"
    return $?
}

show_help(){
    # help function
    usage
    cat <<- ____EOF | sed -e 's/^    //';

    Generate a sweep directory of Quantum ESPRESSO input files from:
      - one csv file describing parameter values
      - one QE template input file

    The two positional files may be given in either order.  The script
    identifies the csv by validating its contents; the other file is treated
    as the QE template.

    The csv format is intentionally simple:
      - first row is the header
      - header fields are QE parameter names
      - each remaining row defines one generated input file
      - every row must have the same number of comma-separated fields
      - blank lines are not allowed

    The QE template file is expected to contain changeable parameters
    matching the csv header fields.

    Workflow summary:
      1. identify the csv and template inputs
      2. validate the csv structure
      3. validate the QE template and required paths
      4. create a *_sweeps directory beside the template
      5. generate one numbered QE input file per csv data row

    positional arguments:
      file_a               one of:    csv file or QE template file
      file_b               the other: QE template file or csv file

    options:
      -h, --help           show this help message and exit

    examples:
      $(basename "$0") sweeps.csv Example1/scf.in
      $(basename "$0") Example2/proj.in proj_sweeps.csv
      $(basename "$0") Example1/nscf.in Example1/ns_sweeps.csv

____EOF
    return 0
}

trim(){
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s\n' "$s"
}

usage(){
    # abbreviated help function
    cat <<- ____EOF | sed -e 's/^    //';
    usage: $(basename "$0") file_a file_b
____EOF
    return 0
}

if [[ ${BASH_SOURCE[0]} == $0 ]]
then

    # -e  aborts on command failure
    # -u  aborts on undefined variables
    # -o pipefail ensures we're not silently failing in pipelines
    set -euo pipefail

    had_error=0

    # define our args
    args=()
    csv_file=
    template_file=

    # parse our args
    while [[ $# -gt 0 ]]
    do case "$1" in
          -h|--help) show_help && exit 0 ;;
                 -*) error_exit "invalid option: $1" ;;
                  *) args+=("$1") && shift ;;
        esac
    done

    # validate args
    if ! [[ ${#args[@]} -eq 2 ]]
    then usage
         error_exit \
            'expected exactly two positional arguments: '\
            'one csv file and one QE template file.'
    fi

    for arg in "${args[@]}"
    do [[ -f $arg && -r $arg ]] || error_exit "can't read $arg"
       if is_valid_csv "$arg"
       then if [[ -z ${csv_file:-} ]]
            then csv_file="$arg"
            else error_exit 'more than one csv provided.'
            fi
       else if [[ -z ${template_file:-} ]]
            then template_file="$arg"
            elif [[ -z ${csv_file:-} ]]
            then error_exit 'no valid csv provided'
            else error_exit 'more than one QE-template provided.'
            fi 
       fi
    done

    # grab headers
    IFS=',' read -r -a headers < "$csv_file"
    for i in "${!headers[@]}";do headers[$i]="$(trim "${headers[$i],,}")";done

    # validate headers against template file
    for param in "${headers[@]}"
    do n_matches="$(count_template_param_matches "$template_file" "$param")"
       if [[ $n_matches -eq 0 ]]
       then error_exit "template parameter not found: $param"
       elif [[ $n_matches -gt 1 ]]
       then error 'template parameter is ambiguous'
            error_exit "(found $n_matches matches): $param"
       fi
    done

    # next step: grab pseudo_dir and outdir

    # nonzero exit if anything went wrong
    exit $had_error
fi
