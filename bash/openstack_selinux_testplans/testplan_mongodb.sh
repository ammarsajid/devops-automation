#!/bin/bash

# The purpose of this test is to prove that a MongoDB processes is protected by SELinux policies.
# This purpose is acheived by proving that MongoDB processes, running in their own SELinux domain,
# can not execute a file (script) even if the file is executable by DAC policy rules.

# MongoDB executable/binary files are assigned different SELinux labels:
ls -Z /bin/ |grep mongo
#
#   -rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mongo
#   -rwxr-xr-x. root root   unconfined_u:object_r:mongod_exec_t:s0 mongod
#   -rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mongodump
#   -rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mongoexport
#   -rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mongofiles
#   -rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mongoimport
#   -rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mongooplog
#   -rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mongoperf
#   -rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mongorestore
#   -rwxr-xr-x. root root   unconfined_u:object_r:mongod_exec_t:s0 mongos
#   -rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mongosniff
#   -rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mongostat
#   -rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mongotop
#
# The binary files mongod and mongos are labelled with mongod_exec_t SELinux type which when
# executed spawns a process in mongod_t SELinux domain. Other components are labelled with
# ordinary bin_t SELinux type.
# In this test plan, we are going to these two components of MongoDB using the same test
# because all of them would spawn their processes in the same domain.
# To let MongoDB processes do what we want, we have to originate our own processes with an SELinux
# labels mongod_t. In order to spawn MongoDB processes in their SELinux domain, we need an 
# executable file with mongod_exec_t SELinux type. Using this executable file, we can try some
# malicious activities like executing another harmful script placed in the system.

# Create two files 'mongodb_test.sh' and 'random_script.sh' in a directory inside root.
# mongodb_test.sh file will be used to spawn processes with any desired SELinux label and 
# random_script.sh file is a random bash script that will be accessed by the processes originated
# from mongodb_test.sh file. The bash script 'random_script.sh' can be any linux bash script.
touch mongodb_test.sh
touch random_script.sh

# Make sure SELinux context of both files is system_u:object_r:admin_home_t:s0
ls -Z
#The expected output of this command is a list of files with SELinux context, as below
#       -rw-r--r--. root root unconfined_u:object_r:admin_home_t:s0 mongodb_test.sh
#       -rw-r--r--. root root unconfined_u:object_r:admin_home_t:s0 random_script.sh

# Write some harmful bash commands in random_script.sh file.
cat > random_script.sh << _EOF
#!/bin/sh
id -Z
setenforce 0
echo SELinux status is set to: \$(getenforce)
setenforce 1
echo SELinux status is set to: \$(getenforce)
_EOF

# In file mongodb_test.sh file, run the random_script.sh script.
cat > mongodb_test.sh << _EOF
#!/bin/sh
./random_script.sh
_EOF

# Make sure both files are executable by DAC rules
chmod +x random_script.sh
chmod +x mongodb_test.sh
# These commands will change the mode of mongodb_test.sh and random_script.sh file to executable.

# Run mongodb_test.sh and see if it displays the below output
#	unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Execute the script using 'runcon' with system_u:system_r:initrc_t:s0 SELinux context because this
# command will execute the script in initrc_t domain. And initrc_t domain is allowed to transition
# to any other domain
runcon system_u:system_r:initrc_t:s0 sh -c ./mongodb_test.sh | cat
# This command is just a test of environment that everything is working fine because this command
# is supposed to work without any issue.
# When command is executed successfully, you will see the following output,
#	system_u:system_r:initrc_t:s0
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Current SELinux context of mongodb_test.sh is unconfined_u:object_r:admin_home_t:s0, we need to
# change this context to one of MongoDB binary context to see if MongoDB processes are protected or
# not.

#******************************************Actual test********************************************#
# First test:
# First change the context of mongodb_test.sh to unconfined_u:object_r:mongod_exec_t:s0, same as
# that of mongodb binary files, so that it can spawn a process in mongod_t SELinux domain.
chcon -t mongod_exec_t mongodb_test.sh
# Make sure this command works fine without any error.

# Since mongodb_test.sh is of mongod_exec_t SELinux type which when executed will originate a
# process with mongod_t SELinux domain. This command makes sure that mongodb_test.sh is executed in
# the specified context. The bash file mongodb_test.sh is executed in initrc_t domain because
# initrc_t domain can transition to any other domain. So this execution will originate a process
# with mongod_t domain.
runcon system_u:system_r:initrc_t:s0 sh -c ./mongodb_test.sh | cat
# The command is expected to fail and failure  will be logged in the file /var/log/audit/audit.log
# Look for an entry of following type
#
#       type=AVC msg=audit(1467020511.173:1313928): avc:  denied  { getattr } for  pid=107342 comm=
#       "mongodb_test.sh" path="/root/Testing/random_script.sh" dev="sda2" ino=8984199298 scontext=
#       system_u:system_r:mongod_t:s0 tcontext=unconfined_u:object_r:admin_home_t:s0 tclass=file
#
# This log entry shows that comm="mongodb_test.sh" is denied to execute a file
# name="random_script.sh". The source context, which is actually the context of the process,
# "scontext=system_u:system_r:mongod_t:s0" is denied to access target context
# "tcontext=unconfined_u:object_r:admin_home_t:s0" for "execute" permission.
# So what happened is, when we execute mongodb_test.sh with SELinux type mongod_exec_t, it
# generates a process with context "system_u:system_r:mongod_t:s0". As we scripted this process to
# execute a bash script "random_script.sh" which has the context 
# "unconfined_u:object_r:admin_home_t:s0". Since mongod_t process is not allowed to execute this
# script by the SELinux policy so it fails with this log error.

# Second test:
# A process with SELinux domain mongod_t can execute a file with SELinux type mongod_exec_t because
# the binary files in /bin directory are labelled with type mongod_exec_t.
# In order to prove that process running in mongod_t domain can execute the mongod_exec_t type
# files, change the SELinux type of random_script.sh script to mongod_exec_t and then run the same
# mongodb_test.sh script again.
chcon -t mongod_exec_t random_script.sh
runcon system_u:system_r:initrc_t:s0 sh -c ./mongodb_test.sh | cat
# When command is executed successfully, you see the following output
#       system_u:system_r:mongod_t:s0
#       SELinux status is set to:
#       SELinux status is set to:
# Now mongod_t process is able to execute the bash script of mongod_exec_t type but still it is not
# able to change SELinux mode because the process is running in mongod_t domain which don't have
# permission to change SELinux status.

# Restore the context before you go for the next test.
# Reset the context of mongodb_test.sh and random_script.sh file to orignal state that was 
# unconfined_u:object_r:admin_home_t:s0. Use commands below to reset context,
restorecon mongodb_test.sh
restorecon random_script.sh
# Make sure these commands executed successfully, the expected output for both command is;
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534213].
#	Full path required for exclude: net:[4026534213].
