"""
Copyright (c) 2014, Are Hansen

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are
permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list
of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this
list of conditions and the following disclaimer in the documentation and/or other
materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND AN
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
"""


__author__ = 'Are Hansen'
__date__ = '2014, Jan 07'
__version__ = '0.0.5'


import glob
import os
import time
from datetime import datetime
from os import R_OK, W_OK


class Check(object):
    """Checks attributes of a file object. """

    def __init__(self):
        """
        self.now: Current time 
        self.fmt: Time format: YEAR-MM-DD hh:mm:ss.ms
        """
        self.now = datetime.now()
        self.fmt = '%Y-%m-%d %H:%M:%S.%f'

    def exists(self, fobj):
        """Checks if the file exists or not. """
        return os.path.isfile(fobj)

    def modage(self, fobj):
        """Calculates the time in minutes since a file object was modified to the persent 
        time. The result is returned as an int object. If the file object cant be found 
        it will return the raised exception in the form of a string. """
        if self.exists(fobj):
            try:
                modtime = datetime.strptime(str(datetime.fromtimestamp(os.path.getmtime(fobj))), self.fmt)
                nowtime = datetime.strptime(str(self.now), self.fmt)
                nixts_1 = time.mktime(modtime.timetuple())
                nixts_2 = time.mktime(nowtime.timetuple())
                return int(nixts_2 - nixts_1) / 60
            except IOError, err:
                return err
            except OSError, err:
                return err
        else:
            return 'FileNotFound: {0}'.format(fobj)


class Read(object):
    """Preform read operations on a file object. """

    def flines(self, fobj):
        """Returns the number of lines in a single file object. """
        lnum = []

        with open(fobj) as obj:
            for line in obj:
                lnum.append(line)

        return len(lnum)

    def flinesg(self, gpatt):
        """Returns the number of lines in any file matching the globbing pattern as a dict 
        where key=file name and value=number of lines. """
        lnum = []
        ldic = {}
        gpatt = glob.glob(gpatt)

        for fobj in gpatt:
            with open(fobj) as obj:
                for line in obj:
                    lnum.append(line)
            ldic[fobj] = len(lnum)
            lnum = []

        return ldic

    def rperm(self, fobj):
        """Checks if the executing user has read access to the file object. Returns True
        or False. """
        return os.access(fobj, R_OK)

    def fread(self, fobj):
        """If the user have read permissions to the file, reads the lines of the file 
        object and returns them as a list. If the user lacks read permissions, return
        AccessError as a list object instead.
        NOTE: This is not a memory friendly option. If you want to read the last n lines
        of a file (I.E. log file), use ftail instead. """
        if self.rperm(fobj):
            fdata = []
            with open(fobj) as obj:
                fdata = list(obj)
            return fdata
        else:
            return ['AccessError: You do not have any read access to {0}'.format(fobj)]

    def freadg(self, gpatt):
        """If the user have read permissions to the file, reads the lines of the file 
        object and returns them as a list. If the user lacks read permissions, return
        AccessError as a list object instead.
        NOTE: This is not a memory friendly option. If you want to read the last n lines
        of a file (I.E. log file), use ftail instead. """
        fdata = []
        gpatt = glob.glob(gpatt)

        for fobj in gpatt:
            with open(fobj) as obj:
                for line in obj:
                    fdata.append(line)
        return fdata

    def ftail(self, fobj, nline):
        """If the user have read permissions to the file, read the nlines of a file object 
        into a list and return it. If the user lacks read permissions, return AccessError 
        as a list object instead. """
        if self.rperm(fobj):
            fobj = file(fobj)
            total_lines_wanted = nline
            block_size = 1024
            fobj.seek(0, 2)
            block_end_byte = fobj.tell()
            lines_to_go = total_lines_wanted
            block_number = -1
            blocks = []

            while lines_to_go > 0 and block_end_byte > 0:
                if block_end_byte - block_size > 0:
                    fobj.seek(block_number*block_size, 2)
                    blocks.append(fobj.read(block_size))
                else:
                    fobj.seek(0, 0)
                    blocks.append(fobj.read(block_end_byte))

                lines_found = blocks[-1].count('\n')
                lines_to_go -= lines_found
                block_end_byte -= block_size
                block_number -= 1

            all_read_text = ''.join(reversed(blocks))
            return all_read_text.splitlines()[-total_lines_wanted:]
        else:
            return ['AccessError: You do not have any read access to {0}'.format(fobj)]


class Write(object):
    """Writes things to a file object in various ways. """

    def __init__(self):
        """self.now: Current time """
        self.now = datetime.now()

    def wline(self, fobj, fstr):
        """Writes a single string to a file object. The file object will be created if not
        already present, any existing file object with the same name will be over written
        by the new string. Returns 0 on success and what ever exception was raised on
        error. """
        with open(fobj, 'w') as obj:
            try:
                obj.write('{0}\n'.format(fstr))
                return 0
            except IOError, err:
                return err
            except OSError, err:
                return err

    def aline(self, fobj, fstr):
        """Appends a single string to a file object. Returns 0 on success and what ever 
        exception was raised on error. """
        with open(fobj, 'a') as obj:
            try:
                obj.write('{0}\n'.format(fstr))
                return 0
            except IOError, err:
                return err
            except OSError, err:
                return err

