#!/usr/bin/python

"""
This script parses a dm dependency tree.

For usage and help:

    tree_parse.py -h        # Brief usage and list of options
    tree_parse.py -f        # Full help including examples and notes

"""

__version__ = "0.1"
__author__ = "Jim Karsten (jimkarsten@gmail.com)"
__copyright__ = "(c) 2009-2010 Jim Karsten. GNU GPL 3."


from optparse import OptionParser
import re
import sys
import unittest

OPTIONS = None          # Global options


class TreeFile():
    def __init__(self, file=None, groups=None, mods=None):
        """Constructor.

        Args:
          file:     file    File-like object.
          groups:   list    List of TreeGroup objects

        """
        self.file = file
        self.groups = groups or {}
        self.mods = mods or {}
        return

    def parse(self, out_file=None, tag_ends=0):
        """Parse the tree file extracting groups.

        Populates the groups list. Optionally prints the tree file and
        tags end.

        Args:
            out_file:   file    Must be object with write(string) or None.
            tag_ends:   boolean If True, append group ids to end tags.

        """
        start_re = re.compile(r'\s*group (.*)')
        end_re = re.compile(r'\s*end$')
        mod_re = re.compile(r'\s*\[[ x]+\]\s*([0-9]{5})\s+')
        group_stack = []
        l = self.file.readline()
        while l:
            write_line = l
            mod_match = mod_re.match(l)
            if mod_match:
                id = int(mod_match.group(1))
                group_id = None
                if group_stack:
                    group_id = group_stack[-1]
                self.mods[id] = TreeMod(id=id, group_id=group_id)
            start_match = start_re.match(l)
            if start_match:
                id = int(start_match.group(1))
                group_stack.append(id)
            end_match = end_re.match(l)
            if end_match:
                if not group_stack:
                    # Oops, an end without a start
                    raise Exception("Group end tag found without corresponding start tag.")
                root_id = group_stack[0]
                id = group_stack.pop()
                parent_id = None
                if len(group_stack) > 0:
                    parent_id = group_stack[-1]
                self.groups[id] = TreeGroup(id=id, parent_id=parent_id,
                        root_id=root_id)
                if tag_ends:
                    write_line = re.sub('\n'," %03d\n" % (id), l)
            if out_file:
                out_file.write(write_line)
            l = self.file.readline()
        return


class TreeGroup():
    def __init__(self, id=0, parent_id=0, root_id=0):
        """Constructor.

        Args:
            id:         integer, id of group
            parent_id:  integer, id of parent group
            root_id:    integer, id of root parent group.

        Examples:
            group 111
                group 222
                    group 333
                    end
                end
            end
            Given the above tree structure,
            if id = 333,
                parent_id = 222
                root_id = 111
            if id = 111
                parent_id = 0
                root_id = 111

        """
        self.id = id
        self.parent_id = parent_id
        self.root_id = root_id
        return


class TreeMod():
    def __init__(self, id=0, group_id=0):
        """Constructor.

        Args:
            id:         integer, id of mod
            group_id:   integer, id of group mod belongs to

        """
        self.id = id
        self.group_id = group_id
        return


class Test_TreeFile(unittest.TestCase):

    def test___init__(self):
        tree_file = TreeFile()
        self.assertTrue(tree_file)      # returns object

    def test__parse(self):

        test_data = """
group 001
# some data
[ ] 11111 Fake mod
    group 003
    # some data
    [ ] 33333 Fake mod
    end
    group 004
    # some data
    [x] 44444 Fake mod
        group 005
        # some data
        [x] 55555 Fake mod
        [ ] 66666 Another fake mod.
        end
    end
end
group 002
# some data
[x] 22222 Fake mod
end
        """
        import tempfile
        import difflib

        tmp_file = tempfile.TemporaryFile()
        tmp_file.write(test_data)
        tmp_file.seek(0)    # Reset at at start of file for read

        tree_file = TreeFile(file=tmp_file)
        self.assertTrue(tree_file)      # returns object
        tree_file.parse()

        # Mods
        self.assertEqual(len(tree_file.mods), 6)        # Correct number of mods
        self.assertEqual(sorted(tree_file.mods.keys()),
                [11111, 22222, 33333, 44444, 55555, 66666]) # Correct mod keys

        # key: [id, group_id]
        expect = {
                    11111: [11111, 1],
                    22222: [22222, 2],
                    33333: [33333, 3],
                    44444: [44444, 4],
                    55555: [55555, 5],
                    66666: [66666, 5],
                }

        for i in expect.keys():
            mod = tree_file.mods[i]
            self.assertEqual(mod.id, expect[i][0])          # mod has correct id
            self.assertEqual(mod.group_id, expect[i][1])    # mod has correct group_id

        # Groups
        self.assertEqual(len(tree_file.groups), 5)  # Correct number of groups
        self.assertEqual(tree_file.groups.keys(),
                [1, 2, 3, 4, 5])                    # Correct group keys

        # key: [id, parent_id, root_id]
        expect = {
                    1: [1, None, 1],
                    2: [2, None, 2],
                    3: [3, 1, 1],
                    4: [4, 1, 1],
                    5: [5, 4, 1],
                }

        for i in expect.keys():
            group = tree_file.groups[i]
            self.assertEqual(group.id, expect[i][0])        # group has correct id
            self.assertEqual(group.parent_id, expect[i][1]) # group has correct parent_id
            self.assertEqual(group.root_id, expect[i][2])   # group has correct root_id

        tmp_file.seek(0)
        out_file = tempfile.TemporaryFile()
        out_file.seek(0)
        tree_file.parse(out_file=out_file)
        tmp_file.seek(0)
        out_file.seek(0)
        t = tmp_file.read()
        o = out_file.read()
        s = difflib.SequenceMatcher(None, t, o)
        self.assertEqual(s.ratio(), 1.0)                # output is the same as original

        tmp_file.seek(0)
        out_file = tempfile.TemporaryFile()
        out_file.seek(0)
        tree_file.parse(out_file=out_file, tag_ends=1)
        out_file.seek(0)
        end_ids = []
        end_re = re.compile(r'\s*end (.*)')
        l = out_file.readline()
        while l:
            end_match = end_re.match(l)
            if end_match:
                id = end_match.group(1)
                end_ids.append(id)
            l = out_file.readline()
        # Note: the end tags don't come in the same order as the start
        # tags :).
        self.assertEqual(end_ids, ['003', '005', '004', '001', '002'])   # end tags look good

        tmp_file.close()
        out_file.close()


class Test_TreeGroup(unittest.TestCase):

    def test___init__(self):
        tree_group = TreeGroup()
        self.assertTrue(tree_group)      # returns object

def run_tests():
    suite = unittest.TestSuite(
            [
            unittest.TestLoader().loadTestsFromTestCase(Test_TreeFile),
            unittest.TestLoader().loadTestsFromTestCase(Test_TreeGroup)
            ])
    unittest.TextTestRunner(verbosity=2).run(suite)
    return

def usage_full():
    return """
MODS
    A list of mods in tree file can be printed using the --mods, -m,
    option. A sample of output might look like so:

        11111 001
        22222
        33333 002

    The first column is the mod id. The second column is the id of the
    group the mod belongs to. If the mod is not in a group, the group id
    is blank.

    The results are *not* sorted. Use the shell sort command if sorted
    results are desired.

        # Sort by mod
        tree_parse.py --mods /path/to/tree | sort

        # Sort by group
        tree_parse.py --mods /path/to/tree | sort -k 2


TAGGING ENDS
    Groups in tree files are indicated by start and end tags.

        group 001
        [ ] 11111 Some mod.
        [ ] 22222 Another mod.
        end

    The start tag has an id, the end tag does not. This means the end tags
    of all groups are the same. The --tag-ends option can be used to append
    the group id to the end tags so they are unique and distinguishable.

        group 001
        [ ] 11111 Some mod.
        [ ] 22222 Another mod.
        end 001

    This can be helpful for extracting the group contents from a tree file.

    $ tree_parse.py --tag_ends /path/to/tree > /tmp/tmpfile
    $ cat /tmp/tmpfile | awk '/group 001/,/end 001/'


ROOT ID

    The --root-id option will print the id of the root group of a group.
    Groups can be contained within other groups. A root group is one
    that is not contained in any other.

    The easiest way to illustrate this is with an example.

        group 001
        [ ] 11111 Fake mod
            group 003
            [ ] 33333 Fake mod
            end
            group 004
            [ ] 44444 Fake mod
                group 005
                [ ] 55555 Fake mod
                end
            end
        end

        group 002
        [x] 22222 Fake mod
        end

    In the above tree, group 005 is contained in group 004. Groups 003
    and 004 are contained in group 001. Neither group 001 nor group 002
    are contained, so they are root groups. Group 001 is the root group
    of groups 003, 004 and 005.

    The root id of a root group is it's own id. The root id of a
    non-root group is the id of the the root group it belongs to.

        group id   root id
        001        001
        002        002
        003        001
        004        001
        005        001

    Why is this important? Say you wanted to move group 005 to a
    different tree file without disrupting the group it belongs to. In
    that case we'd have to move all of group 001 as well. The task of
    moving group 005 to a different tree file without disrupting the
    group it belongs to can be reframed as move group 001 to a different
    tree. In more general terms, the task of moving a group to a
    different tree file without disrupting the group it belongs to can
    be reframed as move its root group to a different tree.
    """


def main():
    """ Main routine.
    Args:
        None.
    Returns:
        None.
    """

    usage = "%prog [options] [FILE...]" + \
            "\nVersion: %s" % (__version__)
    parser = OptionParser(usage=usage)

    parser.add_option("-e", "--tag-ends",
                     action="store_true", dest="tag_ends",
                     help="Print to stdout end tags appended with group id.")
    parser.add_option("-f", "--full-help",
                     action="store_true", dest="full_help",
                     help="Print full help and exit. Full help includes examples and notes.")
    parser.add_option("-m", "--mods",
                     action="store_true", dest="mods",
                     help="Print a list of 'mod group' pairs.")
    parser.add_option("-r", "--root-id",
                     dest="root_id",
                     help="Print the id of the root group.")
    parser.add_option("-t", "--tests",
                     action="store_true", dest="tests",
                     help="Run tests and exist.")
    parser.add_option("-v", "--verbose",
                     action="store_true", dest="verbose", default=False,
                     help="Print messages to stdout.")

    (options, args) = parser.parse_args()

    global OPTIONS
    OPTIONS = options

    if OPTIONS.full_help:
        parser.print_help()
        print
        print usage_full()
        exit(0)

    if OPTIONS.tests:
        run_tests()
        exit(0)

    root_id = 0
    if OPTIONS.root_id:
        try:
            root_id = int(OPTIONS.root_id)
        except:
            print "ERROR: option -r: invalid group id value: %s" % (OPTIONS.root_id)
            exit(1)


    groups = {}
    mods = {}
    files = []

    if len(args) > 0:
        for arg in args:
            f = open(arg, 'r')
            files.append(TreeFile(file=f))
    else:
        files.append(TreeFile(file=sys.stdin))

    for file in files:
        f = None
        if OPTIONS.tag_ends:
            f = sys.stdout
        file.parse(tag_ends=OPTIONS.tag_ends, out_file=f)
        groups.update(file.groups)
        mods.update(file.mods)

    if root_id:
        if not root_id in groups:
            print "ERROR: Group %03d not found in trees." % (root_id)
            exit(1)
        print "%03d" % (groups[root_id].root_id)

    if OPTIONS.mods:
        for m in mods.values():
            if m.group_id:
                print "%05d %03d" % (m.id, m.group_id)
            else:
                print "%05d" % (m.id)


if __name__ == '__main__':
    main()

