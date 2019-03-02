#!/bin/bash

# The purpose of this test is to prove that OpenStack neutron processes are protected by SELinux
# policies.
# This purpose is achieved by proving that neutron processes, running in their own SELinux domain,
# can not execute a file (script) even if the file is executable by DAC policy rules.
 
# Neutron executable/binary files are assigned different SELinux labels:
ls -Z /bin/ | grep neutron
#
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   neutron
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   neutron-bsn-agent
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   neutron-cisco-apic-host-agent
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   neutron-cisco-apic-service-agent
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   neutron-cisco-cfg-agent
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   neutron-db-manage
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   neutron-debug
#	-rwxr-xr-x. root root   unconfined_u:object_r:neutron_exec_t:s0 neutron-dhcp-agent
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   neutron-ipset-cleanup
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   neutron-keepalived-state-change
#	-rwxr-xr-x. root root   unconfined_u:object_r:neutron_exec_t:s0 neutron-l3-agent
#	-rwxr-xr-x. root root   unconfined_u:object_r:neutron_exec_t:s0 neutron-lbaas-agent
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   neutron-lbaasv2-agent
#	-rwxr-xr-x. root root   unconfined_u:object_r:neutron_exec_t:s0 neutron-metadata-agent
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   neutron-metering-agent
#	-rwxr-xr-x. root root   unconfined_u:object_r:neutron_exec_t:s0 neutron-netns-cleanup
#	-rwxr-xr-x. root root   unconfined_u:object_r:neutron_exec_t:s0 neutron-ns-metadata-proxy
#	-rwxr-xr-x. root root   unconfined_u:object_r:neutron_exec_t:s0 neutron-openvswitch-agent
#	-rwxr-xr-x. root root   unconfined_u:object_r:neutron_exec_t:s0 neutron-ovs-cleanup
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   neutron-pd-notify
#	-rwxr-xr-x. root root   unconfined_u:object_r:neutron_exec_t:s0 neutron-rootwrap
#	-rwxr-xr-x. root root   unconfined_u:object_r:neutron_exec_t:s0 neutron-rootwrap-daemon
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   neutron-rootwrap-xen-dom0
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   neutron-sanity-check
#	-rwxr-xr-x. root root   unconfined_u:object_r:neutron_exec_t:s0 neutron-server
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   neutron-usage-audit
#
# The following components of neutron are assigned neutron_exec_t SELinux type that mean, all the
# processes spawned by these components would be in the same domain i.e neutron_t;
#	neutron-dhcp-agent
#	neutron-l3-agent
#	neutron-lbaas-agent
#	neutron-metadata-agent
#	neutron-netns-cleanup
#	neutron-ns-metadata-proxy
#	neutron-openvswitch-agent
#	neutron-ovs-cleanup
#	neutron-rootwrap
#	neutron-rootwrap-daemon
#	neutron-server
# Other components are labelled with ordinary bin_t SELinux type.

# In this test plan, we are going to test all of these components of neutron using the same test
# because all of them would spawn their processes in the same domain.
# To let neutron processes do what we want, we have to originate our own processes with SELinux
# labels neutron_t. In order to spawn neutron processes in their SELinux domain, we need an 
# executable file with neutron_exec_t SELinux type. Using this executable file, we can try some
# malicious activities like executing another harmful script placed in the system.

# Create two files 'neutron_test.sh' and 'random_script.sh' in a directory inside root.
# neutron_test.sh file will be used to spawn processes with any desired SELinux label and 
# random_script.sh file is a random bash script that will be accessed by the processes originated
# from neutron_test.sh file. The bash script 'random_script.sh' can be any linux bash script.
touch neutron_test.sh
touch random_script.sh

# Make sure SELinux context of both files is system_u:object_r:admin_home_t:s0
ls -Z
# The expected output of this command is a list of files with SELinux context, as below
#	-rwxr-xr-x. root root unconfined_u:object_r:admin_home_t:s0 neutron_test.sh
#	-rwxr-xr-x. root root unconfined_u:object_r:admin_home_t:s0 random_script.sh

# Write some harmful bash commands in random_script.sh file.
cat > random_script.sh << _EOF
#!/bin/sh
id -Z
setenforce 0
echo SELinux status is set to: \$(getenforce)
setenforce 1
echo SELinux status is set to: \$(getenforce)
_EOF

# In file neutron_test.sh file, run the random_script.sh script.
cat > neutron_test.sh << _EOF
#!/bin/sh
./random_script.sh
_EOF

# Make sure both files are executable by DAC rules
chmod +x random_script.sh
chmod +x neutron_test.sh
# These commands will change the mode of neutron_test.sh and random_script.sh file to executable.

# Run neutron_test.sh and see if it displays the below output
#	unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Execute the script using 'runcon' with system_u:system_r:initrc_t:s0 SELinux context because this
# command will execute the script in initrc_t domain. And initrc_t domain is allowed to transition
# to any other domain
runcon system_u:system_r:initrc_t:s0 sh -c ./neutron_test.sh | cat
# This command is just a test of environment that everything is working fine because this command
# is supposed to work without any issue.
# When command is executed successfully, you will see the following output,
#	system_u:system_r:initrc_t:s0
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Current SELinux context of neutron_test.sh is unconfined_u:object_r:admin_home_t:s0, we need to
# change this context to one of neutron binary context to see if neutron processes are protected or
# not.

#******************************************Actual test********************************************#
# First test:
# First change the context of neutron_test.sh to unconfined_u:object_r:neutron_exec_t:s0, same
# as that of neutron binary files, so that it can spawn a process in neutron_t SELinux domain.
chcon -t neutron_exec_t neutron_test.sh
# Make sure this command works fine without any error.

# Since neutron_test.sh is of neutron_exec_t SELinux type which when executed will originate a
# process with neutron_t SELinux domain. This command makes sure that neutron_test.sh is executed
# in the specified context. The bash file neutron_test.sh is executed in initrc_t domain because
# initrc_t domain can transition to any other domain. So this execution will originate a process
# with neutron_t domain.
runcon system_u:system_r:initrc_t:s0 sh -c ./neutron_test.sh | cat
# The command is expected to fail and failure will be logged in the file /var/log/audit/audit.log
# Look for an entry of following type
#
#	type=AVC msg=audit(1466529014.838:745421): avc:  denied  { execute } for  pid=20933 comm=
#	"neutron_test.sh" name="random_script.sh" dev="sda2" ino=7600078978 scontext=
#	system_u:system_r:neutron_t:s0 tcontext=unconfined_u:object_r:admin_home_t:s0 tclass=file
#
# This log entry shows that comm="neutron_test.sh" is denied to execute a file name=
# "random_script.sh". The source context, which is actually the context of the process, 
# "scontext=system_u:system_r:neutron_t:s0" is denied to access target context
# "tcontext=unconfined_u:object_r:admin_home_t:s0" for "execute" permission.
# So what happened is, when we execute neutron_test.sh with SELinux type neutron_exec_t, it
# generates a process with context "system_u:system_r:neutron_t:s0". As we scripted this process
# to execute a bash script "random_script.sh" which has the context 
# "unconfined_u:object_r:admin_home_t:s0". Since neutron_t process is not allowed to execute this
# script by the SELinux policy so it fails with this log error.
 
# Second test:
# A process with SELinux domain neutron_t can execute a file with SELinux type neutron_exec_t
# because the binary files in /bin directory are labelled with type neutron_exec_t.
# In order to prove that process running in neutron_t domain can execute the neutron_exec_t
# type files, change the SELinux type of random_script.sh script to neutron_exec_t and then run
# the same neutron_test.sh script again.
chcon -t neutron_exec_t random_script.sh
runcon system_u:system_r:initrc_t:s0 sh -c ./neutron_test.sh | cat
# When command is executed successfully, you see the following output
#	system_u:system_r:neutron_t:s0
#	SELinux status is set to:
#	SELinux status is set to:
# Now neutron_t process is able to execute the bash script of neutron_exec_t type but still it
# is not able to change SELinux mode because the process is running in neutron_t domain which
# don't have permission to change SELinux status.

# Restore the context before you go for the next test.
# Reset the context of neutron_test.sh and random_script.sh file to orignal state that was 
# unconfined_u:object_r:admin_home_t:s0. Use commands below to reset context,
restorecon neutron_test.sh
restorecon random_script.sh
# Make sure these commands executed successfully, the expected output for both command is;
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534213].
#	Full path required for exclude: net:[4026534213].
