"""
Copyright (c) 2016, Are Hansen - Honeypot Development

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
__date__ = '2016, January 6'
__version__ = '0.0.1'


import geoip2.database
import os
import sys


class Geo(object):
    """This class the GeoLite2 database thats created by MaxMind.
    This database is free and can be downloaded from: 
    http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.mmdb.gz

    This module might end up being used in projects where not all of its users wish to
    utilize this feature and/or havent installed the GeoLite2 database yet. 
    The functions in this class will only return something if the GeoLite2 database is
    found. """

    def __init__(self, dbpath):
        """Requires absolute path to GeoLite2-City.mmdb. """
        self.dbpath = dbpath

    def country(self, ipv4):
        """Checks the ipv4 address against the geoip2 database. Returns the full country
        name of origin  if the IPv4 address is found in the database. Returns None if not
        found."""
        geloc = {}

        if os.path.exists(self.dbpath):
            reload(sys)
            sys.setdefaultencoding("utf-8")
            readipdb = geoip2.database.Reader(self.dbpath)
            try:
                response = readipdb.city(str(ipv4))
                geloc[ipv4] = { 
                            'CN': response.country.name
                            }
            except geoip2.errors.AddressNotFoundError, err:
                geloc[err] = {
                            'CN': err
                            }
            except ValueError, err:
                geloc[err] = {
                            'CN': err
                            }
            for geo, loc in geloc.items():
                return loc['CN']
