#!/usr/bin/python

"""

Test suite for google/calendar.py

"""

import os
import sys
import unittest
import gdata.calendar

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

from lib.google.calendar import Event

xml_sample_event = """
<ns0:entry xmlns:ns0="http://www.w3.org/2005/Atom">
<ns0:category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/g/2005#event" />
<ns0:id>http://www.google.com/calendar/feeds/default/private/full/sv3uib1khlgui8nopnvv9rth2c
</ns0:id>
<ns0:title type="text">This is a sample event.</ns0:title>
<ns0:content type="text">Bring blue folder.</ns0:content>
<ns0:when endTime="2009-08-18T15:30:00.000-05:00" startTime="2009-08-18T07:45:00.000-05:00" xmlns:ns0="http://schemas.google.com/g/2005"><ns0:reminder method="sms" minutes="60" /><ns0:reminder method="alert" minutes="10" /></ns0:when>
<ns1:where valueString="285 Weber St N, Waterloo" xmlns:ns1="http://schemas.google.com/g/2005" />
</ns0:entry>
"""

class Test_Event(unittest.TestCase):

    def set_up(self):
        pass

    def tear_down(self):
        pass

    def test__init__(self):
        event_entry = gdata.calendar.CalendarEventEntryFromString(xml_sample_event)
        event = Event(entry=event_entry);
        self.assertEqual( event.entry.title.text, 'This is a sample event.')
        self.assertEqual( event.entry.content.text, 'Bring blue folder.')
        self.assertEqual( event.what, 'This is a sample event.')
        self.assertEqual( event.when, '2009-08-18 08:45:00')
        self.assertEqual( event.until, '2009-08-18 16:30:00')
        self.assertEqual( event.where, '285 Weber St N, Waterloo')
        self.assertEqual( len(event.reminders), 2)
        self.assertEqual( event.reminders[0], '60 minutes by sms')
        self.assertEqual( event.reminders[1], '10 minutes by alert')


    def test_is_match(self):
        event_entry = gdata.calendar.CalendarEventEntryFromString(xml_sample_event)
        event = Event(entry=event_entry);
        # match what
        self.assertEqual( event.is_match('sample event'), True)
        # match description
        self.assertEqual( event.is_match('blue folder'), True)
        # no match
        self.assertEqual( event.is_match('xxxxxx'), False)
        # case insensitive
        self.assertEqual( event.is_match('SAMPLE Event'), True)


def suite():
    suite = unittest.TestSuite()
    suite.addTest(Test_Event('test__init__'))
    suite.addTest(Test_Event('test_is_match'))
    return suite

if __name__ == '__main__':
    unittest.TextTestRunner(verbosity=2).run(suite())

