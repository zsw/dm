#!/usr/bin/python

"""

Test suite for google/contact.py

"""

import os
import sys
import unittest
import gdata.contacts

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

from lib.google.contact import Contact

xml_name_only = """
<ns0:entry ns1:etag="&quot;QHk5eTVSLyt7ImA9WxBTE00CRQw.&quot;" xmlns:ns0="http://www.w3.org/2005/Atom" xmlns:ns1="http://schemas.google.com/g/2005">
<ns0:category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/contact/2008#contact" />
<ns0:id>http://www.google.com/m8/feeds/contacts/jimkarsten%40gmail.com/base/973ed50d526d2e</ns0:id>
<ns0:title>Name Only</ns0:title>
<ns1:email address="work@gmail.com" primary="true" rel="http://schemas.google.com/g/2005#work" />
<ns1:name><ns1:fullName>Only Name</ns1:fullName></ns1:name>
</ns0:entry>
"""

xml_organization_only = """
<ns0:entry ns1:etag="&quot;Q3o8eDVSLyt7ImA9WxBTE00CRAA.&quot;" xmlns:ns0="http://www.w3.org/2005/Atom" xmlns:ns1="http://schemas.google.com/g/2005">
<ns0:category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/contact/2008#contact" />
<ns0:id>http://www.google.com/m8/feeds/contacts/jimkarsten%40gmail.com/base/329be6e90fc963ed</ns0:id>
<ns0:title />
<ns1:organization primary="false" rel="http://schemas.google.com/g/2005#work">
<ns1:orgName>Just A Company</ns1:orgName></ns1:organization>
<ns1:email address="justacompany@gmail.com" primary="true" rel="http://schemas.google.com/g/2005#home" />
</ns0:entry>
"""

xml_name_and_organization = """
<ns0:entry ns1:etag="&quot;R3w5cTVSLSt7ImA9WxBTE00CRAw.&quot;" xmlns:ns0="http://www.w3.org/2005/Atom" xmlns:ns1="http://schemas.google.com/g/2005">
<ns0:category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/contact/2008#contact" />
<ns0:id>http://www.google.com/m8/feeds/contacts/jimkarsten%40gmail.com/base/73506f74899e144a</ns0:id>
<ns0:title>Christina Brown</ns0:title>
<ns1:organization primary="false" rel="http://schemas.google.com/g/2005#work">
<ns1:orgName>Mather Management</ns1:orgName></ns1:organization>
<ns1:email address="cbrown@mathermanagement.com" primary="true" rel="http://schemas.google.com/g/2005#home" />
<ns1:email address="sales@mathermanagement.com" primary="false" rel="http://schemas.google.com/g/2005#work" />
<ns1:phoneNumber primary="false" rel="http://schemas.google.com/g/2005#home">519 111-1111</ns1:phoneNumber>
<ns1:phoneNumber primary="false" rel="http://schemas.google.com/g/2005#work">519 222-2222</ns1:phoneNumber>
<ns1:phoneNumber primary="false" rel="http://schemas.google.com/g/2005#mobile">519 333-3333</ns1:phoneNumber>
<ns1:name>
<ns1:fullName>Christina Brown</ns1:fullName></ns1:name></ns0:entry>
"""

xml_no_name_or_organization = """
<ns0:entry ns1:etag="&quot;Q3o8eDVSLyt7ImA9WxBTE00CRAA.&quot;" xmlns:ns0="http://www.w3.org/2005/Atom" xmlns:ns1="http://schemas.google.com/g/2005">
<ns0:category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/contact/2008#contact" />
<ns0:id>http://www.google.com/m8/feeds/contacts/jimkarsten%40gmail.com/base/329be6e90fc963ed</ns0:id>
<ns0:title />
<ns2:edited xmlns:ns2="http://www.w3.org/2007/app">2009-12-08T21:39:02.470Z</ns2:edited></ns0:entry>
"""

xml_single_email = xml_name_only
xml_multiple_emails = xml_name_and_organization
xml_no_email = xml_no_name_or_organization
xml_multiple_phones = xml_name_and_organization

class Test_Contact(unittest.TestCase):

    def set_up(self):
        pass

    def tear_down(self):
        pass

    def test__init__(self):
        contact_entry = gdata.contacts.ContactEntryFromString(xml_name_and_organization)
        contact = Contact(entry=contact_entry);
        self.assertEqual( contact.entry.title.text, 'Christina Brown')
        self.assertEqual( contact.entry.organization.org_name.text,
                'Mather Management')

    def test_is_match(self):
        contact_entry = gdata.contacts.ContactEntryFromString(xml_name_and_organization)
        contact = Contact(entry=contact_entry);
        # match name
        self.assertEqual( contact.is_match('Christina'), True)
        # match organization
        self.assertEqual( contact.is_match('Mather'), True)
        # match email
        self.assertEqual( contact.is_match('cbrown@mathermanagement.com'), True)
        # match name and email
        self.assertEqual( contact.is_match('brown'), True)
        # match second email
        self.assertEqual( contact.is_match('sales@mathermanagement.com'), True)
        # no match
        self.assertEqual( contact.is_match('xxxxxx'), False)
        # case insensitive
        self.assertEqual( contact.is_match('CHRISTINA'), True)

    def test_parse_emails(self):
        contact_entry = gdata.contacts.ContactEntryFromString(xml_single_email)
        contact = Contact(entry=contact_entry);
        self.assertEqual( contact.emails, [{'address': 'work@gmail.com', 'rel': 'work'}])

        contact_entry = gdata.contacts.ContactEntryFromString(xml_multiple_emails)
        contact = Contact(entry=contact_entry);
        self.assertEqual( contact.emails,
                [
                    {'address': 'cbrown@mathermanagement.com', 'rel': 'home'},
                    {'address': 'sales@mathermanagement.com',  'rel': 'work'},
                ]
                )

        contact_entry = gdata.contacts.ContactEntryFromString(xml_no_email)
        contact = Contact(entry=contact_entry);
        self.assertEqual( contact.emails, [])

    def test_parse_phones(self):
        contact_entry = gdata.contacts.ContactEntryFromString(xml_multiple_emails)
        contact = Contact(entry=contact_entry);
        self.assertEqual( contact.emails,
                [
                    {'number': '519 111-1111', 'rel': 'home'},
                    {'number': '519 222-2222', 'rel': 'work'},
                    {'number': '519 333-3333', 'rel': 'mobile'},
                ]
                )

    def test_set_fullname(self):
        contact_entry = gdata.contacts.ContactEntryFromString(xml_name_only)
        contact = Contact(entry=contact_entry);
        self.assertEqual( contact.fullname, 'Name Only')

        contact_entry = gdata.contacts.ContactEntryFromString(xml_organization_only)
        contact = Contact(entry=contact_entry);
        self.assertEqual( contact.fullname, 'Just A Company')

        contact_entry = gdata.contacts.ContactEntryFromString(xml_name_and_organization)
        contact = Contact(entry=contact_entry);
        self.assertEqual( contact.fullname, 'Christina Brown (Mather Management)')

        contact_entry = gdata.contacts.ContactEntryFromString(xml_no_name_or_organization)
        contact = Contact(entry=contact_entry);
        self.assertEqual( contact.fullname, 'n/a')

def suite():
    suite = unittest.TestSuite()
    suite.addTest(Test_Contact('test__init__'))
    suite.addTest(Test_Contact('test_is_match'))
    suite.addTest(Test_Contact('test_parse_emails'))
    suite.addTest(Test_Contact('test_set_fullname'))
    return suite

if __name__ == '__main__':
    unittest.TextTestRunner(verbosity=2).run(suite())

