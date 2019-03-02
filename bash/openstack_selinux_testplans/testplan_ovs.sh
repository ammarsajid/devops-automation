#!/bin/bash

# The purpose of this test is to prove that OVS processes are protected by SELinux policies.
# This purpose is achieved by proving that OVS processes, running in their own SELinux domain,
# can not execute a file (script) even if the file is executable by DAC policy rules.
 
# OVS executable/binary files are assigned different SELinux labels:
ls -Z /bin/ | grep ovs
#
#	-rwxr-xr-x. root root   unconfined_u:object_r:openvswitch_exec_t:s0 ovs-appctl
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   ovsdb-client
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   ovsdb-tool
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   ovs-dpctl
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   ovs-dpctl-top
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   ovs-ofctl
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   ovs-pki
#	-rwxr-xr-x. root root   unconfined_u:object_r:openvswitch_exec_t:s0 ovs-vsctl
#
# The two binary files 'ovs-appctl' and 'ovs-vsctl' are assigned openvswitch_exec_t SELinux type
# that mean, all the
# processes spawned by these files would be in the same domain i.e openvswitch_t.
# Other files are labelled with ordinary bin_t SELinux type.

# In this test plan, we are going to test these two components of OVS using the same test because
# both of them would spawn their processes in the same domain.
# To let OVS processes do what we want, we have to originate our own processes with SELinux labels
# openvswitch_t. In order to spawn OVS processes in their SELinux domain, we need an executable
# file with openvswitch_exec_t SELinux type. Using this executable file, we can try some malicious
# activities like executing another harmful script placed in the system.

# Create two files 'ovs_test.sh' and 'random_script.sh' in a directory inside root.
# ovs_test.sh file will be used to spawn processes with any desired SELinux label and 
# random_script.sh file is a random bash script that will be accessed by the processes originated
# from ovs_test.sh file. The bash script 'random_script.sh' can be any linux bash script.
touch ovs_test.sh
touch random_script.sh

# Make sure SELinux context of both files is system_u:object_r:admin_home_t:s0
ls -Z
# The expected output of this command is a list of files with SELinux context, as below
#	-rwxr-xr-x. root root unconfined_u:object_r:admin_home_t:s0 ovs_test.sh
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

# In file ovs_test.sh file, run the random_script.sh script.
cat > ovs_test.sh << _EOF
#!/bin/sh
./random_script.sh
_EOF

# Make sure both files are executable by DAC rules
chmod +x random_script.sh
chmod +x ovs_test.sh
# These commands will change the mode of ovs_test.sh and random_script.sh file to executable.

# Run ovs_test.sh and see if it displays the below output
#	unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Execute the script using 'runcon' with system_u:system_r:initrc_t:s0 SELinux context because this
# command will execute the script in initrc_t domain. And initrc_t domain is allowed to transition
# to any other domain
runcon system_u:system_r:initrc_t:s0 sh -c ./ovs_test.sh | cat
# This command is just a test of environment that everything is working fine because this command
# is supposed to work without any issue.
# When command is executed successfully, you will see the following output,
#	system_u:system_r:initrc_t:s0
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Current SELinux context of ovs_test.sh is unconfined_u:object_r:admin_home_t:s0, we need to
# change this context to one of OVS binary context to see if OVS processes are protected or not.

#******************************************Actual test********************************************#
# First test:
# First change the context of ovs_test.sh to unconfined_u:object_r:openvswitch_exec_t:s0, same as
# that of OVS binary files, so that it can spawn a process in openvswitch_t SELinux domain.
chcon -t openvswitch_exec_t ovs_test.sh
# Make sure this command works fine without any error.

# Since ovs_test.sh is of openvswitch_exec_t SELinux type which when executed will orignate a
# process with openvswitch_t SELinux domain. This command makes sure that ovs_test.sh is executed
# in the specified context. The bash file ovs_test.sh is executed in initrc_t domain because
# initrc_t domain can transition to any other domain. So this execution will originate a process
# with openvswitch_t domain.
runcon system_u:system_r:initrc_t:s0 sh -c ./ovs_test.sh | cat
# The command is expected to fail and failure  will be logged in the file /var/log/audit/audit.log
# Look for an entry of following type
#
#	type=AVC msg=audit(1466540597.026:758956): avc:  denied  { execute } for  pid=123728 comm=
#	"ovs_test.sh" name="random_script.sh" dev="sda2" ino=7625244801 scontext=
#	system_u:system_r:openvswitch_t:s0 tcontext=unconfined_u:object_r:admin_home_t:s0 tclass=file
#
# This log entry shows that comm="ovs_test.sh" is denied to execute a file name="random_script.sh"
# The source context, which is actually the context of the process, 
# "scontext=system_u:system_r:openvswitch_t:s0" is denied to access target context
# "tcontext=unconfined_u:object_r:admin_home_t:s0" for "execute" permission.
# So what happened is, when we execute ovs_test.sh with SELinux type openvswitch_exec_t, it
# generates a process with context "system_u:system_r:openvswitch_t:s0". As we scripted this
# process to execute a bash script "random_script.sh" which has the context.
# "unconfined_u:object_r:admin_home_t:s0". Since openvswitch_t process is not allowed to execute
# this script by the SELinux policy so it fails with this log error.

# Second test:
# A process with SELinux domain openvswitch_t can execute a file with SELinux type
# openvswitch_exec_t because the binary files in /bin directory are labelled with type
# openvswitch_exec_t.
# In order to prove that process running in openvswitch_t domain can execute the openvswitch_exec_t
# type files, change the SELinux type of random_script.sh script to openvswitch_exec_t and then run
# the same ovs_test.sh script again.
chcon -t openvswitch_exec_t random_script.sh
runcon system_u:system_r:initrc_t:s0 sh -c ./ovs_test.sh | cat
# When command is executed successfully, you see the following output
#	system_u:system_r:openvswitch_t:s0
#	SELinux status is set to:
#	SELinux status is set to:
# Now openvswitch_t processe is able to execute the bash script of openvswitch_exec_t type but
# still it is not able to change SELinux mode because the process is running in openvswitch_t
# domain which don't have permission to change SELinux status.

# Restore the context before you go for the next test.
# Reset the context of ovs_test.sh and random_script.sh file to orignal state that was 
# unconfined_u:object_r:admin_home_t:s0. Use commands below to reset context,
restorecon ovs_test.sh
restorecon random_script.sh
# Make sure these commands executed successfully, the expected output for both command is;
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534213].
#	Full path required for exclude: net:[4026534213].
