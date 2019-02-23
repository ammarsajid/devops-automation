def hot_generate_basic(template_description):
	
	output = []
	output.append("heat_template_version: 2015-04-30 \n")
	output.append("description: " + template_description + "\n")
	output.append("parameters: \n")
	output.append("resources: \n")
	try:
		file = open("main_template.yaml", 'w')
	except:
		print "main_template.yaml: can not open file"
		sys.exit()
	file.writelines(output)
	file.close()

def hot_generate_instance(resource_group):
	try:
		file = open("main_template.yaml", 'r')
	except:
		print "main_template.yaml: file not found"
		sys.exit()
	check = "not_found"
	output = []
	for line in file:
		if not "resources: " in line or check == "found":
			output.append(line)
		else:		
			output.append(line)
			output.append("  " + resource_group['resource_name'] + ":\n")
			output.append("    type: " + resource_group['type'] + "\n")
			output.append("    properties:" + "\n")
			output.append("      name: " + resource_group['properties']['name'] + "\n")
			output.append("      image: " + resource_group['properties']['image'] + "\n")
			output.append("      flavor: " + resource_group['properties']['flavor'] + "\n")
			output.append("      networks:" + "\n")
			for network in resource_group['properties']['networks']:
				nic = ''
				if network['port_flag'] == 'true':
					nic = 'port'
				else:
					nic = 'network'
				
				if network['resource_flag'] == 'false':
					output.append("        - " + nic + ": " + network['name'] + "\n")
				else:
					output.append("        - " + nic + ": { get_resource: " + network['name'] + " }\n")
			
			if network['port_flag'] == 'false':
				output.append("      security_groups:" + "\n")
				for security_group in resource_group['properties']['security_groups']:			
					if security_group['resource_flag'] == 'false':
						output.append("        - " + security_group['name'] + "\n")
					else:
						output.append("        -  { get_resource: " + security_group['name'] + " }\n")
			
			check = "found"
	file.close()
	try:
		file = open("main_template.yaml", 'w')
	except:
		print "main_template: file not found"
		sys.exit()
	file.writelines(output)
	file.close()
def hot_generate_network(resource_group):
	try:
		file = open("main_template.yaml", 'r')
	except:
		print "main_template.yaml: file not found"
		sys.exit()
	check = "not_found"
	output = []
	for line in file:
		if not "resources: " in line or check == "found":
			output.append(line)
		else:
			output.append(line)
			output.append("  " + resource_group['resource_name'] + ":\n")
			output.append("    type: " + resource_group['type'] + "\n")
			output.append("    properties:" + "\n")
			output.append("      name: " + resource_group['properties']['name'] + "\n")
			check = "found"
	file.close()
	try:
		file = open("main_template.yaml", 'w')
	except:
		print "main_template: file not found"
		sys.exit()
	file.writelines(output)
	file.close()
	
def hot_generate_subnet(resource_group):
	try:
		file = open("main_template.yaml", 'r')
	except:
		print "main_template.yaml: file not found"
		sys.exit()
	check = "not_found"
	output = []
	for line in file:
		if not "resources: " in line or check == "found":
			output.append(line)
		else:
			output.append(line)
			output.append("  " + resource_group['resource_name'] + ":\n")
			output.append("    type: " + "OS::Neutron::Subnet" + "\n")
			output.append("    properties:" + "\n")
			output.append("      name: " + resource_group['properties']['name'] + "\n")
			output.append("      network_id: " + "{ get_resource: " + resource_group['properties']['network_id'] + " }" + "\n")
			output.append("      cidr: " + resource_group['properties']['cidr'] + "\n")
			output.append("      enable_dhcp: " + resource_group['properties']['enable_dhcp'] + "\n")
			output.append("      gateway_ip: " + resource_group['properties']['gateway_ip'] + "\n")
			output.append("      allocation_pools:" + "\n")
			output.append("        - start: " + resource_group['properties']['allocation_pool_start'] + "\n")
			output.append("          end: " + resource_group['properties']['allocation_pool_end'] + "\n")
			check = "found"
	file.close()
	try:
		file = open("main_template.yaml", 'w')
	except:
		print "main_template: file not found"
		sys.exit()
	file.writelines(output)
	file.close()

def hot_generate_port(resource_group):
	try:
		file = open("main_template.yaml", 'r')
	except:
		print "main_template.yaml: file not found"
		sys.exit()
	check = "not_found"
	output = []
	for line in file:
		if not "resources: " in line or check == "found":
			output.append(line)
		else:		
			output.append(line)
			output.append("  " + resource_group['resource_name'] + ":\n")
			output.append("    type: " + resource_group['type'] + "\n")
			output.append("    properties:" + "\n")
			output.append("      name: " + resource_group['properties']['name'] + "\n")
			output.append("      network_id: { get_resource: " + resource_group['properties']['network_id'] + " }\n")
			output.append("      security_groups:" + "\n")
			for security_group in resource_group['properties']['security_groups']:			
				if security_group['resource_flag'] == 'false':
					output.append("        - " + security_group['name'] + "\n")
				else:
					output.append("        -  { get_resource: " + security_group['name'] + " }\n")

			check = "found"
	file.close()
	try:
		file = open("main_template.yaml", 'w')
	except:
		print "main_template: file not found"
		sys.exit()
	file.writelines(output)
	file.close()

def hot_generate_floatingip(resource_group):
	try:
		file = open("main_template.yaml", 'r')
	except:
		print "main_template.yaml: file not found"
		sys.exit()
	check = "not_found"
	output = []
	for line in file:
		if not "resources: " in line or check == "found":
			output.append(line)
		else:		
			output.append(line)
			output.append("  " + resource_group['resource_name'] + ":\n")
			output.append("    type: " + resource_group['type'] + "\n")
			output.append("    properties:" + "\n")
			output.append("      floating_network_id: " + resource_group['properties']['floating_network_id'] + "\n")
			output.append("      port_id: { get_resource: " + resource_group['properties']['port_id'] + " }\n")

			check = "found"
	file.close()
	try:
		file = open("main_template.yaml", 'w')
	except:
		print "main_template: file not found"
		sys.exit()
	file.writelines(output)
	file.close()
	
def hot_generate_router(resource_group):
	try:
		file = open("main_template.yaml", 'r')
	except:
		print "main_template.yaml: file not found"
		sys.exit()
	check = "not_found"
	output = []
	for line in file:
		if not "resources: " in line or check == "found":
			output.append(line)
		else:
			output.append(line)
			output.append("  " + resource_group['resource_name'] + ":\n")
			output.append("    type: " + resource_group['type'] + "\n")
			output.append("    properties:" + "\n")
			output.append("      name: " + resource_group['properties']['name'] + "\n")
			check = "found"
	file.close()
	try:
		file = open("main_template.yaml", 'w')
	except:
		print "main_template: file not found"
		sys.exit()
	file.writelines(output)
	file.close()
def hot_generate_routergateway(resource_group):
	try:
		file = open("main_template.yaml", 'r')
	except:
		print "main_template.yaml: file not found"
		sys.exit()
	check = "not_found"
	output = []
	for line in file:
		if not "resources: " in line or check == "found":
			output.append(line)
		else:
			output.append(line)
			output.append("  " + resource_group['resource_name'] + ":\n")
			output.append("    type: " + resource_group['type'] + "\n")
			output.append("    properties:" + "\n")
			output.append("      router_id: { get_resource: " + resource_group['properties']['router_id'] + " }\n")
			output.append("      network_id: " + resource_group['properties']['ext_network_id'] + "\n")
			check = "found"
	file.close()
	try:
		file = open("main_template.yaml", 'w')
	except:
		print "main_template: file not found"
		sys.exit()
	file.writelines(output)
	file.close()

def hot_generate_routerinterface(resource_group):
	try:
		file = open("main_template.yaml", 'r')
	except:
		print "main_template.yaml: file not found"
		sys.exit()
	check = "not_found"
	output = []
	for line in file:
		if not "resources: " in line or check == "found":
			output.append(line)
		else:
			output.append(line)
			output.append("  " + resource_group['resource_name'] + ":\n")
			output.append("    type: " + resource_group['type'] + "\n")
			output.append("    properties:" + "\n")
			output.append("      router_id: { get_resource: " + resource_group['properties']['router_id'] + " }\n")
			output.append("      subnet_id: { get_resource: " + resource_group['properties']['subnet_id'] + " }\n")
			check = "found"
	file.close()
	try:
		file = open("main_template.yaml", 'w')
	except:
		print "main_template: file not found"
		sys.exit()
	file.writelines(output)
	file.close()

def hot_generate_securitygroup(resource_group):
	try:
		file = open("main_template.yaml", 'r')
	except:
		print "main_template.yaml: file not found"
		sys.exit()
	check = "not_found"
	output = []
	for line in file:
		if not "resources: " in line or check == "found":
			output.append(line)
		else:
			output.append(line)
			output.append("  " + resource_group['resource_name'] + ":\n")
			output.append("    type: " + resource_group['type'] + "\n")
			output.append("    properties:" + "\n")
			output.append("      name: " + resource_group['properties']['name'] + "\n")
			output.append("      description: " + resource_group['properties']['description'] + "\n")
			output.append("      rules:\n")
			for rule in resource_group['properties']['rules']:
				if rule['direction'] != "None":
					output.append("        - direction: " + rule['direction'] + "\n")
				if rule['ethertype'] != "None":
					output.append("          ethertype: " + rule['ethertype'] + "\n")
				if rule['protocol'] != "None":
					output.append("          protocol: " + rule['protocol'] + "\n")
				if rule['port_range_min'] != "None":
					output.append("          port_range_min: " + rule['port_range_min'] + "\n")
				if rule['port_range_max'] != "None":
					output.append("          port_range_max: " + rule['port_range_max'] + "\n")
				if rule['remote_group_id'] != "None":
					output.append("          port_range_max: " + rule['port_range_max'] + "\n")
				if rule['remote_ip_prefix'] != "None":
					output.append("          port_range_max: " + rule['port_range_max'] + "\n")
			check = "found"
	file.close()
	try:
		file = open("main_template.yaml", 'w')
	except:
		print "main_template: file not found"
		sys.exit()
	file.writelines(output)
	file.close()