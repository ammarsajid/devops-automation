#/bin/bash

# The purpose of this test is to prove that a OpenStack cinder processes are protected by SELinux
# policies.
# This purpose is achieved by proving that cinder processes, running in their own SELinux domain,
# can't execute a file (script) even if the file is executable by DAC policy rules.
 
# Cinder executable/binary files are assigned different SELinux labels:
ls -Z /bin/ | grep cinder
#
#   -rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0                   cinder
#   -rwxr-xr-x. root root   unconfined_u:object_r:cinder_api_exec_t:s0       cinder-api
#   -rwxr-xr-x. root root   unconfined_u:object_r:cinder_backup_exec_t:s0    cinder-backup
#   -rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0                   cinder-manage
#   -rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0                   cinder-rootwrap
#   -rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0                   cinder-rtstool
#   -rwxr-xr-x. root root   unconfined_u:object_r:cinder_scheduler_exec_t:s0 cinder-scheduler
#   -rwxr-xr-x. root root   unconfined_u:object_r:cinder_volume_exec_t:s0    cinder-volume
#   -rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0                   cinder-volume-usage-audit
#
# The binary file cinder-api is labelled with cinder_api_exec_t SELinux type which when executed
# spawns a process in cinder_api_t SELinux domain.
# cinder-backup is labelled with cinder_backup_exec_t SELinux type which when executed triggers a
# process in cinder_backup_t SELinux domain.
# cinder-volume is labelled with cinder_volume_exec_t SELinux type, when executed spawns a process
# in cinder_volume_t SELinux domain.
# Similarly cinder-scheduler is labelled with cinder_scheduler_exec_t SELinux type and when
# executed spawns a process in cinder_scheduler_t SELinux domain.
# Whereas other files are assigned bin_t label.
# In this test plan, we are going to test all of these SELinux labels related to cinder service. To
# let cinder processes do what we want, we have to orignate our own processes with SELinux labels
# cinder_api_t, cinder_volume_t and cinder_scheduler_t. In order to spawn cinder processes in their
# respective SELinux domains we need executable files with cinder_api_exec_t, 
# cinder_scheduler_exec_t and cinder_volume_exec_t SELinux types respectively. Using these 
# executable files, we can try some malicious activities like executing another harmful script
# placed in the system.

# Create two files 'cinder_test.sh' and 'random_script.sh' in a directory inside root.
# cinder_test.sh file will be used to spawn processes with any desired SELinux label and 
# random_script.sh file is a random bash script that will be accessed by the processes orginated
# from cinder_test.sh file. The bash script 'random_script.sh' can be any linux bash script.
touch cinder_test.sh
touch random_script.sh

# Make sure SELinux context of both files is system_u:object_r:admin_home_t:s0
ls -Z
# The expected output of this command is a list of file with SELinux context, as below
#	-rwxr-xr-x. root root unconfined_u:object_r:admin_home_t:s0 random_script.sh
#	-rwxr-xr-x. root root unconfined_u:object_r:admin_home_t:s0 cinder_test.sh

# Write some harmful bash commands in random_script.sh file.
cat > random_script.sh << _EOF
#!/bin/sh
id -Z
setenforce 0
echo SELinux status is set to: \$(getenforce)
setenforce 1
echo SELinux status is set to: \$(getenforce)
_EOF

# In file cinder_test.sh file, run the random_script.sh script.
cat > cinder_test.sh << _EOF
#!/bin/sh
./random_script.sh
_EOF

# Make sure both files are executable by DAC rules
chmod +x random_script.sh
chmod +x cinder_test.sh
# These commands will change the mode of cinder_test.sh and random_script.sh file to executable.

# Run cinder_test.sh and see if it displays the below output
#	unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Execute the script using 'runcon' with system_u:system_r:initrc_t:s0 SELinux context because this
# command will execute the script in initrc_t domain. And initrc_t domain is allowed to transition
# to any other domain
runcon system_u:system_r:initrc_t:s0 sh -c ./cinder_test.sh | cat
# This command is just a test of environment that everything is working fine because this command
# is supposed to work without any issue.
# When command is executed successfully, you will see the following output,
#	system_u:system_r:initrc_t:s0
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Current SELinux context of cinder_test.sh is unconfined_u:object_r:admin_home_t:s0, we need to
# change this context to one of cinder binary context to see if cinder processes are protected or
# not.

#****************************************cinder-api test******************************************#
# First test:
# First change the context of cinder_test.sh to unconfined_u:object_r:cinder_api_exec_t:s0, same
# as that of cinder-api binary file, so that it can spawn a process in cineder_api_t SELinux domain
chcon -t cinder_api_exec_t cinder_test.sh
# Make sure this command works fine without any error.

# Since cinder_test.sh is of cinder_api_exec_t SELinux type which when executed will orignates a
# process with cinder_api_t SELinux domain. This command make sure that cinder_test.sh is executed
# in the specified context. The bash file cinder_test.sh is executed in initrc_t domain because
# initrc_t domain can transition to any other domain. So this execution will orignates a process
# with cinder_api_t domain.
runcon system_u:system_r:initrc_t:s0 sh -c ./cinder_test.sh | cat
# This command is expected to be executed properly without getting any AVC denial messages in 
# /var/log/audit/audit.log. Below is the expected output of this command,
#	system_u:system_r:cinder_api_t:s0
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing
# The reason behind its successful execution is that the process is running in unconfined domain.
# since cinder-api policies are not included in the installed version of openstack-linux package so
# cinder-api has to be running in unconfined domain to avoid any denials. As cinder-api process is
# running in unconfined domain so that mean, it is not protected by SELinux.
# To verify that cinder-api process is running in unconfined domain, use the command below;
# seinfo -aunconfined_domain_type -x | grep cinder_api_t
# but seinfo command is not part of any SELinux package already installed. A separate package
# setool is required to run this command that's why this command is not part of this test.

# Second test:
# A process with SELinux domain cinder_api_t can execute file with SELinux type cinder_api_exec_t
# because the binary file in /bin directory is labelled with type cinder_api_exec_t.
# In order to prove that process running in cinder_api_t domain can execute the cinder_api_exec_t
# type files, change the SELinux type of random_script.sh script to cinder_api_exec_t and then run
# the cinder_test.sh script again.
chcon -t cinder_api_exec_t random_script.sh
runcon system_u:system_r:initrc_t:s0 sh -c ./cinder_test.sh | cat
# When command is executed successfully, you see the following output
#	system_u:system_r:cinder_api_t:s0
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing
#
# cinder-api still can access and execute the script because the service is running is unconfined 
# domain.

# Restore the context before you go for the next test.
# Reset the context of cinder_test.sh and random_script.sh file to orignal state that was 
# unconfined_u:object_r:admin_home_t:s0. Use commands below to reset context,
restorecon cinder_test.sh
restorecon random_script.sh
# Make sure these commands executed successfully, the expected output for both command is;
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534213].
#	Full path required for exclude: net:[4026534213].

#************************************cinder-scheduler test****************************************#
# First test:
# For cinder-scheduler change the context of cinder_test.sh file to
# unconfined_u:object_r:cinder_scheduler_exec_t:s0, same as that of cinder-scheduler binary file,
# so that it can spawn a process in cinder_scheduler_t SELinux domain.
chcon -t cinder_scheduler_exec_t cinder_test.sh
# Make sure this command works fine without any error.

# Since cinder_test.sh is of cinder_scheduler_exec_t SELinux type which when executed will
# orignates a process with cinder_scheduler_t SELinux domain. This command make sure that
# cinder_test.sh is executed in the specified context. The bash file cinder_test.sh is executed in
# initrc_t domain because initrc_t domain can transition to any other domain. So this execution
# will orignates a process with cinder_scheduler_t domain.
runcon system_u:system_r:initrc_t:s0 sh -c ./cinder_test.sh | cat
# This command is expected to be executed properly without getting any AVC denial messages in 
# /var/log/audit/audit.log. Below is the expected output of this command,
#	system_u:system_r:cinder_scheduler_t:s0
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing
# The reason behind its successful execution is that the process is running in unconfined domain.
# since cinder-scheduler policies are not included in the installed version of openstack-linux
# package so cinder-scheduler has to be running in unconfined domain to avoid any denials. As
# cinder-scheduler process is running in unconfined domain so that mean, it is not protected by 
# SELinux.
# To verify that cinder-scheduler process is running in unconfined domain, use the command below;
# seinfo -aunconfined_domain_type -x | grep cinder_scheduler_t
# but seinfo command is not part of any SELinux package already installed. A separate package
# setool is required to run this command that's why this command is not part of this test.
 
# Second test:
# A process with SELinux domain cinder_scheduler_t can execute file with SELinux type 
# cinder_scheduler_exec_t because the binary file in /bin/cinder-scheduler directory is labelled
# with type cinder_scheduler_exec_t. In order to prove that process running in cinder_scheduler_t
# domain can execute the cinder_scheduler_exec_t type files, change the SELinux type of
# random_script.sh script to cinder_scheduler_exec_t and then run the cinder_test.sh script again.
chcon -t cinder_scheduler_exec_t random_script.sh
runcon system_u:system_r:initrc_t:s0 sh -c ./cinder_test.sh | cat
# When command is executed successfully, you see the following output
#	system_u:system_r:cinder_scheduler_t:s0
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing
#
# cinder-scheduler still can access and execute the script because the service is running in
# unconfined domain.

# Restore the context before you go for the next test.
# Reset the context of cinder_test.sh and random_script.sh file to orignal state that was 
# unconfined_u:object_r:admin_home_t:s0. Use commands below to reset context,
restorecon cinder_test.sh
restorecon random_script.sh
# Make sure these commands executed successfully, the expected output for both command is;
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534213].
#	Full path required for exclude: net:[4026534213].

#**************************************cinder-volume test*****************************************#
# First test:
# For cinder-volume change the context of cinder_test.sh to 
# unconfined_u:object_r:cinder_volume_exec_t:s0, same as that of cinder-volume binary file, so that
# it can spawn a process in cinder_volume_t SELinux domain.
chcon -t cinder_volume_exec_t cinder_test.sh
# Make sure this command works fine without any error.

# Since cinder_test.sh is of cinder_volume_exec_t SELinux type which when executed will orignates
# a process with cinder_volume_t SELinux domain. This command make sure that cinder_test.sh is
# executed in the specified context. The bash file cinder_test.sh is executed in initrc_t domain
# because initrc_t domain can transition to any other domain. So this execution will orignates a
# process with cinder_volume_t domain.
runcon system_u:system_r:initrc_t:s0 sh -c ./cinder_test.sh | cat
# This command is expected to be executed properly without getting any AVC denial messages in 
# /var/log/audit/audit.log. Below is the expected output of this command,
#	system_u:system_r:cinder_volume_t:s0
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing
# The reason behind its successful execution is that the process is running in unconfined domain.
# since cinder-volume policies are not included in the installed version of openstack-linux package
# so cinder-volume has to be running in unconfined domain to avoid any denials. As cinder-volume
# process is running in unconfined domain so that mean, it is not protected by SELinux.
# To verify that cinder-volume process is running in unconfined domain, use the command below;
# seinfo -aunconfined_domain_type -x | grep cinder_volume_t
# but seinfo command is not part of any SELinux package already installed. A separate package
# setool is required to run this command that's why this command is not part of this test.

# Second test:
# A process with SELinux domain cinder_volume_t can execute file with SELinux type
# cinder_volume_exec_t because the binary file in /bin/cinder-volume directory is labelled with
# type cinder_volume_exec_t. In order to prove that process running in cinder_volume_t domain
# can execute the cinder_volume_exec_t type files, change the SELinux type of random_script.sh
# script to cinder_volume_exec_t and then run the cinder_test.sh script again.
chcon -t cinder_volume_exec_t random_script.sh
runcon system_u:system_r:initrc_t:s0 sh -c ./cinder_test.sh | cat
# When command is executed successfully, you see the following output
#	system_u:system_r:cinder_volume_t:s0
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing
#
# cinder-volume still can access and execute the script because the service is running in unconfined 
# domain.

# Restore the context before you go for the next test.
# Reset the context of cinder_test.sh and random_script.sh file to orignal state that was 
# unconfined_u:object_r:admin_home_t:s0. Use commands below to reset context,
restorecon cinder_test.sh
restorecon random_script.sh
# Make sure these commands executed successfully, the expected output for both command is;
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534213].
#	Full path required for exclude: net:[4026534213].

#**************************************cinder-backup test*****************************************#
# First test:
# Now change the context of cinder_test.sh to unconfined_u:object_r:cinder_backup_exec_t:s0, same
# as that of cinder-backup binary file, so that it can spawn a process in cinder_backup_t SELinux
# domain
chcon -t cinder_backup_exec_t cinder_test.sh
# Make sure this command works fine without any error.

# Since cinder_test.sh is of cinder_backup_exec_t SELinux type which when executed will orignates a
# process with cinder_backup_t SELinux domain. This command make sure that cinder_test.sh is
# executed in the specified context. The bash file cinder_test.sh is executed in initrc_t domain
# because initrc_t domain can transition to any other domain. So this execution will orignates a
# process with cinder_backup_t domain.
runcon system_u:system_r:initrc_t:s0 sh -c ./cinder_test.sh | cat
# This command is expected to be executed properly without getting any AVC denial messages in 
# /var/log/audit/audit.log. Below is the expected output of this command,
#	system_u:system_r:cinder_backup_t:s0
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing
# The reason behind its successful execution is that the process is running in unconfined domain.
# since cinder-backup policies are not included in the installed version of openstack-linux package
# so cinder-backup has to be running in unconfined domain to avoid any denials. As cinder-backup
# process is running in unconfined domain so that mean, it is not protected by SELinux.
# To verify that cinder-backup process is running in unconfined domain, use the command below;
# seinfo -aunconfined_domain_type -x | grep cinder_backup_t
# but seinfo command is not part of any SELinux package already installed. A separate package
# setool is required to run this command that's why this command is not part of this test.

# Second test:
# A process with SELinux domain cinder_backup_t can execute file with SELinux type
# cinder_backup_exec_t because the binary file in /bin directory is labelled with type
# cinder_backup_exec_t. In order to prove that process running in cinder_backup_t domain
# can execute the cinder_backup_exec_t type files, change the SELinux type of random_script.sh
# script to cinder_backup_exec_t and then run the cinder_test.sh script again.
chcon -t cinder_backup_exec_t random_script.sh
runcon system_u:system_r:initrc_t:s0 sh -c ./cinder_test.sh | cat
# When command is executed successfully, you see the following output
#	system_u:system_r:cinder_backup_t:s0
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing
#
# cinder-backup still can access and execute the script because the service is running in
# unconfined domain.

# Restore the context before you go for the next test.
# Reset the context of cinder_test.sh and random_script.sh file to orignal state that was 
# unconfined_u:object_r:admin_home_t:s0. Use commands below to reset context,
restorecon cinder_test.sh
restorecon random_script.sh
# Make sure these commands executed successfully, the expected output for both command is;
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534213].
#	Full path required for exclude: net:[4026534213].
