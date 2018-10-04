Purpose:
The script automates the process of cloning databases.

Execution:
The script needs to be triggered from the same directory where it is placed. It would require your Azure active directory credentials with appropriate permissions.

> clone_db.ps1

There are many parameters that can change the execution flow.

Required Parameters:
- dsub
	Choose destination subscription value from the set ('an','tmx','vic','sp').
- ddb
	Name of the destination database details from the respective json file

Optional Parameters:
- ssub
	Choose source subscription value from the set ('an','tmx','vic','sp'). This parameters is required only when you need to clone database across different subscription
- sdb
	Name of the source database details from the respective json file. Required when you need to clone from a source database.
- backupOnly
	It's switch parameter required only when you just want to take backup of destination database and nothing else
- new
	This parameter is used when you want to create a new database from an existing source database.

