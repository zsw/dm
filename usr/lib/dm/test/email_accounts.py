#!/usr/bin/python

"""

Test suite for email_accounts.py

"""

import os
import sys
import unittest

env_var = 'HOME'
try:
    home = os.environ[env_var]
except KeyError:
    raise NameError(
            "%(env_var)s: environmental variable not found" % locals()
            )

dm_root = os.path.join(home, 'dm')
os.chdir(dm_root)
if not dm_root in sys.path:
    sys.path.append(dm_root)

from lib.email_accounts import EmailAccounts


class Test_EmailAccounts(unittest.TestCase):

    def set_up(self):
        if os.path.exists(self.file):
            os.unlink(self.file);

        fh = open(self.file, 'w')
        text = """[accounts]
email@example.com: mypassword

[google]
someapi: email@example.com
anotherapi: another@example.com
"""
        fh.write(text)
        fh.close()

    def tear_down(self):
        if os.path.exists(self.file):
            os.unlink(self.file);

    def test__init__(self):
        accounts = EmailAccounts();
        self.assertEqual( accounts.accounts, {})
        self.assertEqual( accounts.google, {})

        accounts = EmailAccounts(file='/tmp/some/fake/file');
        self.assertEqual( accounts.accounts, {})
        self.assertEqual( accounts.google, {})

        self.file = '/tmp/test_email_accounts.rc'
        self.set_up()

        accounts = EmailAccounts(file=self.file);
        expect_accounts = {'email@example.com': 'mypassword'}
        expect_google = {'someapi': 'email@example.com', 'anotherapi':
                'another@example.com'}
        self.assertEqual( accounts.accounts, expect_accounts)
        self.assertEqual( accounts.accounts['email@example.com'], 'mypassword')
        self.assertEqual( accounts.google, expect_google)
        self.assertEqual( accounts.google['someapi'], 'email@example.com')
        self.assertEqual( accounts.google['anotherapi'], 'another@example.com')

        self.tear_down()

def suite():
    suite = unittest.TestLoader().loadTestsFromTestCase(Test_EmailAccounts)
    return suite

if __name__ == '__main__':
    unittest.TextTestRunner(verbosity=2).run(suite())

