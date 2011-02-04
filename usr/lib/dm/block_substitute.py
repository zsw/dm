#!/usr/bin/python -W ignore::DeprecationWarning

"""
usage: block_substitute.py [OPTIONS] file.txt pattern.txt replace.txt

This script will substitute a block of text (the contents of
pattern.txt) in a file (file.txt) with another block of text (contents
of replace.txt) and print the result to stdout.

OPTIONS:

    -g  Global search and replace.
    -h  Print this help message.

EXAMPLES:
    block_substitute.py /path/to/file.txt /path/to/pattern.txt /path/to/replace.txt

NOTES:

    By default only the first match is replaced. If the -g,
    --global-replace, option is provided all matches are replaced.
"""

from optparse import OptionParser
import re
import sys

def file_contents(file=None):
    """Read and return contents of file.

    Args:
        file: The name of file optionally including path.
    Return:
        string. The contents of the file.

    """
    content = None
    with open(file, 'rb') as f:
        content = f.read()
    return content

def main():
    """Process options and perform search and replace"""

    usage = "usage: %prog [OPTIONS] file pattern_file replace_file"
    parser = OptionParser(usage=usage)

    parser.add_option("-g", "--global-replace",
                     action="store_true", dest="global_replace", default=False,
                     help="Replace all occurrences of pattern instead of just the first.")

    (options, args) = parser.parse_args()

    if len(args) < 3:
        print >> sys.stderr, 'ERROR: Three file name arguments required.'
        parser.print_help()
        exit(1)

    text_file = args[0]
    pattern_file = args[1]
    replace_file = args[2]

    text = file_contents(file=text_file)
    pattern = file_contents(file=pattern_file)
    replace = file_contents(file=replace_file)
    count = 1
    if options.global_replace:
        count = 0
    sys.stdout.write(re.compile(re.escape(pattern),
            re.MULTILINE|re.DOTALL).sub(replace, text, count))

if __name__ == '__main__':
    main()
