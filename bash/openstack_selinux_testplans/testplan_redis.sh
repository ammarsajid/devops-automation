#!/bin/bash

# The purpose of this test is to prove that redis processes are protected by SELinux policies.
# This purpose is achieved by proving that redis processes, running in their own SELinux domain,
# can not execute a file (script) even if the file is executable by DAC policy rules.

# redis executable/binary files are assigned different SELinux labels:
ls -Z /bin/ | grep redis
#
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   redis-benchmark
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   redis-check-aof
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   redis-check-dump
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   redis-cli
#	lrwxrwxrwx. root root   unconfined_u:object_r:bin_t:s0   redis-sentinel -> redis-server
#	-rwxr-xr-x. root root   unconfined_u:object_r:redis_exec_t:s0 redis-server
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   redis-shutdown
#
# The binary file 'redis-server' is assigned redis_exec_t SELinux type that mean, all the
# processes spawned by the binary file would be in the same domain i.e redis_t.
# Other files are labelled with ordinary bin_t SELinux type.

# In this test plan, we are going to test redis-server components of redis. To let redis processes
# do what we want, we have to originate our own processes with SELinux labels redis_t. In order to
# spawn redis processes in their SELinux domain, we need an executable file with redis_exec_t
# SELinux type. Using this executable file, we can try some malicious activities like executing
# another harmful script placed in the system.

# Create two files 'redis_test.sh' and 'random_script.sh' in a directory inside root.
# redis_test.sh file will be used to spawn processes with any desired SELinux label and 
# random_script.sh file is a random bash script that will be accessed by the processes originated
# from redis_test.sh file. The bash script 'random_script.sh' can be any linux bash script.
touch redis_test.sh
touch random_script.sh

# Make sure SELinux context of both files is system_u:object_r:admin_home_t:s0
ls -Z
# The expected output of this command is a list of files with SELinux context, as below
#	-rwxr-xr-x. root root unconfined_u:object_r:admin_home_t:s0 redis_test.sh
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

# In file redis_test.sh file, run the random_script.sh script.
cat > redis_test.sh << _EOF
#!/bin/sh
./random_script.sh
_EOF

# Make sure both files are executable by DAC rules
chmod +x random_script.sh
chmod +x redis_test.sh
# These commands will change the mode of redis_test.sh and random_script.sh file to executable.

# Run redis_test.sh and see if it displays the below output
#	unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Execute the script using 'runcon' with system_u:system_r:initrc_t:s0 SELinux context because this
# command will execute the script in initrc_t domain. And initrc_t domain is allowed to transition
# to any other domain.
runcon system_u:system_r:initrc_t:s0 sh -c ./redis_test.sh | cat
# This command is just a test of environment that everything is working fine because this command
# is supposed to work without any issue.
# When command is executed successfully, you will see the following output,
#	system_u:system_r:initrc_t:s0
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Current SELinux context of redis_test.sh is unconfined_u:object_r:admin_home_t:s0, we need to
# change this context, to as that of redis-server binary context, to see if redis processes are
# protected or not.

#******************************************Actual test********************************************#
# First test:
# Change the context of redis_test.sh to unconfined_u:object_r:redis_exec_t:s0, same as that of
# redis-server, so that it can spawn a process in redis_t SELinux domain.
chcon -t redis_exec_t redis_test.sh
# Make sure this command works fine without any error.

# Since redis_test.sh is of redis_exec_t SELinux type which when executed will orignate a process
# with redis_t SELinux domain. This command makes sure that redis_test.sh is executed in the
# specified context. The bash file redis_test.sh is executed in initrc_t domain because initrc_t
# domain can transition to any other domain. So this execution will originate a process with
# redis_t domain.
runcon system_u:system_r:initrc_t:s0 sh -c ./redis_test.sh | cat
# The command is expected to fail and failure will be logged in the file /var/log/audit/audit.log
# Look for an entry of following type
#
#	type=AVC msg=audit(1466705266.057:950599): avc:  denied  { execute } for  pid=98718 comm=
#	"redis_test.sh" name="random_script.sh" dev="sda2" ino=8732541057 scontext=
#	system_u:system_r:redis_t:s0 tcontext=unconfined_u:object_r:admin_home_t:s0 tclass=file
#
# This log entry shows that comm="redis_test.sh" is denied to execute a file
# name="random_script.sh". The source context, which is actually the context of the process,
# "scontext=system_u:system_r:redis_t:s0" is denied to access target context
# "tcontext=unconfined_u:object_r:admin_home_t:s0" for "execute" permission.
# So what happened is, when we execute redis_test.sh with SELinux type redis_exec_t, it
# generates a process with context "system_u:system_r:redis_t:s0". As we scripted this process
# to execute a bash script "random_script.sh" which has the context.
# "unconfined_u:object_r:admin_home_t:s0". Since redis_t process is not allowed to execute this
# script by the SELinux policy so it fails with this log error.

# Second test:
# To demonstrate that a process with SELinux domain redis_t can execute a file with SELinux type
# redis_exec_t because the binary file in /sbin directory is labelled with type redis_exec_t. In
# order to prove that process running in redis_t domain can execute the redis_exec_t type files,
# change the SELinux type of random_script.sh script to redis_exec_t and then run the same
# redis_test.sh script again.
chcon -t redis_exec_t random_script.sh
runcon system_u:system_r:initrc_t:s0 sh -c ./redis_test.sh | cat
# The command is expected to fail and failure will be logged in the file /var/log/audit/audit.log
# Look for an entry of following type,
#
#	type=AVC msg=audit(1466923902.599:1202640): avc:  denied  { execute } for  pid=70052 comm=
#	"redis_test.sh" name="bash" dev="sda2" ino=10062380 scontext=system_u:system_r:redis_t:s0 
#	tcontext=unconfined_u:object_r:shell_exec_t:s0 tclass=file
#
# This log entry shows that redis_test is unable to access /bin/bash file. The source context 
# "scontext=system_u:system_r:redis_t:s0", the context of redis_test.sh is denied access to target
# context "tcontext=unconfined_u:object_r:shell_exec_t:s0" for execute permissions. This is a
# different behaviour, try changing the script and run again to understand this strange behaviour.

# Restore the context before you go for the next test.
# First reset the context of redis_test.sh and random_script.sh file to orignal state that was 
# unconfined_u:object_r:admin_home_t:s0. Use commands below to reset context,
restorecon redis_test.sh
restorecon random_script.sh
# Make sure these commands executed successfully, the expected output for both command is;
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534213].
#	Full path required for exclude: net:[4026534213].

# Change the content of redis_test.sh to execute a simple command like 'ls',
cat > redis_test.sh << _EOF
#!/bin/sh
ls
_EOF

# Now change the context of redis_test.sh to unconfined_u:object_r:redis_exec_t:s0, same as that
# of redis-server, so that it can spawn a process in redis_t SELinux domain.
chcon -t redis_exec_t redis_test.sh
# Make sure this command works fine without any error.

# Now run the script again,
runcon system_u:system_r:initrc_t:s0 sh -c ./redis_test.sh | cat
# This command is expected to fail and error is logged in file /var/log/audit/audit.log, look for
# the log entry below,
#
#	type=AVC msg=audit(1466925268.762:1204228): avc:  denied  { execute } for  pid=4685 comm=
#	"redis_test.sh" name="ls" dev="sda2" ino=10003479 scontext=system_u:system_r:redis_t:s0
#	tcontext=unconfined_u:object_r:bin_t:s0 tclass=file
#
# The log entry shows that the process with context "scontext=system_u:system_r:redis_t:s0" is
# denied to execute /bin/ls command (actually a binary file) of SELinux linux type bin_t.
# So a process with redis_t label can't even access general commands that lies in /bin directory
# that's why  it is failing to trigger a bash script. Because bash script looks for /bin/bash
# binary to start execution.

# Restore the context before you go for the next test.
# Reset the context of redis_test.sh file to orignal state that was 
# unconfined_u:object_r:admin_home_t:s0. Use commands below to reset context,
restorecon redis_test.sh
# Make sure these commands executed successfully, the expected output for both command is;
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534213].
#	Full path required for exclude: net:[4026534213].
