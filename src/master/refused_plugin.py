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

from twisted.internet import reactor
import plugin
import logging
import struct
import socket

logger = logging.getLogger(name='refused')

def store_connections(message, client):
	(basetime,) = struct.unpack('!Q', message[:8])
	message = message[8:]
	while message:
		(time, reason, family, loc_port, rem_port) = struct.unpack('!QcBHH', message[:14])
		addr_len = 4 if family == 4 else 16
		address = message[14:14 + addr_len]
		address = socket.inet_ntop(socket.AF_INET if family == 4 else socket.AF_INET6, address)
		message = message[14 + addr_len:]

class RefusedPlugin(plugin.Plugin):
	def __init__(self, plugins, config):
		self.__config = config

	def name(self):
		return 'Refused'

	def message_from_client(self, message, client):
		if message == 'C':
			logger.debug("Sending config %s to client %s", self.__config['version'], client)
			config = struct.pack('!IIIIQQ', self.__config['version'], self.__config['finished_limit'], self.__config['send_limit'], self.__config['undecided_limit'], self.__config['timeout'], self.__config['max_age'])
			self.send('C' + config, client)
		if message[0] == 'D':
			activity.log_activity(client, 'refused')
			reactor.callInThread(store_connections, message[1:], client)
		else:
			logger.error("Unknown message from client %s: %s", client, message)
