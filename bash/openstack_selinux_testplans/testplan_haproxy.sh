#!/bin/bash

# The purpose of this test is to prove that HAProxy processes are protected by SELinux policies.
# This purpose is achieved by proving that HAProxy processes, running in their own SELinux domain,
# can not execute a file (script) even if the file is executable by DAC policy rules.
 
# HAProxy executable/binary files are assigned different SELinux labels:
ls -Z /sbin/ | grep haproxy
#
#	-rwxr-xr-x. root root     unconfined_u:object_r:haproxy_exec_t:s0 haproxy
#	-rwxr-xr-x. root root     unconfined_u:object_r:haproxy_exec_t:s0 haproxy-systemd-wrapper
#
# The above two files of HAProxy service are assigned haproxy_exec_t SELinux type that mean, all
# the processes spawned by these components would be in the same domain i.e haproxy_t;

# In this test plan, we are going to test all of these components of HAProxy using the same test
# because all of them would spawn their processes in the same domain.
# To let HAProxy processes do what we want, we have to originate our own processes with SELinux
# labels haproxy_t. In order to spawn HAProxy processes in their SELinux domain, we need an 
# executable file with haproxy_exec_t SELinux type. Using this executable file, we can try some
# malicious activities like executing another harmful script placed in the system.

# Create two files 'haproxy_test.sh' and 'random_script.sh' in a directory inside root.
# haproxy_test.sh file will be used to spawn processes with any desired SELinux label and 
# random_script.sh file is a random bash script that will be accessed by the processes originated
# from haproxy_test.sh file. The bash script 'random_script.sh' can be any linux bash script.
touch haproxy_test.sh
touch random_script.sh

# Make sure SELinux context of both files is system_u:object_r:admin_home_t:s0
ls -Z
# The expected output of this command is a list of files with SELinux context, as below
#	-rwxr-xr-x. root root unconfined_u:object_r:admin_home_t:s0 haproxy_test.sh
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

# In file haproxy_test.sh file, run the random_script.sh script.
cat > haproxy_test.sh << _EOF
#!/bin/sh
./random_script.sh
_EOF

# Make sure both files are executable by DAC rules
chmod +x random_script.sh
chmod +x haproxy_test.sh
# These commands will change the mode of haproxy_test.sh and random_script.sh file to executable.

# Run haproxy_test.sh and see if it displays the below output
#	unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Execute the script using 'runcon' with system_u:system_r:initrc_t:s0 SELinux context because this
# command will execute the script in initrc_t domain. And initrc_t domain is allowed to transition
# to any other domain
runcon system_u:system_r:initrc_t:s0 sh -c ./haproxy_test.sh | cat
# This command is just a test of environment that everything is working fine because this command
# is supposed to work without any issue.
# When command is executed successfully, you will see the following output,
#	system_u:system_r:initrc_t:s0
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Current SELinux context of haproxy_test.sh is unconfined_u:object_r:admin_home_t:s0, we need to
# change this context to one of HAProxy binary context to see if HAProxy processes are protected or
# not.

#******************************************Actual test********************************************#
# First test
# First change the context of haproxy_test.sh to unconfined_u:object_r:haproxy_exec_t:s0, same
# as that of HAProxy binary files, so that it can spawn a process in haproxy_t SELinux domain.
chcon -t haproxy_exec_t haproxy_test.sh
# Make sure this command works fine without any error.

# Since haproxy_test.sh is of haproxy_exec_t SELinux type which when executed will originate a
# process with haproxy_t SELinux domain. This command makes sure that haproxy_test.sh is executed
# in the specified context. The bash file haproxy_test.sh is executed in initrc_t domain because
# initrc_t domain can transition to any other domain. So this execution will originate a process
# with haproxy_t domain.
runcon system_u:system_r:initrc_t:s0 sh -c ./haproxy_test.sh | cat
# The command is expected to fail and failure will be logged in the file /var/log/audit/audit.log
# Look for an entry of following type
#
#	type=AVC msg=audit(1467751048.756:433168): avc:  denied  { execute } for  pid=37070 comm=
#	"haproxy_test.sh" name="random_script.sh" dev="sda2" ino=2726297793 scontext
#	=system_u:system_r:haproxy_t:s0 tcontext=unconfined_u:object_r:admin_home_t:s0 tclass=file
#
# This log entry shows that comm="haproxy_test.sh" is denied to execute a file name=
# "random_script.sh". The source context, which is actually the context of the process, 
# "scontext=system_u:system_r:haproxy_t:s0" is denied to access target context
# "tcontext=unconfined_u:object_r:admin_home_t:s0" for "execute" permission.
# So what happened is, when we execute haproxy_test.sh with SELinux type haproxy_exec_t, it
# generates a process with context "system_u:system_r:haproxy_t:s0". As we scripted this process
# to execute a bash script "random_script.sh" which has the context 
# "unconfined_u:object_r:admin_home_t:s0". Since haproxy_t process is not allowed to execute this
# script by the SELinux policy so it fails with this log error.
 
# Second test
# A process with SELinux domain haproxy_t can execute a file with SELinux type haproxy_exec_t
# because the binary files in /bin directory are labelled with type haproxy_exec_t.
# In order to prove that process running in haproxy_t domain can execute the haproxy_exec_t
# type files, change the SELinux type of random_script.sh script to haproxy_exec_t and then run
# the same haproxy_test.sh script again.
chcon -t haproxy_exec_t random_script.sh
runcon system_u:system_r:initrc_t:s0 sh -c ./haproxy_test.sh | cat
# The command is expected to fail and failure will be logged in the file /var/log/audit/audit.log
# Look for an entry of following type,
#
#	type=AVC msg=audit(1467751123.040:433255): avc:  denied  { execute } for  pid=41590 comm=
#	"haproxy_test.sh" name="bash" dev="sda2" ino=10062380 scontext=system_u:system_r:haproxy_t:s0
#	tcontext=unconfined_u:object_r:shell_exec_t:s0 tclass=file
#
# This log entry shows that haproxy_t is unable to access /bin/bash file. The source context 
# "scontext=system_u:system_r:haproxy_t:s0", the context of haproxy_test.sh is denied access to
# target context "tcontext=unconfined_u:object_r:shell_exec_t:s0" for execute permissions. This is
# a different behaviour, try changing the script and run again to understand this behaviour.

# Restore the context before you go for the next test.
# First reset the context of haproxy_test.sh and random_script.sh file to orignal state that was 
# unconfined_u:object_r:admin_home_t:s0. Use commands below to reset context,
restorecon haproxy_test.sh
restorecon random_script.sh
# Make sure these commands executed successfully, the expected output for both command is;
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534213].
#	Full path required for exclude: net:[4026534213].

# Change the content of haproxy_test.sh to execute a simple command like 'ls',
cat > haproxy_test.sh << _EOF
#!/bin/sh
ls
_EOF

# Now change the context of haproxy_test.sh to unconfined_u:object_r:haproxy_exec_t:s0, same as that
# of HAProxy components, so that it can spawn a process in haproxy_t SELinux domain.
chcon -t haproxy_exec_t haproxy_test.sh
# Make sure this command works fine without any error.

# Now run the script again,
runcon system_u:system_r:initrc_t:s0 sh -c ./haproxy_test.sh | cat
# This command is expected to fail and error is logged in file /var/log/audit/audit.log, look for
# the log entry below,
#
#	type=AVC msg=audit(1467751184.610:433328): avc:  denied  { execute } for  pid=45322 comm=
#	"haproxy_test.sh" name="ls" dev="sda2" ino=10003479 scontext=system_u:system_r:haproxy_t:s0
#	tcontext=unconfined_u:object_r:bin_t:s0 tclass=file
#
# The log entry shows that the process with context "scontext=system_u:system_r:haproxy_t:s0" is
# denied to execute /bin/ls command (actually a binary file) of SELinux linux type bin_t.
# So a process with haproxy_t label can't even access general commands that lies in /bin directory
# that's why  it is failing to trigger a bash script. Because bash script looks for /bin/bash
# binary to start execution.

# Reset the context of haproxy_test.sh file to orignal state that was 
# unconfined_u:object_r:admin_home_t:s0. Use commands below to reset context,
restorecon haproxy_test.sh
# Make sure these commands executed successfully, the expected output for both command is;
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534213].
#	Full path required for exclude: net:[4026534213].
