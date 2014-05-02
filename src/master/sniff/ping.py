#
#    Ucollect - small utility for real-time analysis of network data
#    Copyright (C) 2014 CZ.NIC, z.s.p.o. (http://www.nic.cz/)
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License along
#    with this program; if not, write to the Free Software Foundation, Inc.,
#    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#

import struct

from task import Task

class PingTask(Task):
	def __init__(self, message):
		Task.__init__(self)
		self.__message = message

	def name(self):
		return 'Ping'

	def message(self, client):
		return self.__message

def encode_host(hostname, proto, count, size):
	return struct.pack('!cBHL' + str(len(hostname)) + 's', proto, count, size, len(hostname), hostname);

class Pinger:
	def __init__(self):
		pass

	def code(self):
		return 'P'

	def check_schedule(self):
		return [PingTask(struct.pack('!H', 2) + encode_host('turris.cz', '6', 2, 100) + encode_host('www.nic.cz', '4', 3, 64))]

