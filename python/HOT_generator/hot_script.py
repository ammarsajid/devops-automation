import os
import sys
import json
from func_defs import *

'''
try:
	file = open("configurations.json", 'r')
except:
	print "file not found"
	sys.exit()

configurations = json.load(file)
file.close()
'''


try:
	configurations = json.loads(sys.argv[1])
except:
	print "ERROR loading json data"
	sys.exit()

hot_generate_basic(configurations['description'])

for resource in configurations['resources']:
	if resource['type']=="OS::Nova::Server":
		hot_generate_instance(resource)
	elif resource['type']=="OS::Neutron::Net":
		hot_generate_network(resource)
	elif resource['type']=="OS::Neutron::Subnet":
		hot_generate_subnet(resource)
	elif resource['type']=="OS::Neutron::Port":
		hot_generate_port(resource)
	elif resource['type']=="OS::Neutron::FloatingIP":
		hot_generate_floatingip(resource)
	elif resource['type']=="OS::Neutron::Router":
		hot_generate_router(resource)
	elif resource['type']=="OS::Neutron::RouterGateway":
		hot_generate_routergateway(resource)
	elif resource['type']=="OS::Neutron::RouterInterface":
		hot_generate_routerinterface(resource)
	elif resource['type']=="OS::Neutron::SecurityGroup":
		hot_generate_securitygroup(resource)
	
