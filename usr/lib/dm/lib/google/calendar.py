#!/usr/bin/python

"""

Classes related to google contact api.

"""

from feedparser import _parse_date as parse_date
import gdata.calendar
import re
import time

P_ID = re.compile(r'^http://www.google.com/calendar/feeds/default/private/full/(.*)$')

class Event():
    """
    This class pseudo extends gdata.calendar.CalendarEventEntry. The entry
    property points to a CalendarEventEntry object.
    """
    def __init__(self, entry=None):
        self.entry = entry
        self.id = None
        self.set_id()
        self.what = self.entry.title.text
        self.when = None
        self.until = None
        self.set_when()
        self.where = None
        self.set_where()
        self.description = self.entry.content.text
        self.reminders=[]
        self.set_reminders()

    def format_time(self, timestamp):
        """
        Convert time from google format, eg '2010-01-03T10:00:00.000-05:00'
        to our format yyyy-mm-dd hh:mm:ss

        """
        datetime_fmt = '%Y-%m-%d %H:%M:%S'
        iso8601 = Iso8601(timestamp=timestamp)
        return time.strftime(datetime_fmt, time.localtime(iso8601.parse()))

    def is_match(self, keyword=None):
        if not keyword:
            return True
        match = False
        if self.what:
            if re.search(keyword, self.what, re.IGNORECASE):
                match = True
        if self.description:
            if re.search(keyword, self.description, re.IGNORECASE):
                match = True
        return match

    def set_id(self):
        if self.entry.id:
            match = P_ID.match(self.entry.id.text)
            if match:
                self.id = match.group(1)

    def set_reminders(self):
        if not self.entry.when:
            return
        if not len(self.entry.when) > 0:
            return
        if not hasattr(self.entry.when[0], 'reminder'):
            return
        if not len(self.entry.when[0].reminder) > 0:
            return
        for reminder in self.entry.when[0].reminder:
            method = reminder.method
            minutes = reminder.minutes
            self.reminders.append("%s minutes by %s" % (minutes, method))

    def set_when(self):
        if not self.entry.when:
            return
        if not len(self.entry.when) > 0:
            return
        self.when = self.format_time(self.entry.when[0].start_time)
        self.until = self.format_time(self.entry.when[0].end_time)

    def set_where(self):
        if self.entry.where:
            if len(self.entry.where) > 0:
                self.where = self.entry.where[0].value_string


class Iso8601():
    # Internal data and functions:

    __date_re = ("(?P<year>\d\d\d\d)"
                 "(?:(?P<dsep>-|)"
                    "(?:(?P<julian>\d\d\d)"
                      "|(?P<month>\d\d)(?:(?P=dsep)(?P<day>\d\d))?))?")
    __tzd_re = "(?P<tzd>[-+](?P<tzdhours>\d\d)(?::?(?P<tzdminutes>\d\d))|Z)"
    __tzd_rx = re.compile(__tzd_re)
    __time_re = ("(?P<hours>\d\d)(?P<tsep>:|)(?P<minutes>\d\d)"
                 "(?:(?P=tsep)(?P<seconds>\d\d(?:[.,]\d+)?))?"
                 + __tzd_re)

    __datetime_re = "%s(?:T%s)?" % (__date_re, __time_re)
    __datetime_rx = re.compile(__datetime_re)

    def __init__(self, timestamp=None):
        """
        The following code was extracted/adapted from _xmlplus/utils/iso8601.py.
        The header doc from that modules is:

            ISO-8601 date format support, sufficient for the profile defined in
            <http://www.w3.org/TR/NOTE-datetime>.

            The parser is more flexible on the input format than is required to support
            the W3C profile, but all accepted date/time values are legal ISO 8601 dates.
            The tostring() method only generates formatted dates that are conformant to
            the profile.

            This module was written by Fred L. Drake, Jr. <fdrake@acm.org>.

        This class represents an ISO-8601 formatted date/timestamp.

        Args
            timestamp - ISO-8601 date/time string
        """
        self.timestamp = timestamp
        return


    def parse(self):
        """Parse an ISO-8601 date/time string, returning the value in seconds
        since the epoch."""
        if not self.timestamp:
            return
        s = self.timestamp
        m = self.__datetime_rx.match(s)
        if m is None or m.group() != s:
            raise ValueError, "unknown or illegal ISO-8601 date format: " + `s`
        gmt = self.__extract_date(m) + self.__extract_time(m) + (0, 0, 0)
        return time.mktime(gmt) + self.__extract_tzd(m) - time.timezone


    def parse_timezone(self, timezone):
        """Parse an ISO-8601 time zone designator, returning the value in seconds
        relative to UTC."""
        m = __tzd_rx.match(timezone)
        if not m:
            raise ValueError, "unknown timezone specifier: " + `timezone`
        if m.group() != timezone:
            raise ValueError, "unknown timezone specifier: " + `timezone`
        return __extract_tzd(m)


    def tostring(self, t, timezone=0):
        """Format a time in ISO-8601 format.

        If `timezone' is specified, the time will be specified for that timezone,
        otherwise for UTC.

        Some effort is made to avoid adding text for the 'seconds' field, but
        seconds are supported to the hundredths.
        """
        if type(timezone) is type(''):
            timezone = self.parse_timezone(timezone)
        else:
            timezone = int(timezone)
        if timezone:
            sign = (timezone < 0) and "+" or "-"
            timezone = abs(timezone)
            hours = timezone / (60 * 60)
            minutes = (timezone % (60 * 60)) / 60
            tzspecifier = "%c%02d:%02d" % (sign, hours, minutes)
        else:
            tzspecifier = "Z"
        psecs = t - int(t)
        t = time.gmtime(int(t) - timezone)
        year, month, day, hours, minutes, seconds = t[:6]
        if seconds or psecs:
            if psecs:
                psecs = int(round(psecs * 100))
                f = "%4d-%02d-%02dT%02d:%02d:%02d.%02d%s"
                v = (year, month, day, hours, minutes, seconds, psecs, tzspecifier)
            else:
                f = "%4d-%02d-%02dT%02d:%02d:%02d%s"
                v = (year, month, day, hours, minutes, seconds, tzspecifier)
        else:
            f = "%4d-%02d-%02dT%02d:%02d%s"
            v = (year, month, day, hours, minutes, tzspecifier)
        return f % v


    def ctime(self, t):
        """Similar to time.ctime(), but using ISO-8601 format."""
        return self.tostring(t, time.timezone)



    def __extract_date(self, m):
        year = int(m.group("year"))
        julian = m.group("julian")
        if julian:
            return self.__find_julian(year, int(julian))
        month = m.group("month")
        day = 1
        if month is None:
            month = 1
        else:
            month = int(month)
            if not 1 <= month <= 12:
                raise ValueError, "illegal month number: " + m.group("month")
            else:
                day = m.group("day")
                if day:
                    day = int(day)
                    if not 1 <= day <= 31:
                        raise ValueError, "illegal day number: " + m.group("day")
                else:
                    day = 1
        return year, month, day


    def __extract_time(self, m):
        if not m:
            return 0, 0, 0
        hours = m.group("hours")
        if not hours:
            return 0, 0, 0
        hours = int(hours)
        if not 0 <= hours <= 23:
            raise ValueError, "illegal hour number: " + m.group("hours")
        minutes = int(m.group("minutes"))
        if not 0 <= minutes <= 59:
            raise ValueError, "illegal minutes number: " + m.group("minutes")
        seconds = m.group("seconds")
        if seconds:
            seconds = float(seconds)
            if not 0 <= seconds <= 60:
                raise ValueError, "illegal seconds number: " + m.group("seconds")
            # Python 2.3 requires seconds to be an integer
            seconds=int(seconds)
        else:
            seconds = 0
        return hours, minutes, seconds


    def __extract_tzd(self, m):
        """Return the Time Zone Designator as an offset in seconds from UTC."""
        if not m:
            return 0
        tzd = m.group("tzd")
        if not tzd:
            return 0
        if tzd == "Z":
            return 0
        hours = int(m.group("tzdhours"))
        minutes = m.group("tzdminutes")
        if minutes:
            minutes = int(minutes)
        else:
            minutes = 0
        offset = (hours*60 + minutes) * 60
        if tzd[0] == "+":
            return -offset
        return offset


    def __find_julian(self, year, julian):
        month = julian / 30 + 1
        day = julian % 30 + 1
        jday = None
        while jday != julian:
            t = time.mktime((year, month, day, 0, 0, 0, 0, 0, 0))
            jday = time.gmtime(t)[-2]
            diff = abs(jday - julian)
            if jday > julian:
                if diff < day:
                    day = day - diff
                else:
                    month = month - 1
                    day = 31
            elif jday < julian:
                if day + diff < 28:
                    day = day + diff
                else:
                    month = month + 1
        return year, month, day

