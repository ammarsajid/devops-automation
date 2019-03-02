#!/bin/bash

# The purpose of this test is to prove that MySQL processes are protected by SELinux
# policies.
# This purpose is achieved by proving that MySQL processes, running in their own SELinux domain,
# can not execute a file (script) even if the file is executable by DAC policy rules.

# MySQL executable/binary files are assigned different SELinux labels:
ls -Z /bin/ | grep -i mysql
#
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   msql2mysql
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mysql
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mysqlaccess
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mysqladmin
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mysqlbinlog
#	lrwxrwxrwx. root root   unconfined_u:object_r:bin_t:s0   mysqlbug -> /etc/alternatives/mysqlbug
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mysqlcheck
#	lrwxrwxrwx. root root   unconfined_u:object_r:bin_t:s0   mysql_config -> /etc/alternatives/mysql_config
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mysql_convert_table_format
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mysqld_multi
#	-rwxr-xr-x. root root   unconfined_u:object_r:mysqld_safe_exec_t:s0 mysqld_safe
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mysqldump
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mysqldumpslow
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mysql_find_rows
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mysql_fix_extensions
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mysqlhotcopy
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mysqlimport
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mysql_install_db
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mysql_plugin
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mysql_secure_installation
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mysql_setpermission
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mysqlshow
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mysqlslap
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mysqltest
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mysql_tzinfo_to_sql
#	-rwxr-xr-x. root root   unconfined_u:object_r:mysqld_exec_t:s0 mysql_upgrade
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mysql_waitpid
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   mysql_zap
#	-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   wsrep_sst_mysqldump
#
# The binary file mysqld_safe is labelled with mysqld_safe_exec_t SELinux type which when executed
# spawns a process in mysqld_safe_t SELinux domain. Similarly mysql_upgrade is labelled with
# mysqld_exec_t SELinux type and when executed spawns a process in mysqld_t SELinux domain. Whereas
# other files are assigned bin_t label.

# In this test plan, we are going to test all of these SELinux labels related to MySQL service.
# To let MySQL processes do what we want, we have to originate our own processes with SELinux
# labels mysqld_t and mysqld_safe. In order to spawn MySQL processes in their respective SELinux
# domains we need executable files with mysqld_exec_t, and mysqld_safe_exec_t SELinux types
# respectively. Using these executable files, we can try some malicious activities like executing
# another harmful script placed in the system.

# Create two files 'mysql_test.sh' and 'random_script.sh' in a directory.
# mysql_test.sh file will be used to spawn processes with any desired SELinux label and 
# random_script.sh file is a random bash script that will be accessed by the processes originated
# from mysql_test.sh file. The bash script 'random_script.sh' can be any linux bash script.
touch mysql_test.sh
touch random_script.sh

# Make sure SELinux context of both files is system_u:object_r:admin_home_t:s0
ls -Z
# The expected output of this command is a list of file with SELinux context, as below
#	-rwxr-xr-x. root root unconfined_u:object_r:admin_home_t:s0 random_script.sh
#	-rwxr-xr-x. root root unconfined_u:object_r:admin_home_t:s0 mysql_test.sh

# Write some harmful bash commands in random_script.sh file.
cat > random_script.sh << _EOF
#!/bin/sh
id -Z
setenforce 0
echo SELinux status is set to: \$(getenforce)
setenforce 1
echo SELinux status is set to: \$(getenforce)
_EOF

# In file mysql_test.sh file, run the random_script.sh script.
cat > mysql_test.sh << _EOF
#!/bin/sh
./random_script.sh
_EOF

# Make sure both files are executable by DAC rules
chmod +x random_script.sh
chmod +x mysql_test.sh
# These commands will change the mode of mysql_test.sh and random_script.sh file to executable.

# Run mysql_test.sh and see if it displays the below output
#	unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Execute the script using 'runcon' with system_u:system_r:initrc_t:s0 SELinux context because this
# command will execute the script in initrc_t domain. And initrc_t domain is allowed to transition
# to any other domain.
runcon system_u:system_r:initrc_t:s0 sh -c ./mysql_test.sh | cat
# This command is just a test of environment that everything is working fine because this command
# is supposed to work without any issue.
# When command is executed successfully, you will see the following output,
#	system_u:system_r:initrc_t:s0
#	SELinux status is set to: Permissive
#	SELinux status is set to: Enforcing

# Current SELinux context of mysql_test.sh is unconfined_u:object_r:admin_home_t:s0, we need to
# change this context to one of MySQL binary context to see if MySQL processes are protected or
# not.

#***************************************mysql_upgrade test****************************************#
# First test:
# First change the context of mysql_test.sh to unconfined_u:object_r:mysqld_exec_t:s0, same as that
# of mysql_upgrade binary file, so that it can spawn a process in mysqld_t SELinux domain.
chcon -t mysqld_exec_t mysql_test.sh
# Make sure this command works fine without any error.

# Since mysql_test.sh is of mysqld_exec_t SELinux type which when executed will originates a
# process with mysqld_t SELinux domain. This command make sure that mysql_test.sh is executed
# in the specified context. The bash file mysql_test.sh is executed in initrc_t domain because
# initrc_t domain can transition to any other domain. So this execution will originates a process
# with mysqld_t domain.
runcon system_u:system_r:initrc_t:s0 sh -c ./mysql_test.sh | cat
# The command is expected to fail and failure  will be logged in that file /var/log/audit/audit.log
# Look for an entry of following type
#
#	type=AVC msg=audit(1466697609.953:941783): avc:  denied  { execute } for  pid=82726 comm=
#	"mysql_test.sh" name="random_script.sh" dev="sda2" ino=8707375233 scontext=
#	system_u:system_r:mysqld_t:s0 tcontext=unconfined_u:object_r:admin_home_t:s0 tclass=file
#
# This log entry shows that comm="mysql_test.sh" is denied to execute file name="random_script.sh".
# The source context, which is actually the context of the process, 
# "scontext=system_u:system_r:mysqld_t:s0" is denied to access target context
# "tcontext=unconfined_u:object_r:admin_home_t:s0" for "execute" permission.
# So what happened is, when we execute mysql_test.sh with SELinux type mysqld_exec_t, it
# generates a process with context "system_u:system_r:mysqld_t:s0". As we scripted this process
# to execute a bash script "random_script.sh" which has the context 
# "unconfined_u:object_r:admin_home_t:s0". Since mysqld_t process is not allowed to execute this
# script by the SELinux policy so it fails with this log error.

# Second test:
# A process with SELinux domain mysqld_t can execute file with SELinux type mysqld_exec_t
# because the binary file in /bin directory is also labelled with type mysqld_exec_t.
# In order to prove that process running in mysqld_t domain can execute the mysqld_exec_t
# type files, change the SELinux type of random_script.sh script to mysqld_exec_t and then run
# the mysql_test.sh script again.
chcon -t mysqld_exec_t random_script.sh
runcon system_u:system_r:initrc_t:s0 sh -c ./mysql_test.sh | cat
# When command is executed successfully, you see the following output
#	system_u:system_r:mysqld_t:s0
#	SELinux status is set to: Enforcing
#	SELinux status is set to: Enforcing
#
# Now mysql_upgrade processe is able to execute the bash script of mysqld_exec_t type but still it
# is not able to change SELinux mode because the process is running in mysqld_t domain which
# don't have permission to change SELinux status. But it can get access the current status of
# SELinux using getenforce command
#
# Also look for this log entry in /var/log/audit/audit.log
#
#	type=AVC msg=audit(1466697794.179:942009): avc:  denied  { setenforce } for  pid=93870 comm=
#	"setenforce" scontext=system_u:system_r:mysqld_t:s0 tcontext=system_u:object_r:security_t:s0 
#	tclass=security
#
# The log entry demonstrate the the process with context "scontext=system_u:system_r:mysqld_t:s0" 
# is denied to execute setenforce command which has context "tcontext=system_u:object_r:security_t:s0"

# Restore the context before you go for the next test.
# Reset the context of mysql_test.sh and random_script.sh file to orignal state that was 
# unconfined_u:object_r:admin_home_t:s0. Use commands below to reset context,
restorecon mysql_test.sh
restorecon random_script.sh
# Make sure these commands executed successfully, the expected output for both command is;
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534213].
#	Full path required for exclude: net:[4026534213].

#***************************************mysqld_safe test******************************************#
# First test:
# For mysqld_safe change the context of mysql_test.sh file to
# unconfined_u:object_r:mysqld_safe_exec_t:s0, same as that of mysqld_safe binary file, so
# that it can spawn a process in mysqld_safe_t SELinux domain.
chcon -t mysqld_safe_exec_t mysql_test.sh
# Make sure this command works fine without any error.

# Since mysql_test.sh is of mysqld_safe_exec_t SELinux type which when executed will originates
# a process with mysqld_safe_t SELinux domain. This command make sure that mysql_test.sh is
# executed in the specified context. The bash file mysql_test.sh is executed in initrc_t domain
# because initrc_t domain can transition to any other domain. So this execution will originates a
# process with mysqld_safe_t domain.
runcon system_u:system_r:initrc_t:s0 sh -c ./mysql_test.sh | cat
# The command is expected to fail and failure  will be logged in that file /var/log/audit/audit.log
# Look for an entry of following type
#
#	type=AVC msg=audit(1466699420.588:943870): avc:  denied  { execute } for  pid=43061 comm=
#	"mysql_test.sh" name="random_script.sh" dev="sda2" ino=8707375233 scontext=
#	system_u:system_r:mysqld_safe_t:s0 tcontext=unconfined_u:object_r:admin_home_t:s0 tclass=file
#
# This log entry shows that comm="mysql_test.sh" is denied to execute file name="random_script.sh".
# The source context, which is actually the context of the process, 
# "scontext=system_u:system_r:mysqld_safe_t:s0" is denied to access target context
# "tcontext=unconfined_u:object_r:admin_home_t:s0" for "execute" permission.
# So what happened is, when we execute mysql_test.sh with SELinux type mysqld_safe_exec_t, it
# generates a process with context "system_u:system_r:mysqld_safe_t:s0". As we scripted this
# process to execute a bash script "random_script.sh" which has the context 
# "unconfined_u:object_r:admin_home_t:s0". Since mysqld_safe_t process is not allowed to execute
# this script by the SELinux policy so it fails with this log error.
 
# Second test:
# A process with SELinux domain mysqld_safe_t can execute file with SELinux type 
# mysqld_safe_exec_t because the binary file in /bin directory is label with
# type mysqld_safe_exec_t. In order to prove that process running in mysqld_safe_t domain
# can execute the mysqld_safe_exec_t type files, change the SELinux type of random_script.sh
# script to mysqld_safe_exec_t and then run the mysql_test.sh script again.
chcon -t mysqld_safe_exec_t random_script.sh
runcon system_u:system_r:initrc_t:s0 sh -c ./mysql_test.sh | cat
# When command is executed successfully, you see the following output
#	system_u:system_r:mysqld_safe_t:s0
#	SELinux status is set to:
#	SELinux status is set to:
# Now mysqld_safe process is able to execute the bash script of mysqld_safe_exec_t type
# but still it is not able to change SELinux mode because the process is running in 
# mysqld_safe_t domain which don't have permission to change SELinux status.

# Restore the context before you go for the next test.
# Reset the context of mysql_test.sh and random_script.sh file to orignal state that was 
# unconfined_u:object_r:admin_home_t:s0. Use commands below to reset context,
restorecon mysql_test.sh
restorecon random_script.sh
# Make sure these commands executed successfully, the expected output for both command is;
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534107].
#	Full path required for exclude: net:[4026534213].
#	Full path required for exclude: net:[4026534213].

