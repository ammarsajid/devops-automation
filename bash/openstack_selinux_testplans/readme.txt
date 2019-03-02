What is SELinux?
	Security-Enhanced Linux (SELinux) is a Linux security module that is built into the Linux
	 kernel. SELinux is driven by SElinux policy rules. When a security related access is required,
	 such as when a process attempts to open a file, the operation is intercepted in the kernel by
	 SELinux. If an SELinux policy rule allows the operation it continues otherwise the operation
	 is blocked and the process receives an error.

What is Mandatory and Discretionary Access?
	SELinux is an implementation of a Mandatory Access Control (MAC) mechanism in the Linux kernel,
	 checking for allowed operations after standard Discretionary Access Controls (DAC) are
	 checked. Most operating systems use a Discretionary Access Control system that controls how
	 users control the permissions of files that they own. Relying on DAC mechanisms alone is
	 inadequate for strong system security. DAC access decisions are only based on user identity
	 and ownership, ignoring other information such as the role of the user, the function and
	 trustworthiness of the program, and the sensitivity and integrity of the data. Each user
	 typically has complete discretion over their files, making it difficult to enforce a
	 system-wide security policy. Furthermore, every program run by a user inherits all of the
	 permissions granted to the user and is free to change access to the user's files, so minimal
	 protection is provided against malicious software. SELinux policy rules have no effect if
	 Discretionary Access Control (DAC) rules deny access first.

What is the Access Vector Cache?
	SELinux decisions, such as allowing or disallowing access, are cached. This cache is known as
	 the Access Vector Cache (AVC). When using these cached decisions, SELinux policy rules need to
	 be checked less, which increases performance.

What is an SELinux context?
	Processes and files are labeled with an SELinux context that contains additional information,
	 such as an SELinux user, role and type. The context is used to make access control decisions.
	 Use 'ls -Z' command to show the context of files and directories.
	
	[heat-admin@overcloud-controller-0 ~]$ ls -Z /bin/nova-api
	-rwxr-xr-x. root root unconfined_u:object_r:nova_exec_t:s0 /bin/nova-api

	"unconfined_u:object_r:nova_exec_t:s0" is the context of file nova-api
	
	SELinux user:
		SELinux maintains its own user identity for processes, separately from Linux user identities.
		 In a SELinux context, the first part (always ended with '_u') is called the SELinux user. The
		 SELinux user is an ID known to the policy that is authorized for a specifics set of roles.
		 Each Linux user is mapped to an SELinux user via SELinux policy.
		 
	SELinux role:
		The SELinux role shows that what domains are possible to be in this user. In SELinux context, 
		 the second part ended with '_r' is the role of that user.
	
	SELinux type:
		The type defines a domain for processes. SELinux policy rules define how types can access
		each other.

Advantages of SELinux
	Every process has its own domain and processes are separated from each other by running in
	their own domains.

	SELinux policy rules define how processes interact with files, as well as how processes
	interact with each other.

	SELinux access decisions are based on all available information, such as SELinux user, role,
	type and optionally a level.

	Reduced vulnerability to privilege escalation attacks.

	SELinux can be used to enforce data confidentiality and integrity, as well as protecting
	processes from untrusted inputs.

SElinux States and Modes
	SELinux can be either in the enabled or disabled state. When disabled, only DAC rules are used.
	When enabled, SELinux can run in one of the following modes:

	Enforcing
		When SELinux policy is enforced, it denies access based on SELinux policy rules.

	Permissive
		When SELinux policy is permissive, it does not deny access but denials are logged for
		 actions that would have been denied if running in enforcing mode.


Current SELinux status on all nodes of Red Hat OpenStack Liberty:

	System Admin Host Node		Permissive
	Director Node				Enforcing
	Ceph Node					Enforcing
	Controller Nodes			Enforcing
	Compute Nodes				Enforcing
	Storage Nodes				Permissive

Use 'sestatus' command to check the current status of SELinux.

For OpenStack components, we are going to use the SELinux policies provided by the openstack-selinux
 rpm for Red Hat OpenStack Platform.

The link to the openstack-selinux GitHub repo is:

	https://github.com/redhat-openstack/openstack-selinux

The version details of openstack-selinux package provided by Red Hat OpenStack Liberty:

	[root@overcloud-controller-0 heat-admin]# rpm -qi openstack-selinux
	Name        : openstack-selinux
	Version     : 0.6.58
	Release     : 1.el7ost
	Architecture: noarch
	Install Date: Fri 15 Apr 2016 10:40:31 PM UTC
	Group       : System Environment/Base
	Size        : 143770
	License     : GPLv2
	Signature   : RSA/SHA256, Thu 24 Mar 2016 05:55:51 PM UTC, Key ID 199e2f91fd431d51
	Source RPM  : openstack-selinux-0.6.58-1.el7ost.src.rpm
	Build Date  : Thu 10 Mar 2016 02:03:43 PM UTC
	Build Host  : x86-034.build.eng.bos.redhat.com
	Relocations : (not relocatable)
	Packager    : Red Hat, Inc. <http://bugzilla.redhat.com/bugzilla>
	Vendor      : Red Hat, Inc.
	URL         : https://github.com/redhat-openstack/openstack-selinux
	Summary     : SELinux Policies for OpenStack
	Description :
	SELinux policy modules for use with OpenStack


The list of files installed by that openstack-selinux rpm are:

	[root@overcloud-controller-0 heat-admin]# rpm -ql openstack-selinux
	/usr/share/doc/openstack-selinux-0.6.58
	/usr/share/doc/openstack-selinux-0.6.58/COPYING
	/usr/share/selinux/devel/include/services/os-glance.if
	/usr/share/selinux/devel/include/services/os-haproxy.if
	/usr/share/selinux/devel/include/services/os-ipxe.if
	/usr/share/selinux/devel/include/services/os-keepalived.if
	/usr/share/selinux/devel/include/services/os-keystone.if
	/usr/share/selinux/devel/include/services/os-mongodb.if
	/usr/share/selinux/devel/include/services/os-mysql.if
	/usr/share/selinux/devel/include/services/os-neutron.if
	/usr/share/selinux/devel/include/services/os-nova.if
	/usr/share/selinux/devel/include/services/os-ovs.if
	/usr/share/selinux/devel/include/services/os-rabbitmq.if
	/usr/share/selinux/devel/include/services/os-redis.if
	/usr/share/selinux/devel/include/services/os-rsync.if
	/usr/share/selinux/devel/include/services/os-swift.if
	/usr/share/selinux/packages/os-glance.pp.bz2
	/usr/share/selinux/packages/os-haproxy.pp.bz2
	/usr/share/selinux/packages/os-ipxe.pp.bz2
	/usr/share/selinux/packages/os-keepalived.pp.bz2
	/usr/share/selinux/packages/os-keystone.pp.bz2
	/usr/share/selinux/packages/os-mongodb.pp.bz2
	/usr/share/selinux/packages/os-mysql.pp.bz2
	/usr/share/selinux/packages/os-neutron.pp.bz2
	/usr/share/selinux/packages/os-nova.pp.bz2
	/usr/share/selinux/packages/os-ovs.pp.bz2
	/usr/share/selinux/packages/os-rabbitmq.pp.bz2
	/usr/share/selinux/packages/os-redis.pp.bz2
	/usr/share/selinux/packages/os-rsync.pp.bz2
	/usr/share/selinux/packages/os-swift.pp.bz2

Note: The files with extension '.if' are empty and they are probably not used.
Checking for the existence of the .pp files is a step in the validation process.


The version details of current SELinux package on controller and compute nodes can be determined
 using rpm command

[heat-admin@overcloud-controller-0 ~]$ rpm -qi selinux-policy
Name        : selinux-policy
Version     : 3.13.1
Release     : 60.el7_2.3
Architecture: noarch
Install Date: Fri 15 Apr 2016 09:40:03 PM UTC
Group       : System Environment/Base
Size        : 180
License     : GPLv2+
Signature   : RSA/SHA256, Fri 29 Jan 2016 10:45:27 AM UTC, Key ID 199e2f91fd431d51
Source RPM  : selinux-policy-3.13.1-60.el7_2.3.src.rpm
Build Date  : Wed 27 Jan 2016 11:19:46 AM UTC
Build Host  : ppc-026.build.eng.bos.redhat.com
Relocations : (not relocatable)
Packager    : Red Hat, Inc. <http://bugzilla.redhat.com/bugzilla>
Vendor      : Red Hat, Inc.
URL         : http://oss.tresys.com/repos/refpolicy/
Summary     : SELinux policy configuration
Description :
SELinux Reference Policy - modular.
Based off of reference policy: Checked out revision  2.20091117


On Director node, the version of selinux-policy is same but dates are slightly different,

[osp_admin@director pilot]$  rpm -qi selinux-policy
Name        : selinux-policy
Version     : 3.13.1
Release     : 60.el7_2.3
Architecture: noarch
Install Date: Tue 14 Jun 2016 12:48:53 AM CDT
Group       : System Environment/Base
Size        : 180
License     : GPLv2+
Signature   : RSA/SHA256, Fri 29 Jan 2016 04:45:27 AM CST, Key ID 199e2f91fd431d51
Source RPM  : selinux-policy-3.13.1-60.el7_2.3.src.rpm
Build Date  : Wed 27 Jan 2016 05:19:46 AM CST
Build Host  : ppc-026.build.eng.bos.redhat.com
Relocations : (not relocatable)
Packager    : Red Hat, Inc. <http://bugzilla.redhat.com/bugzilla>
Vendor      : Red Hat, Inc.
URL         : http://oss.tresys.com/repos/refpolicy/
Summary     : SELinux policy configuration
Description :
SELinux Reference Policy - modular.
Based off of reference policy: Checked out revision  2.20091117


How to check which SELinux policies are loaded successfully?

We can check active policies that have been loaded into the kernel by using 'semodule -l' command

[root@director log]# semodule -l | grep os-
os-glance       0.1
os-haproxy      0.1
os-ipxe 		0.1
os-keepalived   0.1
os-keystone     0.1
os-mongodb      0.1
os-mysql        0.1
os-neutron      0.1
os-nova 		0.1
os-ovs  		0.1
os-rabbitmq     0.1
os-redis        0.1
os-rsync        0.1
os-swift        0.1

These modules are installed loaded by openstack-selinux package but other than these package, the
 base package of selinux 'selinux-policy', have some SELinux modules for OpenStack components. 
 such as,

nova    		1.0.0
glance  		1.1.0
cinder  		1.0.0
swift   		1.0.0
keepalived	    1.0.0
keystone    	1.1.0
mongodb 		1.1.0
mysql   		1.14.1
rabbitmq       	1.0.2
redis   		1.0.1
rsync   		1.13.0

Initially we assume that openstack-selinux policies are built on these base policies provided by
 base selinux package. The difference between these packages is needed to be evaluate.

On director node there are more selinux policy module installed as part of image. such as

ironic-ipxe     				1.0
tripleo-selinux-keepalived      1.0
tripleo-selinux-keystone        1.0
tripleo-selinux-neutron 		1.0
tripleo-selinux-nova    		1.0
tripleo-selinux-openvswitch     1.0
tripleo-selinux-rhsmcertd       1.0
tripleo-selinux-ssh     		1.0
tripleo-selinux-swift   		1.0

 
Are policies for Cinder in the package?

The base policy 'selinux-policy' contains the Cinder SELinux module but the SElinux module for
 Cinder is not part of the current installed openstack-selinux package. These policies are
 added in the latest release openstack-selinux-0.7.3. Below is the GitHub link comparing 
 openstack-selinux-0.6.58 package with the latest available release.

Comparing the latest openstack-selinux package with current installed package:

	https://github.com/redhat-openstack/openstack-selinux/compare/0.6.58...el7

The package installed is only a few commits behind the latest release. Other than Cinder & Cielometer,
policies for all the other OpenStack components are in the current installed package.
	 
Do we have to update to openstack-selinux latest package?
TBD: early guidance is the we should not update to the latest package. We are discussing
with Red Hat as to their reasons to NOT include the latest package. We believe it may have
hindered their ability to execute the automated Director-based deployment model.

When loaded, is there a place where the Kernel logs anything on behalf of SElinux policies?

We can check the current  SElinux packaged installed by using “yum history” and “rpm” commands.

[root@overcloud-controller-0 log]# yum history info 10
Loaded plugins: product-id, search-disabled-repos, subscription-manager
This system is not registered to Red Hat Subscription Management. You can use subscription-manager
 to register.
Transaction ID : 10
Begin time     : Fri Apr 15 22:40:30 2016
Begin rpmdb    : 1041:e212dd4a329758beebbb7c339819a9c54db82e6e
End time       :            22:41:21 2016 (51 seconds)
End rpmdb      : 1042:ad0ccaec66799b8b5b560013c736f8d1d70a1fa8
User           : root <root>
Return-Code    : Success
Command Line   : -v -y install openstack-selinux
Transaction performed with:
    Installed     rpm-4.11.3-17.el7.x86_64                  @anaconda/7.2
        Installed     subscription-manager-1.15.9-15.el7.x86_64 @anaconda/7.2
	    Installed     yum-3.4.3-132.el7.noarch                  @anaconda/7.2
	        Installed     yum-metadata-parser-1.1.4-10.el7.x86_64   @anaconda/7.2
		Packages Altered:
		    Install openstack-selinux-0.6.58-1.el7ost.noarch @rhos-8.0-signed
		    history info

		    Also by using rpm command we can see the package installed
		    [root@director targeted]# rpm -qi openstack-selinux
		    Name        : openstack-selinux
		    Version     : 0.6.58
		    Release     : 1.el7ost
		    Architecture: noarch
		    Install Date: Thu 02 Jun 2016 02:19:43 PM CDT
		    Group       : System Environment/Base
		    Size        : 143770
		    License     : GPLv2
		    Signature   : RSA/SHA256, Thu 24 Mar 2016 12:55:51 PM CDT, Key ID 199e2f91fd431d51
		    Source RPM  : openstack-selinux-0.6.58-1.el7ost.src.rpm
		    Build Date  : Thu 10 Mar 2016 08:03:43 AM CST
		    Build Host  : x86-034.build.eng.bos.redhat.com
		    Relocations : (not relocatable)
		    Packager    : Red Hat, Inc. <http://bugzilla.redhat.com/bugzilla>
		    Vendor      : Red Hat, Inc.
		    URL         : https://github.com/redhat-openstack/openstack-selinux
		    Summary     : SELinux Policies for OpenStack
		    Description :
		    SELinux policy modules for use with OpenStack

But we didn’t find any log entries or other crumbs showing openstack-selinux policies are loaded into the Kernel.

-----------------------

In SELinux test plans we are going to prove that SELinux policies, provided in
 openstack-selinux package, are being enforced and the OpenStack services are protected by SELinux. 

We started with the understanding of test suite provided by SElinux project on GitHub.  
Below is the link to the tests by SElinux project on GitHub. These are the general tests for
 SELinux features. No openstack-specific tests are there but we started looking into the
 test suite below, which might be useful for creating openstack-selinux tests for our purpose.

 https://github.com/SELinuxProject/selinux-testsuite

The selinux-testsuite uses perl to create test scripts for SELinux policies. Below is the example
 code for the testing of creating a sub-directory in a particular directory. This example tests if
 'mkdir' command is able to create sub-directory in a directory having a specific SELinux context.

# ******************************************************************
#!/usr/bin/perl

use Test;
BEGIN { plan tests => 5}

$basedir = $0;  $basedir =~ s|(.*)/[^/]*|$1|;

$selinux_mntpoint = `mount | grep "^selinuxfs" | awk '{ORS="";print \$3}'`;
if (-e "$selinux_mntpoint/mls") {
    print "selinuxfs found at: $selinux_mntpoint\n";
} else {
    print "selinuxfs not found in mount list\n";
    @locations = ('/selinux', '/sys/fs/selinux');
    foreach (@locations) {
        if (-e "$_/mls") {
            $selinux_mntpoint = $_;
            print "selinuxfs found at: $selinux_mntpoint\n";
            last;
        }
    }
}

$mls = `cat $selinux_mntpoint/mls`;
if ($mls eq 1) {
	$suffix = ":s0";
} else {
	$suffix = "";
}

# Remove any leftover test directory from prior failed runs.
system ("rm -rf $basedir/test_dir");

# Create a test directory with the test_mkdir_dir_t type for use in the tests.
system ("mkdir $basedir/test_dir 2>&1");
system ("chcon -t test_mkdir_dir_t $basedir/test_dir" );

# Verify that test_addname_t can create a subdirectory.
$result = system ("runcon -t test_addname_t mkdir $basedir/test_dir/test1 2>&1");
ok($result, 0); 

# Verify that test_noaddname_t cannot create a subdirectory.
# Should fail on the add_name permission check to the test directory.
$result = system ("runcon -t test_noaddname_t mkdir $basedir/test_dir/test2 2>&1");
ok($result); 

# Verify that test_nosearch_t cannot create a subdirectory.
# Should fail on the search permission check to the test directory.
$result = system ("runcon -t test_nosearch_t mkdir $basedir/test_dir/test2 2>&1");
ok($result); 

# Verify that test_create_t can create a subdirectory with a different type.
# This requires add_name to test_mkdir_dir_t and create to test_create_dir_t.
$result = system ("runcon -t test_create_t -- mkdir --context= \
			system_u:object_r:test_create_dir_t$suffix $basedir/test_dir/test3 2>&1");
ok($result, 0); 

# Verify that test_nocreate_t cannot create a subdirectory with a different type.
# Should fail on create check to the new type.
$result = system ("runcon -t test_nocreate_t -- mkdir --context=\
			system_u:object_r:test_create_dir_t$suffix $basedir/test_dir/test4 2>&1");
ok($result); 

# Cleanup.
system ("rm -rf $basedir/test_dir");

#******************************************************************

'chcon' command is used to change SELinux context of a file or directory.

'runcon' command is used to run any command (or process) in a particular defined context. If the
 process is allowed by the SELinux policy to run in that particular context, then it would execute
 the provided command, otherwise not.

So we can build our own perl script to test openstack-selinux policies. For example we can write a
 test that execute 'nova list' command in 'nova_t' domain, this test should pass but if we change
 the domain it supposed to fail.

 ----------------

We have tried 'runcon' command to execute nova commands like this

$ runcon -t unconfined_t nova list

The 'runcon' command supposed to work only for 'nova_t' domain but this only works with
 'unconfined_t' domain although all nova processes are running in 'nova_t' domains, as shown below
 (truncated output):

[heat-admin@overcloud-controller-0 ~]$ ps -axZ | grep nova
system_u:system_r:nova_t:s0    10343 ?      Ss     1:23 /usr/bin/python2 /usr/bin/nova-scheduler
system_u:system_r:nova_t:s0    85415 ?      Ss    82:40 /usr/bin/python2 /usr/bin/nova-api
system_u:system_r:nova_t:s0    86142 ?      Ss     6:48 /usr/bin/python2 /usr/bin/nova-consoleauth
system_u:system_r:nova_t:s0    88290 ?      Ss     4:00 /usr/bin/python2 /usr/bin/nova-novncproxy \
--web /usr/share/novnc/

When we list the context of nova file in /usr/bin/, all file are of type 'nova_exec_t', shown below

[heat-admin@overcloud-controller-0 ~]$ ls -Z /usr/bin/ | grep nova
-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   nova
-rwxr-xr-x. root root   unconfined_u:object_r:nova_exec_t:s0 nova-api
-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   nova-api-ec2
-rwxr-xr-x. root root   unconfined_u:object_r:nova_exec_t:s0 nova-api-metadata
-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   nova-api-os-compute
-rwxr-xr-x. root root   unconfined_u:object_r:nova_exec_t:s0 nova-cert
-rwxr-xr-x. root root   unconfined_u:object_r:virtd_exec_t:s0 nova-compute
-rwxr-xr-x. root root   unconfined_u:object_r:nova_exec_t:s0 nova-conductor
-rwxr-xr-x. root root   unconfined_u:object_r:nova_exec_t:s0 nova-console
-rwxr-xr-x. root root   unconfined_u:object_r:nova_exec_t:s0 nova-consoleauth
-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   nova-idmapshift
-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   nova-manage
-rwxr-xr-x. root root   unconfined_u:object_r:nova_exec_t:s0 nova-novncproxy
-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   nova-rootwrap
-rwxr-xr-x. root root   unconfined_u:object_r:bin_t:s0   nova-rootwrap-daemon
-rwxr-xr-x. root root   unconfined_u:object_r:nova_exec_t:s0 nova-scheduler
-rwxr-xr-x. root root   unconfined_u:object_r:nova_exec_t:s0 nova-xvpvncproxy

The reason behind this strange behaviour is initially assumed that these services are running in
 unconfined domain.

Difference between confined and unconfined domains

link:
https://wiki.gentoo.org/wiki/SELinux/Tutorials/What_is_this_unconfined_thingie_and_tell_me_about_attributes

The unconfined space is for processes that require almost unrestricted access. Almost because
 writable memory execution is not permitted. The following permissions are restricted for processes
 that operate in the unconfined space unless specified otherwise: 
	 Execmem 
	 Execstack 
	 Execheap
	 Execmod

As it so happens, most processes that conduct a useful function require the ability to
modify the memory, use of the stack for function calls/returns, use of the heap
for memory allocation, respectively for the first three in the list above.

About Execmod:
The execmod permission controls the ability to execute memory-mapped files
that *have been modified* in the process memory.

This permission check is useful in keeping shared libraries from being modified within a process.
Without it, if a memory mapped file is modified, it will not be allowed to be executed by the process
(http://www.engardelinux.org/modules/index/list_archives.cgi?list=selinux&page=0213.html&month=2007-09)

The 'setsebool' and 'getsebool' commands are used to set/get these values.

TBD: understand if we want to set/disable/enable different parts of specific OpenStack
component policies.

The unconfined domain is to support SELinux-enabled systems where the network related services are
 running in confined domains like http, ssh etc., but the users themselves run in a more
 unrestricted fashion. The commands executed by the users are trusted by the system in unconfined
 domain. When unconfined domains are used, SELinux is mainly set up to protect against remote
 attacks and remotely exploitable vulerabilities. Local attacks are then not targeted when using
 SELinux with unconfined domains.

Applications that are normally confined might also run in the unconfined domain if they are
 launched by a user whose processes are already in the unconfined domain.

The kernel and RPM processes stay unconfined because they processes need many permissions in order
 to operate successfully.

Since http and ssh srevices are running in confined domain, for negative testing, we will SSH into
 the controller node from a remote machine and try to run commands that voilates the SELinux
 policies. We may decide to build perl/python scripts (like the SELinux testsuite) to test the
 openstack-selinux policies. Our focus would be more on negative testing of these policies.

--------------------------

After research, we come to the know that OpenStack services are running in confined domain with the
 correct context but when we run CLI commands (e.g /bin/nova), they are not running in correct
 context. Then we started looking into the process transitioning in processes and find out that we
 cannot run any process/command in a specific context directly from an unconfined domain. Similarly
 the problem we were facing with the 'runcon' command is, we execute ‘runcon’ command to access
 nova domain directly and no policy defined to access nova domain directly from the unconfined
 domain. By default unconfined domain transition to initrc and initrc can transition to most of the
 domains (depends upon policy). That is the reason why nova commands works through unconfined
 domain but not directly. Lets take an example, what happens when we run ‘nova list’ command in
 Linux shell,

	Linux kernel executes /sbin/init, resulting in the init process
	The init process executes init_domain_daemon which defines the transitioning.
	Since init_domain_daemon have transitioning policies defined so it can call ‘nova_t’ domain.

Now what we can do is to execute ‘runcon’ command from initrc domain. we have tried this way and it
 worked fine.

$ runcon system_u:system_r:initrc_t:s0 sh -c 'nova list'

--------------------------

Af this stage, we are clear that how to run processes in their particular contexts so we started
 writing test plan for services of OpenStack. We targeted the below services in priority order:
 
	1) Nova
	2) Glance
	3) Swift
	4) Keystone
	5) Neutron
	6) OVS
	7) Cinder
	8) MySQL
	9) Keepalive
	10) Redis
	
Each service has it's own test plan with name testplan_<service>.sh. Each test plan is a step by
 step guide and check points. The test plans are designed to prove that these services are
 protected by SELinux. The test plans are more focused on negative testing and each test plan
 proves that the particular service is harmful for the system or not. If the service is protected
 by SELinux then it should not be harmful.

How to run a test?
 Each test plan contains description and set of commands to run. The description is written as
 comments in bash script and commands as normal bash commands. Even though we are using bash
 files (with .sh extention) but still these are not executable bash scripts. Two different tests
 are performed while testing of each service in each test plan named as:
 First test
	legitimate service executable can't execute malicious commands
 Second test
	hijacked service executable can't execute malicious commands

 There are two different bash files are genereted in each test <service>_test.sh and random_test.sh.
 <service>_test.sh is a proxy for all executables related to that service. There are two main roles
 which random_script.sh plays.
 
 In First test:
	random_script is a proxy for malicious actions that an unauthorized user might take with the
	intention of breaking through the OpenStack components. For example, completly turning off the
	selinux enforcement by executing this command "setenforce 0"
	
 In Second test:
	We will make random_script into a proxy for the service executables by replacing it with
	malicious commands such as turning off selinux enforcement. This is the scenerio where a
	hacker replaces an executables of a particular service with it's own executables which includes
	potentially malicious commands. In that case the hacker executables will execute as if they are
	executable of that particular service (service under testing) but it will try to execute
	commands that require higher priveliges to run.

 Run the test plan as a root user. Follow the test plan and compare your output with expected
 output.
 Best practices:
	Create a folder in root directory before starting the validation
	Create seperate a subdirectory for each test plan.	
 