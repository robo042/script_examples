#!/usr/bin/env python3


from argparse import ArgumentParser
from os import path, getcwd
from sys import argv, stderr


def write(text, bold=False):
    ''' writes to stdout '''
    if bold: 
        text = '\033[1m ' + text + ' \033[0m'
    print('[*] ' + text)
    return


def error(message):
    ''' writes to stderr '''
    print('[!] ' + message, file=stderr)
    return


def error_exit(message):
    ''' prints an error message and exits with a non-zero return code '''
    error(message)
    exit(1)


def analyze_target(target, is_special=False):
    ''' simple example function '''
    if path.isfile(target):
        write(f'\t{target} is a file.', bold=is_special)
    elif path.isdir(target):
        write(f'\t{target} is a directory.', bold=is_special)
    elif path.islink(target):
        write(f'\t{target} is a symbolic link.', bold=is_special)
    else:
        error(f'\t{target} is not a valid file or directory.')
    return


if __name__ == '__main__':

    # define our args
    parser = ArgumentParser(description='Simple automation sample script')
    parser.add_argument(
        '-f', '--flag', action='store_true', help='Activate the demo flag.')
    parser.add_argument(
        '-s', '--special', action='append', help='Highlight an argument.')
    parser.add_argument('targets', nargs='*', help='Positional arguments.')

    # parse our args
    args, unknown = parser.parse_known_args()
    special = args.special if args.special else []
    targets = sorted(args.targets + unknown + special)

    # where this script lives vs where it was called from
    script_path = path.abspath(argv[0])
    script_dir, call_dir = path.dirname(script_path), getcwd()
    write(f'Script lives at: {script_path}')
    write(f'Called from:     {call_dir}')

    # take some action based on some flag
    if args.flag:
        write('-f / --flag is active.', bold=True)

    # do some stuff
    if targets:
        write(f'{len(targets)} targets provided')
    else:
        error_exit('No targets provided.')

    for target in targets:
        analyze_target(target, is_special = target in special)

    # ensure successful runs leave a good (zero) return code
    exit(0)

