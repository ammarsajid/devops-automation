import subprocess
import json

path_script='/root/ammar/hot_script.py'

file = open("/root/ammar/configurations.json")

json_data = json.load(file)
data_str=json.dumps(json_data)

pi = subprocess.Popen(['python', path_script, data_str])

