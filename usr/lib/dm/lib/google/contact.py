#!/usr/bin/python

"""

Classes related to google contact api.

"""

import re

P_ID = re.compile(r'^http://www.google.com/m8/feeds/contacts/.*?/base/(.*)$')
P_REL = re.compile(r'^http://schemas.google.com/g/2005#(.*)$')

class Contact():
    """
    This class pseudo extends gdata.contacts.ContactEntry. The entry property
    points to a ContactEntry object.
    """
    def __init__(self, entry=None):
        self.entry = entry
        self.id = None
        if self.entry.id:
            match = P_ID.match(self.entry.id.text)
            if match:
                self.id = match.group(1)
        self.name = self.entry.title.text or None
        self.organization = None
        if self.entry.organization and self.entry.organization.org_name:
            self.organization = self.entry.organization.org_name.text or None
        self.emails = []
        self.parse_emails()
        self.phones = []
        self.parse_phones()
        self.fullname = ''
        self.set_fullname()

    def is_match(self, keyword):
        match = False
        for email in self.emails:
            if re.search(keyword, email['address'], re.IGNORECASE):
                match = True
        if self.name:
            if re.search(keyword, self.name, re.IGNORECASE):
                match = True
        if self.organization:
            if re.search(keyword, self.organization, re.IGNORECASE):
                match = True
        return match

    def parse_emails(self):
        for email in self.entry.email:
            rel = 'other'
            if email.rel:
                match = P_REL.match(email.rel)
                if match:
                    rel = match.group(1)
            self.emails.append( {'address': email.address, 'rel': rel} )

    def parse_phones(self):
        for phone in self.entry.phone_number:
            rel = 'other'
            if phone.rel:
                match = P_REL.match(phone.rel)
                if match:
                    rel = match.group(1)
            self.phones.append( {'number': phone.text, 'rel': rel} )

    def set_fullname(self):
        if self.name and self.organization:
            self.fullname = "%s (%s)" % (self.name, self.organization)
        elif self.organization:
            self.fullname = "%s" % (self.organization)
        elif self.name:
            self.fullname = "%s" % (self.name)
        else:
            self.fullname = 'n/a'

