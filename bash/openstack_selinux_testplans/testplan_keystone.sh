#!/bin/bash

# The purpose of this test is to prove that a OpenStack keystone processes are protected by SELinux
# policies.
# This purpose is achieved by proving that keystone processes, running in their own SELinux domain,
# can not execute a file (script) even if the file is executable by DAC policy rules.

# keystone executable/binary files are assigned different SELinux labels:
ls -Z /bin/ | grep keystone
#
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   heat-keystone-setup
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   heat-keystone-setup-domain
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   keystone
#	-rwxr-xr-x. root root   unconfined_u:object_r:keystone_exec_t:s0 keystone-all
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   keystone-manage
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   keystone-wsgi-admin
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   keystone-wsgi-public
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   openstack-keystone-sample-data
# 
# keystone-all is the only binary which is assigned a specific context that is keystone_exec_t. All
# the processes spawned by this binary would be in keystone_t SELinux domain. Other components are
# labelled with ordinary bin_t SELinux type.

# In this test plan, we are going to test keystone components that are assigned specific context
# other than bin_t. The only one binary file 'keystone-all' is assigned with keystone_exec_t
# SELinux type. When this binary file is triggered, it would spawns a process in keystone_t domain.
# To let keystone process do what we want, we have to originate our own process with SELinux labels
# keystone_t. In order to spawn keystone process in its SELinux domain, we need an executable file
# with keystone_exec_t SELinux type. Using this executable file, we can try some malicious
# activities like executing another harmful script placed in the system.

# Create two files 'keystone_test.sh' and 'random_script.sh' in a directory inside root.
# keystone_test.sh file will be used to spawn processes with any desired SELinux label and 
# random_script.sh file is a random bash script that will be accessed by the processes originated
# from keystone_test.sh file. The bash script 'random_script.sh' can be any linux bash script.
touch keystone_test.sh
touch random_script.sh

# Make sure SELinux context of both files is system_u:object_r:admin_home_t:s0
ls -Z
# The expected output of this command is a list of files with SELinux context, as below
#	-rwxr-xr-x. root root unconfined_u:object_r:admin_home_t:s0 keystone_test.sh
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

# In file keystone_test.sh file, run the random_script.sh script.
cat > keystone_test.sh << _EOF
#!/bin/sh
./random_script.sh
_EOF

# Make sure both files are executable by DAC rules
chmod +x random_script.sh
chmod +x keystone_test.sh
# These commands will change the mode of keystone_test.sh and random_script.sh file to executable.

# Run keystone_test.sh and see if it displays the below output
#	unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Execute the script using 'runcon' with system_u:system_r:initrc_t:s0 SELinux context because this
# command will execute the script in initrc_t domain. And initrc_t domain is allowed to transition
# to any other domain
runcon system_u:system_r:initrc_t:s0 sh -c ./keystone_test.sh | cat
# This command is just a test of environment that everything is working fine because this command
# is supposed to work without any issue.
# When command is executed sucessfully, you will see the following output,
#	system_u:system_r:initrc_t:s0
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Current SELinux context of keystone_test.sh is unconfined_u:object_r:admin_home_t:s0, we need to
# change this context to one of keystone binary context to see if keystone processes are protected
# or not.

#******************************************Actual test********************************************#
# First test:
# Now change the context of keystone_test.sh to unconfined_u:object_r:keystone_exec_t:s0, same
# as that of keystone-all binary file, so that it can spawn a process in keystone_t SELinux domain.
chcon -t keystone_exec_t keystone_test.sh
# Make sure this command works fine without any error.

# Since keystone_test.sh is of keystone_exec_t SELinux type which when executed will originates a
# process with keystone_t SELinux domain. This command makes sure that keystone_test.sh is executed
# in the specified context. The bash file keystone_test.sh is executed in initrc_t domain because
# initrc_t domain can transition to any other domain. So this execution will originate a process
# with keystone_t domain.
runcon system_u:system_r:initrc_t:s0 sh -c ./keystone_test.sh | cat
# The command is expected to fail and failure  will be logged in the file /var/log/audit/audit.log
# Look for an entry of following type
#
#	type=AVC msg=audit(1466547622.304:767052): avc:  denied  { execute } for  pid=102470 comm=
#	"keystone_test.s" name="random_script.sh" dev="sda2" ino=7633633409 scontext=
#	system_u:system_r:keystone_t:s0 tcontext=unconfined_u:object_r:admin_home_t:s0 tclass=file
#
# This log entry shows that comm="keystone_test.sh" is denied to execute a file 
# name="random_script.sh". The source context, which is actually the context of the process,
# "scontext=system_u:system_r:keystone_t:s0" is denied to access target context
# "tcontext=unconfined_u:object_r:admin_home_t:s0" for "excute" permission.
#
# So what happened is, when we excute keystone_test.sh with SELinux type keystone_exec_t, it
# generates a process with context "system_u:system_r:keystone_t:s0". As we scripted this process
# to excute a bash script "random_script.sh" which has the context 
# "unconfined_u:object_r:admin_home_t:s0". Since keystone_t process is not allowed to execute this
# script by the SELinux policy so it fails with this log error.
 
# Second test:
# A process with SELinux domain keystone_t can execute a file with SELinux type keystone_exec_t
# because the binary file in /sbin directory is labelled with type keystone_exec_t. In order to
# prove that process running in keystone_t domain can execute the keystone_exec_t type files,
# change the SELinux type of random_script.sh script to keystone_exec_t and then run the same
# keystone_test.sh script again.
chcon -t keystone_exec_t random_script.sh
runcon system_u:system_r:initrc_t:s0 sh -c ./keystone_test.sh | cat
# When command is executed successfully, you see the following output
#	system_u:system_r:keystone_t:s0
#	SELinux status is set to: Enforcing
#	SELinux status is set to: Enforcing
# Also, look for a log entry in var/log/audit/audit.log of following type:
#	type=AVC msg=audit(1466798068.992:1057888): avc:  denied  { setenforce } for  pid=51303	comm=
#	"setenforce" scontext=system_u:system_r:keystone_t:s0 tcontext=system_u:object_r:security_t:s0
#	tclass=security
#
# Now keystone_t process is able to execute the bash script of keystone_exec_t type but still it
# is not able to change SELinux mode because the process is running in keystone_t domain which
# don't have permission to change SELinux status. But it can get access the current status of
# SELinux using getenforce command

# Restore the context before you go for the next test.
# Reset the context of keystone_test.sh and random_script.sh file to orignal state that was 
# unconfined_u:object_r:admin_home_t:s0. Use commands below to reset context,
restorecon keystone_test.sh
restorecon random_script.sh
# Make sure these commands executed successfully, the expected output for both command is;
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534213].
#	Full path required for exclude: net:[4026534213].
