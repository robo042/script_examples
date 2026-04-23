#!/usr/bin/env bash

error(){
    # writes to stderr
    echo -e "[!] $*" >&2 && return
}

error_exit(){
    # writes an error message and exits with a non-zero (bad) return code
    error "$@"
    exit 1
}

escape_ere(){
    printf '%s\n' "$1" | sed 's/[][(){}.^$*+?|\\/]/\\\\&/g'
}

get_value(){
    template_param_scan get "$1" "$2"
}

is_valid_csv(){
    local file="$1"
    [[ -f $file && -r $file ]] || return 1
    awk -F ','  'BEGIN { ok = 1 }
      /^[[:space:]]*$/ { ok = 0; next }
               NR == 1 { n = NF; if (n < 1) ok = 0 }
               NF != n { ok = 0 } 
                   END { exit ok ? 0 : 1}' "$file"
    return
}

log(){
    # writes to stdout
    echo -e "[*] $*" && return
}

render_template(){
    local template_file="$1" outfile="$2" sep=$'\x1f' keys_pat=()
    local keys vals keys_blob vals_blob kpat_blob
    keys=("${headers[@]}" pseudo_dir outdir)
    vals=("${row_values[@]}" "'$pseudo_dir'" "'$outdir'")
    for k in "${keys[@]}"; do keys_pat+=("$(escape_ere "${k,,}")"); done
    keys_blob="$(printf "%s${sep}" "${keys[@]}")"
    vals_blob="$(printf "%s${sep}" "${vals[@]}")"
    kpat_blob="$(printf "%s${sep}" "${keys_pat[@]}")"
    keys_blob="${keys_blob%$sep}"
    vals_blob="${vals_blob%$sep}"
    kpat_blob="${kpat_blob%$sep}"
    awk -v sep="$sep" -v keys_blob="$keys_blob" \
        -v vals_blob="$vals_blob" -v kpat_blob="$kpat_blob" '
      function split_code_comment(line,    i, c, sq, dq){
          code_part = ""
          comment_part = ""
          sq = dq = 0
          for(i = 1; i <= length(line); i++){
              c = substr(line, i, 1)
              if(c == "'"'"'" && !dq){ sq = !sq}
              else if(c == "\"" && !sq){ dq = !dq }
              else if(c == "!" && !sq && !dq){
                  code_part = substr(line, 1, i - 1)
                  comment_part = substr(line, i)
                  return
              }
          }
          code_part = line
          comment_part = ""
      }
      function replace_param(code, key, val, pat, low, full_start,
                             full_len, lead_len, before, lead, rhs, after){
          low = tolower(code)
          pat = "(^|[^[:alnum:]_])" pat "[[:space:]]*=[[:space:]]*"
          if(!match(low, pat)){ return code }
          full_start = RSTART
          full_len   = RLENGTH
          lead_len   = 0
          if(substr(low, full_start, 1) != substr(key, 1, 1)){lead_len = 1}
          before = substr(code, 1, full_start - 1)
          lead   = (lead_len ? substr(code, full_start, 1) : "")
          rhs    = substr(code, full_start + full_len)
          if(match(rhs, /^[[:space:]]*'\''[^'\'']*'\''/)){
                 after = substr(rhs, RLENGTH + 1)
          }else if(match(rhs, /^[[:space:]]*"[^"]*"/)){
                 after = substr(rhs, RLENGTH + 1)
          }else if(match(rhs, /^[[:space:]]*[^,[:space:]]+/)){
                 after = substr(rhs, RLENGTH + 1)
          }else{ after = rhs}
          return before lead key " = " val after
      }BEGIN{
          n = split(keys_blob, keys, sep)
          split(vals_blob, vals, sep)
          split(kpat_blob, kpats, sep)
          for(i = 1; i <= n; i++){keys[i] = tolower(keys[i])}
      }{
          split_code_comment($0)
          code = code_part
          for(i = 1; i <= n; i++){
              code = replace_param(code, keys[i], vals[i], kpats[i])
          }
          print code comment_part
      }' "$template_file" > "$outfile"
      return
}

resolve_dir_path(){
    local raw_path="$1" base_dir="$2" abs_path=
    if [[ $raw_path == /* ]]
    then abs_path="$raw_path"
    else abs_path="${base_dir}/${raw_path}"
    fi
    [[ -d $abs_path ]] || error_exit "directory does not exist: $abs_path"
    (cd -- "$abs_path" &>/dev/null && pwd)
    return
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
      -f, --force          overwrite existing generated sweep files

    examples:
      $(basename "$0") sweeps.csv Example1/scf.in
      $(basename "$0") Example2/scf.in scf_sweeps.csv
      $(basename "$0") Example1/nscf_sweeps.csv Example1/nscf.in 

____EOF
    return
}

template_param_count(){
    template_param_scan count "$1" "$2"
    return
}

template_param_scan(){
    local mode="$1" file="$2" param="$3" pat
    pat="$(escape_ere "${param,,}")"
    awk -v mode="$mode" -v pat="$pat" '
      function strip_comment(line, out, i, c, sq, dq){
        out = ""; sq = dq = 0
        for(i = 1; i <= length(line); i++){
          c = substr(line, i, 1)
          if     (c == "'"'"'" && !dq)       { sq = !sq }
          else if(c == "\""    && !sq)       { dq = !dq }
          else if(c == "!"     && !sq && !dq){ break }
          out = out c
        } return out
      }
      function parse_rhs(rhs, m){
        if(match(rhs, /^[[:space:]]*'\''([^'\'']*)'\''[[:space:]]*,?/, m)){
          return m[1]
        }else if(match(rhs, /^[[:space:]]*"([^"]*)"[[:space:]]*,?/, m)){
          return m[1]
        }else if(match(rhs, /^[[:space:]]*([^,[:space:]]+)[[:space:]]*,?/, m)){
          return m[1]
        }return ""
      } {
        line = strip_comment($0)
        low  = tolower(line)
        while(match(low, "(^|[^[:alnum:]_])" pat "[[:space:]]*=[[:space:]]*")){
          start = RSTART + RLENGTH
          rhs   = substr(line, start)
          if(count == 0){ value = parse_rhs(rhs)}
          count++
          line = substr(line, start)
          low  = substr(low,  start)
        }
      }END{
        if     (mode == "count") { print count + 0; exit 0}
        else if(mode == "get")   { if(count == 1){print value; exit 0 } exit 1}
        exit 2
      }' "$file"
    return
}

trim(){
    local s="$1"
    s="${s//$'\r'/}"
    s="${s#"${s%%[![:space:]]*}"}"
    printf '%s\n' "${s%"${s##*[![:space:]]}"}"
    return
}

usage(){
    # abbreviated help function
    cat <<- ____EOF | sed -e 's/^    //';
    usage: $(basename "$0") [-h] [-f] file_a file_b

____EOF
    return
}

if [[ ${BASH_SOURCE[0]} == $0 ]]
then

    # -e  aborts on command failure
    # -u  aborts on undefined variables
    # -o pipefail ensures we're not silently failing in pipelines
    set -euo pipefail

    # define our args
    args=()
    csv_file=
    force=
    template_file=

    # parse our args
    while [[ $# -gt 0 ]]
    do case "$1" in
         -f|--force) force=1 && shift ;;
          -h|--help) show_help && exit 0 ;;
                 -*) usage; error_exit "invalid option: $1" ;;
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
    do n_matches="$(template_param_count "$template_file" "$param")"
       if [[ $n_matches -eq 0 ]]
       then error_exit "template parameter not found: $param"
       elif [[ $n_matches -gt 1 ]]
       then error 'template parameter is ambiguous'
            error_exit "(found $n_matches matches): $param"
       fi
    done

    # grab pseudo_dir and outdir
    template_dir="$(cd -- "$(dirname -- "$template_file")" &>/dev/null && pwd)"
    pseudo_dir_raw="$(get_value "$template_file" pseudo_dir)" ||
        error_exit 'could not uniquely extract pseudo_dir from template'
    outdir_raw="$(get_value "$template_file" outdir)" ||
        error_exit 'could not uniquely extract outdir from template'
    pseudo_dir="$(resolve_dir_path "$pseudo_dir_raw" "$template_dir")"

    # derive template stem/ext from basename; strip only rightmost dot suffix
    template_name="$(basename -- "$template_file")"
    if [[ $template_name == *.* ]]
    then template_stem="${template_name%.*}"
         template_ext=".${template_name##*.}"
    else template_stem="$template_name"
         template_ext=
    fi
    sweep_dir="${template_dir}/${template_stem}_sweeps"
    outdir="$sweep_dir"

    # # count csv data rows (exclude header)
    csv_rows="$(awk 'END{ print NR - 1 }' "$csv_file")"
    [[ $csv_rows -gt 0 ]] || error_exit 'csv contains no data rows.'

    # create sweep directory
    mkdir -p -- "$sweep_dir"

    # compute intended output filenames and check for collisions
    collisions=()
    planned_files=()

    for ((i = 1; i <= csv_rows; i++))
    do printf -v idx '%03d' "$i"
       outfile="${sweep_dir}/${template_stem}${idx}${template_ext}"
       planned_files+=("$outfile")
       [[ -e $outfile ]] && collisions+=("$outfile")
    done

    if [[ ${#collisions[@]} -gt 0 && -z ${force:-} ]]
    then for file in "${collisions[@]}"
         do error "$(realpath --relative-to=. "$file") already exists"
         done
         error_exit 'refusing to overwrite existing sweep files'
    fi

    row_num=0
    while IFS=',' read -r -a row_values
    do ((++row_num))
       for i in "${!row_values[@]}"
       do row_values[$i]="$(trim "${row_values[$i]}")"
       done
       if ! [[ ${#row_values[@]} -eq ${#headers[@]} ]]
       then error_exit "csv row $row_num has wrong number of fields"
       fi 
       printf -v idx '%03d' "$row_num"
       outfile="${sweep_dir}/${template_stem}${idx}${template_ext}"
       render_template "$template_file" "$outfile"
       log "wrote $(realpath --relative-to=. "$outfile")"
    done < <(tail -n +2 "$csv_file")
    
    exit 0
fi
