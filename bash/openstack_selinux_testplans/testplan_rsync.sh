#!/bin/bash

# The purpose of this test is to prove that rsync processes are protected by SELinux policies.
# This purpose is achieved by proving that rsync processes, running in their own SELinux domain,
# can not execute a file (script) even if the file is executable by DAC policy rules.
 
# rsync executable/binary files are assigned different SELinux labels:
ls -Z /bin/ | grep rsync
#
#	-rwxr-xr-x. root root   unconfined_u:object_r:rsync_exec_t:s0 rsync
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   wsrep_sst_rsync
#
# The binary file 'rsync' is assigned rsync_exec_t SELinux type that mean, all the
# processes spawned by the binary file would be in the same domain i.e rsync_t.
# Other files are labelled with ordinary bin_t SELinux type.

# In this test plan, we are going to test all of the SELinux labels related to rsync service.
# To let rsync processes do what we want, we have to originate our own processes with SELinux
# labels rsync_t. In order to spawn rsync processes in their SELinux domain, we need an 
# executable file with rsync_exec_t SELinux type. Using this executable file, we can try some
# malicious activities like executing another harmful script placed in the system.

# Create two files 'rsync_test.sh' and 'random_script.sh' in a directory.
# rsync_test.sh file will be used to spawn processes with any desired SELinux label and 
# random_script.sh file is a random bash script that will be accessed by the processes originated
# from rsync_test.sh file. The bash script 'random_script.sh' can be any linux bash script.
touch rsync_test.sh
touch random_script.sh

# Make sure SELinux context of both files is system_u:object_r:admin_home_t:s0
ls -Z
# The expected output of this command is a list of files with SELinux context, as below
#	-rwxr-xr-x. root root unconfined_u:object_r:admin_home_t:s0 rsync_test.sh
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

# In file rsync_test.sh file, run the random_script.sh script.
cat > rsync_test.sh << _EOF
#!/bin/sh
./random_script.sh
_EOF

# Make sure both files are executable by DAC rules
chmod +x random_script.sh
chmod +x rsync_test.sh
# These commands will change the mode of rsync_test.sh and random_script.sh file to executable.

# Run rsync_test.sh and see if it displays the below output
#	unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Execute the script using 'runcon' with system_u:system_r:initrc_t:s0 SELinux context because this
# command will execute the script in initrc_t domain. And initrc_t domain is allowed to transition
# to any other domain
runcon system_u:system_r:initrc_t:s0 sh -c ./rsync_test.sh | cat
# This command is just a test of environment that everything is working fine because this command
# is supposed to work without any issue.
# When command is executed sucessfully, you will see the following output,
#	system_u:system_r:initrc_t:s0
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Current SELinux context of rsync_test.sh is unconfined_u:object_r:admin_home_t:s0, we need to
# change this context, to as that of rsync binary context, to see if rsync processes are protected
# or not.

#******************************************Actual test********************************************#
# First test:
# Change the context of rsync_test.sh to unconfined_u:object_r:rsync_exec_t:s0, same  as that of
# rsync binary file, so that it can spawn a process in rsync_t SELinux domain.
chcon -t rsync_exec_t rsync_test.sh
# Make sure this command works fine without any error.

# Since rsync_test.sh is of rsync_exec_t SELinux type which when executed will orignate a process
# with rsync_t SELinux domain. This command makes sure that rsync_test.sh is executed in the
# specified context. The bash file rsync_test.sh is executed in initrc_t domain because initrc_t
# domain can transition to any other domain. So this execution will originate a process with
# rsync_t domain.
runcon system_u:system_r:initrc_t:s0 sh -c ./rsync_test.sh | cat
# This command executes successfully and shows the below output,
#	system_u:system_r:initrc_t:s0
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing
#
# This command is expected to fail and generate a log entry in selinux logs because if rsync
# service is protected then it should not be able to execute a malicious script. Also the context
# of process executing the random_script.sh is "system_u:system_r:initrc_t:s0" but it should be 
# "system_u:system_r:rsync_t_t:s0", even the SELinux type of rsync_test.sh file is rsync_exec_t.
# It looks like transitioning is not happening from initrc_t domain to rsync_t domain.

# Second test:
chcon -t rsync_exec_t random_script.sh
runcon system_u:system_r:initrc_t:s0 sh -c ./rsync_test.sh | cat
# This command executes successfully and shows the below output,
#	system_u:system_r:initrc_t:s0
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing
#
# This command is expected to execute but SELinux status should not be changed by random_script.sh
# because if rsync service is protected then it should not be able to change SELinux status. Also
# the context of process executing the random_script.sh is "system_u:system_r:initrc_t:s0" but it
# should be "system_u:system_r:rsync_t_t:s0", even the SELinux type of rsync_test.sh file is
# rsync_exec_t. It looks like transitioning is not happening from initrc_t domain to rsync_t domain

# Restore the context before you go for the next test.
# Reset the context of rsync_test.sh and random_script.sh file to orignal state that was 
# unconfined_u:object_r:admin_home_t:s0. Use commands below to reset context,
restorecon rsync_test.sh
restorecon random_script.sh
# Make sure these commands executed successfully, the expected output for both command is;
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534213].
#	Full path required for exclude: net:[4026534213].