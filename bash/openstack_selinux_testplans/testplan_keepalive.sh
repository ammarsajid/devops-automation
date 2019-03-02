#!/bin/bash

# The purpose of this test is to prove that the keepalived process is protected by SELinux
# policies.
# This purpose is acheived by proving that keepalived process, running in its own SELinux domain,
# can execute a file (script) even if the file is executable by DAC policy rules.
 
# keepalived executable/binary files are assigned different SELinux labels:
ls -Z /sbin/ |grep keepalived
#
#   -rwxr-xr-x. root root     unconfined_u:object_r:keepalived_exec_t:s0 keepalived
#
# The binary file keepalived is labelled with keepalive_exec_t SELinux type which when executed
# spawns a process in keepalive_t SELinux domain.

# In this test plan, we are going to test all of the SELinux labels related to keepalived service.
# To let keepalived process do what we want, we have to originate our own processes with SELinux
# labels keepalived_t. In order to spawn keepalived process in its  respective SELinux domain we
# need an executable file with SELinux type keepalived_exec_t. Using this executable file, we can
# try some malicious activities like executing another harmful script placed in the system.

# Create two files 'keepalived_test.sh' and 'random_script.sh' in a directory inside root.
# keepalived_test.sh file will be used to spawn processes with any desired SELinux label and 
# random_script.sh file is a random bash script that will be accessed by the processe originated
# from keepalived_test.sh file. The bash script 'random_script.sh' can be any linux bash script.
touch keepalived_test.sh
touch random_script.sh

# Make sure SELinux context of both files is system_u:object_r:admin_home_t:s0
ls -Z
# The expected output of this command is a list of file with SELinux context, as below
#	-rwxr-xr-x. root root unconfined_u:object_r:admin_home_t:s0 random_script.sh
#	-rwxr-xr-x. root root unconfined_u:object_r:admin_home_t:s0 keepalived_test.sh

# Write some harmful bash commands in random_script.sh file.
cat > random_script.sh << _EOF
#!/bin/sh
id -Z
setenforce 0
echo SELinux status is set to: \$(getenforce)
setenforce 1
echo SELinux status is set to: \$(getenforce)
_EOF

# In file keepalived_test.sh file, run the random_script.sh script.
cat > keepalived_test.sh << _EOF
#!/bin/sh
./random_script.sh
_EOF

# Make sure both files are executable by DAC rules
chmod +x random_script.sh
chmod +x keepalived_test.sh
# These commands will change the mode of keepalived_test.sh and random_script.sh file to executable

# Run keepalived_test.sh and see if it displays the below output
#	unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Execute the script using 'runcon' with system_u:system_r:initrc_t:s0 SELinux context because this
# command will execute the script in initrc_t domain. And initrc_t domain is allowed to transition
# to any other domain
runcon system_u:system_r:initrc_t:s0 sh -c ./keepalived_test.sh | cat
# This command is just a test of environment that everything is working fine because this command
# is supposed to work without any issue.
# When command is executed successfully, you will see the following output,
#	system_u:system_r:initrc_t:s0
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Current SELinux context of keepalived_test.sh is unconfined_u:object_r:admin_home_t:s0, we need
# to change this context to one of keepalived binary context to see if keepalived process is
# protected or not.

#****************************************Keepalived test******************************************
# First test:
# Now change the context of keepalived_test.sh file to unconfined_u:object_r:keepalived_exec_t:s0,
# same as that of keepalived binary file, so that it can spawn a process in keepalived_t SELinux
# domain.
chcon -t keepalived_exec_t keepalived_test.sh
# Make sure this command works fine without any error.

# Since keepalived_test.sh is of keepalived_exec_t SELinux type which when executed will originates
# a process with keepalived_t SELinux domain. This command make sure that keepalived_test.sh is
# executed in the specified context. The bash file keepalived_test.sh is executed in initrc_t
# domain because initrc_t domain can transition to any other domain. So this execution will
# originates a process with keepalived_t domain.
runcon system_u:system_r:initrc_t:s0 sh -c ./keepalived_test.sh | cat
# The command is expected to fail and failure  will be logged in that file /var/log/audit/audit.log
# Look for an entry of following type
#
#	type=AVC msg=audit(1466459928.039:665650): avc:  denied  { execute } for  pid=13668 comm=
#	"keepalived_test.sh" name="random_script.sh" dev="sda2" ino=7566524546 scontext=
#	system_u:system_r:keepalived_t:s0 tcontext=unconfined_u:object_r:admin_home_t:s0 tclass=file
#
# This log entry shows that comm="keepalived_test.sh" is denied to execute file
# name="random_script.sh". The source context, which is actually the context of the process,
# "scontext=system_u:system_r:keepalived_t:s0" is denied to access target context
# "tcontext=unconfined_u:object_r:admin_home_t:s0" for "execute" permission.
# So what happened is, when we execute keepalived_test.sh with SELinux type keepalived_exec_t, it
# generates a process with context "system_u:system_r:keepalived_t:s0". As we scripted this
# process to execute a bash script "random_script.sh" which has the context 
# "unconfined_u:object_r:admin_home_t:s0". Since keepalived_t process is not allowed to execute
# this script by the SELinux policy so it fails with this log error.

# Second test:
# A process with SELinux domain keepalived_t can execute file with SELinux type 
# keepalived_exec_t because the binary file in /sbin/keepalived directory is label with
# type keepalived_exec_t. In order to prove that process running in keepalived_t domain
# can execute the keepalived_exec_t type files, change the SELinux type of random_script.sh
# script to keepalived_exec_t and then run the keepalived_test.sh script again.
chcon -t keepalived_exec_t random_script.sh
runcon system_u:system_r:initrc_t:s0 sh -c ./keepalived_test.sh | cat
# When command is executed successfully, you see the following output
#	system_u:system_r:keepalived_t:s0
#	SELinux status is set to:
#	SELinux status is set to:
# Now keepalived process is able to execute the bash script of keepalived_exec_t type
# but still it is not able to change SELinux mode because the process is running in 
# keepalived_t domain which don't have permission to change SELinux status.

# Restore the context before you go for the next test.
# Reset the context of keepalived_test.sh and random_script.sh file to orignal state that was 
# unconfined_u:object_r:admin_home_t:s0. Use commands below to reset context,
restorecon keepalived_test.sh
restorecon random_script.sh
# Make sure these commands executed successfully, the expected output for both commands is;
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534213].
#	Full path required for exclude: net:[4026534213].
