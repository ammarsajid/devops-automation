#!/bin/bash

# The purpose of this test is to prove that OpenStack nova processes are protected by SELinux
# policies.
# This purpose is achieved by proving that nova processes, running in their own SELinux domain,
# can not execute a file (script) even if the file is executable by DAC policy rules.
 
# Nova executable/binary files are assigned different SELinux labels:
ls -Z /bin/ | grep nova
#
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   nova
#	-rwxr-xr-x. root root   unconfined_u:object_r:nova_exec_t:s0 nova-api
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   nova-api-ec2
#	-rwxr-xr-x. root root   unconfined_u:object_r:nova_exec_t:s0 nova-api-metadata
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   nova-api-os-compute
#	-rwxr-xr-x. root root   unconfined_u:object_r:nova_exec_t:s0 nova-cert
#	-rwxr-xr-x. root root   unconfined_u:object_r:virtd_exec_t:s0 nova-compute
#	-rwxr-xr-x. root root   unconfined_u:object_r:nova_exec_t:s0 nova-conductor
#	-rwxr-xr-x. root root   unconfined_u:object_r:nova_exec_t:s0 nova-console
#	-rwxr-xr-x. root root   unconfined_u:object_r:nova_exec_t:s0 nova-consoleauth
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   nova-idmapshift
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   nova-manage
#	-rwxr-xr-x. root root   unconfined_u:object_r:nova_exec_t:s0 nova-novncproxy
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   nova-rootwrap
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   nova-rootwrap-daemon
#	-rwxr-xr-x. root root   unconfined_u:object_r:nova_exec_t:s0 nova-scheduler
#	-rwxr-xr-x. root root   unconfined_u:object_r:nova_exec_t:s0 nova-xvpvncproxy
#
# The following components of nova are assigned nova_exec_t SELinux type that mean, all the
# processes spawned by these components would be in the same domain i.e nova_t;
#	nova-api
#	nova-api-metadata
#	nova-cert
#	nova-conductor
#	nova-console
#	nova-consoleauth
#	nova-novncproxy
#	nova-scheduler
#	nova-xvpvncproxy
# Other components are labelled with ordinary bin_t SELinux type.

# In this test plan, we are going to test all of these components of nova using the same test
# because all of them would spawn their processes in the same domain.
# To let nova processes do what we want, we have to originate our own processes with an SELinux
# labels nova_t. In order to spawn nova processes in their SELinux domain, we need an executable
# file with nova_exec_t SELinux type. Using this executable file, we can try some malicious
# activities like executing another harmful script placed in the system.

# Create two files 'nova_test.sh' and 'random_script.sh' in a directory.
# nova_test.sh file will be used to spawn processes with any desired SELinux label and 
# random_script.sh file is a random bash script that will be accessed by the processes originated
# from nova_test.sh file. The bash script 'random_script.sh' can be any linux bash script.
touch nova_test.sh
touch random_script.sh

# Make sure SELinux context of both files is system_u:object_r:admin_home_t:s0
ls -Z
# The expected output of this command is a list of files with SELinux context, as below
#	-rwxr-xr-x. root root unconfined_u:object_r:admin_home_t:s0 nova_test.sh
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

# In file nova_test.sh file, run the random_script.sh script.
cat > nova_test.sh << _EOF
#!/bin/sh
./random_script.sh
_EOF

# Make sure both files are executable by DAC rules
chmod +x random_script.sh
chmod +x nova_test.sh
# These commands will change the mode of nova_test.sh and random_script.sh file to executable.

# Run nova_test.sh and see if it displays the below output
#	unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Execute the script using 'runcon' with system_u:system_r:initrc_t:s0 SELinux context because this
# command will execute the script in initrc_t domain. And initrc_t domain is allowed to transition
# to any other domain
runcon system_u:system_r:initrc_t:s0 sh -c ./nova_test.sh | cat
# This command is just a test of environment that everything is working fine because this command
# is supposed to work without any issue.
# When command is executed successfully, you will see the following output,
#	system_u:system_r:initrc_t:s0
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Current SELinux context of nova_test.sh is unconfined_u:object_r:admin_home_t:s0, we need to
# change this context to one of nova binary context to see if nova processes are protected or not.

#******************************************Actual test********************************************#
# First test:
# First change the context of nova_test.sh to unconfined_u:object_r:nova_exec_t:s0, same as that of
# nova binary files, so that it can spawn a process in nova_t SELinux domain.
chcon -t nova_exec_t nova_test.sh
# Make sure this command works fine without any error.

# Since nova_test.sh is of nova_exec_t SELinux type which when executed will originate a process
# with nova_t SELinux domain. This command makes sure that nova_test.sh is executed in the
# specified context. The bash file nova_test.sh is executed in initrc_t domain because initrc_t
# domain can transition to any other domain. So this execution will originate a process with nova_t
# domain.
runcon system_u:system_r:initrc_t:s0 sh -c ./nova_test.sh | cat
# The command is expected to fail and failure  will be logged in the file /var/log/audit/audit.log
# Look for an entry of following type
#
#	type=AVC msg=audit(1466718638.988:966096): avc:  denied  { execute } for  pid=14282 comm=
#	"nova_test.sh" name="random_script.sh" dev="sda2" ino=7558135937 scontext=
#	system_u:system_r:nova_t:s0 tcontext=unconfined_u:object_r:admin_home_t:s0 tclass=file
#
# This log entry shows that comm="nova_test.sh" is denied to execute a file name="random_script.sh"
# The source context, which is actually the context of the process, 
# "scontext=system_u:system_r:nova_t:s0" is denied to access target context
# "tcontext=unconfined_u:object_r:admin_home_t:s0" for "execute" permission.
# So what happened is, when we execute nova_test.sh with SELinux type nova_exec_t, it generates a
# process with context "system_u:system_r:nova_t:s0". As we scripted this process to execute a bash
# script "random_script.sh" which has the context "unconfined_u:object_r:admin_home_t:s0". Since
# nova_t process is not allowed to execute this script by the SELinux policy so it fails with this
# log error.

# Second test: 
# A process with SELinux domain nova_t can execute a file with SELinux type nova_exec_t because the
# binary files in /bin directory are labelled with type nova_exec_t.
# In order to prove that process running in nova_t domain can execute the nova_exec_t type files,
# change the SELinux type of random_script.sh script to nova_exec_t and then run the same
# nova_test.sh script again.
chcon -t nova_exec_t random_script.sh
runcon system_u:system_r:initrc_t:s0 sh -c ./nova_test.sh | cat
# When command is executed successfully, you see the following output
#	system_u:system_r:nova_t:s0
#	SELinux status is set to:
#	SELinux status is set to:
# Now nova_t process is able to execute the bash script of nova_exec_t type but still it is not
# able to change SELinux mode because the process is running in nova_t domain which don't have
# permission to change SELinux status.

# Restore the context before you go for the next test.
# Reset the context of nova_test.sh and random_script.sh file to orignal state that was 
# unconfined_u:object_r:admin_home_t:s0. Use commands below to reset context,
restorecon nova_test.sh
restorecon random_script.sh
# Make sure these commands executed successfully, the expected output for both command is;
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534213].
#	Full path required for exclude: net:[4026534213].

#***************************************nova-compute test*****************************************#
# First test:
# For nova-compute change the context of nova_test.sh to unconfined_u:object_r:virtd_exec_t:s0,
# same as that of nova-compute binary file, so that it can spawn a process in nova_t SELinux domain
chcon -t virtd_exec_t nova_test.sh
# Make sure this command works fine without any error.

# Since nova_test.sh is of virtd_exec_t SELinux type which when executed will originate a process
# with nova_t SELinux domain. This command makes sure that nova_test.sh is executed in the
# specified context. The bash file nova_test.sh is executed in initrc_t domain because initrc_t
# domain can transition to any other domain. So this execution will originate a process with nova_t
# domain.
runcon system_u:system_r:initrc_t:s0 sh -c ./nova_test.sh | cat
# This command is expected to be executed properly without getting any AVC denial messages in 
# /var/log/audit/audit.log. Below is the expected output of this command,
#	system_u:system_r:virtd_t:s0-s0:c0.c1023
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing
# The reason behind its successful execution is that the process is running in unconfined domain.
# since nova-compute policies are not included in the installed version of openstack-linux package
# so it has to be running in unconfined domain to avoid any denials. As nova-compute process is
# running in unconfined domain so that mean, it is not protected by SELinux.
# To verify that nova-compute process is running in unconfined domain, use the command below;
# seinfo -aunconfined_domain_type -x | grep virtd_t
# but seinfo command is not part of any SELinux package already installed. A separate package
# setool is required to run this command that's why this command is not part of this test.

# Second test:
# A process with SELinux domain virtd_t can execute a file with SELinux type virtd_exec_t because
# the binary files in /bin directory are labelled with type virtd_exec_t.
# In order to prove that a process running in virtd_t domain can execute the virtd_exec_t type
# files, change the SELinux type of random_script.sh script to virtd_exec_t and then run the same
# nova_test.sh script again.
chcon -t virtd_exec_t random_script.sh
runcon system_u:system_r:initrc_t:s0 sh -c ./nova_test.sh | cat
# When command is executed successfully, you see the following output
#	system_u:system_r:virtd_t:s0-s0:c0.c1023
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing
#
# nova-compute still can access and execute the script because the service is running is
# unconfined domain.

# Restore the context before you go for the next test.
# Reset the context of nova_test.sh and random_script.sh file to orignal state that was 
# unconfined_u:object_r:admin_home_t:s0. Use commands below to reset context,
restorecon nova_test.sh
restorecon random_script.sh
# Make sure these commands executed successfully, the expected output for both command is;
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534213].
#	Full path required for exclude: net:[4026534213].
