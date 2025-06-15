# Script Examples

This repository is a small collection of example scripts showcasing my
preferred scripting style and best practices for command-line automation.

The current focus is on argument parsing, script hygiene, and robust behavior 
under real-world usage patterns. These scripts are intentionally minimalist —
designed to be clear, extendable, and suitable as templates for future
automation work.

I use this style in both personal automation and production-grade tooling, and
it’s held up across teams, projects, and weird edge cases.

## Contents

### `autodemo.py`
A Python 3 script that uses `argparse` to demonstrate:
- Named flags and positional arguments
- Support for multiple `--special` arguments
- Mixed-order parsing (`--flag` before/after args)
- Bolded output for specific arguments
- Consistent formatting and error handling

### `autodemo.sh`
A Bash implementation of the same logic, demonstrating:
- Manual argument parsing without `getopts`
- Clean function structure and scoped variables
- Portable script path resolution
- ANSI formatting
- Matching behavior to the Python version

## Philosophy

This project isn’t just about scripting — it’s about scripting **well**:
- Arguments should be flexible and order-independent
- Error messages should be clear and immediate
- Output should be consistent and human-readable
- Scripts should work the same way every time, no surprises

## License

Free code. No strings attached.

Use it, fork it, copy-paste it into your thesis or your startup. You don’t
need to ask for permission, and I won’t pretend to care. MIT license, for
those who like legal symbols.

## Future Plans

I may add more demonstration scripts in the future — possibly covering:
- idempotency patterns
- Safe file modifications
- Scripting with remote systems
- Workflow orchestration

