#!/bin/bash

# The purpose of this test is to prove that a OpenStack swift processes are protected by SELinux
# policies.
# This purpose is achieved by proving that swift processes, running in their own SELinux domain,
# can not execute a file (script) even if the file is executable by DAC policy rules.
 
# swift executable/binary files are assigned different SELinux labels:
ls -Z /bin/ | grep swift
#
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   swift
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   swift-account-audit
#	-rwxr-xr-x. root root   unconfined_u:object_r:swift_exec_t:s0 swift-account-auditor
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   swift-account-info
#	-rwxr-xr-x. root root   unconfined_u:object_r:swift_exec_t:s0 swift-account-reaper
#	-rwxr-xr-x. root root   unconfined_u:object_r:swift_exec_t:s0 swift-account-replicator
#	-rwxr-xr-x. root root   unconfined_u:object_r:swift_exec_t:s0 swift-account-server
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   swift-config
#	-rwxr-xr-x. root root   unconfined_u:object_r:swift_exec_t:s0 swift-container-auditor
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   swift-container-info
#	-rwxr-xr-x. root root   unconfined_u:object_r:swift_exec_t:s0 swift-container-reconciler
#	-rwxr-xr-x. root root   unconfined_u:object_r:swift_exec_t:s0 swift-container-replicator
#	-rwxr-xr-x. root root   unconfined_u:object_r:swift_exec_t:s0 swift-container-server
#	-rwxr-xr-x. root root   unconfined_u:object_r:swift_exec_t:s0 swift-container-sync
#	-rwxr-xr-x. root root   unconfined_u:object_r:swift_exec_t:s0 swift-container-updater
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   swift-dispersion-populate
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   swift-dispersion-report
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   swift-drive-audit
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   swift-form-signature
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   swift-get-nodes
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   swift-init
#	-rwxr-xr-x. root root   unconfined_u:object_r:swift_exec_t:s0 swift-object-auditor
#	-rwxr-xr-x. root root   unconfined_u:object_r:swift_exec_t:s0 swift-object-expirer
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   swift-object-reconstructor
#	-rwxr-xr-x. root root   unconfined_u:object_r:swift_exec_t:s0 swift-object-replicator
#	-rwxr-xr-x. root root   unconfined_u:object_r:swift_exec_t:s0 swift-object-server
#	-rwxr-xr-x. root root   unconfined_u:object_r:swift_exec_t:s0 swift-object-updater
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   swift-oldies
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   swift-orphans
#	-rwxr-xr-x. root root   unconfined_u:object_r:swift_exec_t:s0 swift-proxy-server
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   swift-recon
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   swift-reconciler-enqueue
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   swift-recon-cron
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   swift-ring-builder
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   swift-ring-builder-analyzer
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   swift-temp-url
#
# We can see that swift_exec_t context is assigned to to the following components of swift
#	swift-account-auditor
#	swift-account-reaper
#	swift-account-replicator
#	swift-account-server
#	swift-container-auditor
#	swift-container-reconciler
#	swift-container-replicator
#	swift-container-server
#	swift-container-sync
#	swift-container-updater
#	swift-object-auditor
#	swift-object-expirer
#	swift-object-replicator
#	swift-object-server
#	swift-object-updater
#	swift-proxy-server

# In this test plan, we are going to test all of these components of swift using the same test
# because all of them would spawn their processes in the same domain.
# To let swift processes do what we want, we have to originate our own processes with SELinux label
# swift_exec_t. Using these executable files, we can try some malicious activities like executing
# another harmful script placed in the system.

# Create two files 'swift_test.sh' and 'random_script.sh' in a directory.
# swift_test.sh file will be used to spawn processes with any desired SELinux label and 
# random_script.sh file is a random bash script that will be accessed by the processes originated
# from swift_test.sh file. The bash script 'random_script.sh' can be any linux bash script.
touch swift_test.sh
touch random_script.sh

# Make sure SELinux context of both files is system_u:object_r:admin_home_t:s0
ls -Z
# The expected output of this command is a list of file with SELinux context, as below
#	-rwxr-xr-x. root root unconfined_u:object_r:admin_home_t:s0 random_script.sh
#	-rwxr-xr-x. root root unconfined_u:object_r:admin_home_t:s0 swift_test.sh

# Write some harmful bash commands in random_script.sh file.
cat > random_script.sh << _EOF
#!/bin/sh
id -Z 
setenforce 0
echo SELinux status is set to: \$(getenforce)
setenforce 1
echo SELinux status is set to: \$(getenforce)
_EOF

# In file swift_test.sh file, run the random_script.sh script.
cat > swift_test.sh << _EOF
#!/bin/sh
./random_script.sh
_EOF

# Make sure both files are executable by DAC rules
chmod +x random_script.sh
chmod +x swift_test.sh
# These commands will change the mode of swift_test.sh and random_script.sh file to executable.

# Run swift_test.sh and see if it displays the below output
#	unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Execute the script using 'runcon' with system_u:system_r:initrc_t:s0 SELinux context because this
# command will execute the script in initrc_t domain. And initrc_t domain is allowed to transition
# to any other domain
runcon system_u:system_r:initrc_t:s0 sh -c ./swift_test.sh | cat
# This command is just a test of environment that everything is working fine because this command
# is supposed to work without any issue.
# When command is executed successfully, you will see the following output,
#	system_u:system_r:initrc_t:s0
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Current SELinux context of swift_test.sh is unconfined_u:object_r:admin_home_t:s0, we need to
# change this context to one of swift binary context to see if swift processes are protected or
# not.

#******************************************Actual test********************************************#
# First test:
# Change the context of swift_test.sh to unconfined_u:object_r:swift_exec_t:s0, so that it can
# spawn a process in swift_t SELinux domain.
chcon -t swift_exec_t swift_test.sh
# Make sure this command works fine without any error.

# Since swift_test.sh is of swift_exec_t SELinux type which when executed will originates a process
# with swift_t SELinux domain. This command make sure that swift_test.sh is executed in the
# specified context. The bash file swift_test.sh is executed in initrc_t domain because initrc_t
# domain can transition to any other domain. So this execution will originates a process with
# swift_t domain.
runcon system_u:system_r:initrc_t:s0 sh -c ./swift_test.sh | cat
# The command is expected to fail and failure will be logged in that file /var/log/audit/audit.log
# Look for an entry of following type
#
#	type=AVC msg=audit(1466452577.462:657148): avc:  denied  { execute } for  pid=15582 comm=
#	"swift_test.sh" name="random_script.sh" dev="sda2" ino=7566524546 scontext=
#	system_u:system_r:swift_t:s0 tcontext=unconfined_u:object_r:admin_home_t:s0 tclass=file
#
# This log entry shows that comm="swift_test.sh" is denied to execute file name="random_script.sh".
# The source context, which is actually the context of the process, 
# "scontext=system_u:system_r:swift_t:s0" is denied to access target context
# "tcontext=unconfined_u:object_r:admin_home_t:s0" for "execute" permission
# So what happened is, when we execute swift_test.sh with SELinux type swift_exec_t, it
# generates a process with context "system_u:system_r:swift_t:s0". As we scripted this process
# to execute a bash script "random_script.sh" which has the context 
# "unconfined_u:object_r:admin_home_t:s0". Since swift_t process is not allowed to execute this
# script by the SELinux policy so it fails with this log error.

# Second test: 
# A process with SELinux domain swift_t can execute file with SELinux type swift_exec_t
# because the binary files in /bin directory are label with type swift_exec_t.
# In order to prove that process running in swift_t domain can execute the swift_exec_t
# type files, change the SELinux type of random_script.sh script to swift_exec_t and then run
# the swift_test.sh script again.
chcon -t swift_exec_t random_script.sh
runcon system_u:system_r:initrc_t:s0 sh -c ./swift_test.sh | cat
# When command is executed successfully, you see the following output
#	system_u:system_r:swift_t:s0
#	SELinux status is set to:
#	SELinux status is set to:
# Now swift processes are able to execute the bash script of swift_exec_t type but still it
# is not able to change SELinux mode because the process is running in swift_t domain which
# don't have permission to change SELinux status.

# Restore the context before you go for the next test.
# Reset the context of swift_test.sh and random_script.sh file to orignal state that was
# unconfined_u:object_r:admin_home_t:s0. Use commands below to reset context,
restorecon swift_test.sh
restorecon random_script.sh
# Make sure these commands executed successfully, the expected output for both command is;
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534213].
#	Full path required for exclude: net:[4026534213].