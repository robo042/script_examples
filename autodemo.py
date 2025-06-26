#!/usr/bin/env python3


from argparse import ArgumentParser
from pathlib import Path
from sys import argv, stderr


def write(text, bold=False):
    ''' writes to stdout '''
    if bold: 
        text = '\033[1m' + text + '\033[0m'
    print('[*] ' + text)
    return


def error(message):
    ''' writes to stderr '''
    print('[!] ' + message, file = stderr)
    return


def error_exit(message):
    ''' prints an error message and exits with a non-zero (bad) return code '''
    error(message)
    exit(1)


def analyze_target(target, is_special = False):
    ''' simple example function '''
    if Path(target).is_file():
        write(f'\t{target} is a file.', bold = is_special)
    elif Path(target).is_dir():
        write(f'\t{target} is a directory.', bold = is_special)
    elif Path(target).is_symlink():
        write(f'\t{target} is a symbolic link.', bold = is_special)
    else:
        error(f'\t{target} is not a valid file or directory.')
    return


if __name__ == '__main__':

    # define our args
    parser = ArgumentParser(description = 'Simple automation sample script')
    parser.add_argument(
        '-f', '--flag', action = 'store_true', help = 'activate the demo flag')
    parser.add_argument(
        '-s', '--special', action = 'append', help = 'highlight an argument')
    parser.add_argument('targets', nargs = '*', help = 'positional arguments')

    # parse our args
    args, unknown = parser.parse_known_args()
    special = args.special if args.special else []
    targets = sorted(set(args.targets + unknown + special))

    # where this script lives vs where it was called from
    call_dir, script_path = Path.cwd(), Path(__file__).resolve()
    write(f'Script lives at: {script_path}')
    write(f'Called from:     {call_dir}')

    # take some action based on some flag
    if args.flag:
        write('-f / --flag is active.', bold = True)

    # do some stuff
    if targets:
        write(f'{len(targets)} targets provided')
    else:
        error_exit('No targets provided.')

    for target in targets:
        analyze_target(target, is_special = target in special)

    # ensure successful runs leave a good (zero) return code
    exit(0)

