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

Examples:
Just backup of a Database
> .\clone_db.ps1 -dsub an -ddb testing_stg -backupOnly

Create a new database from an existing
> .\clone_db.ps1 -dsub sp -ddb testing_build2 -sdb testing_build -new

Clone from source to destination database within same subscription
> .\clone_db.ps1 -dsub an -sdb testing_prod -ddb testing_stg

Clone database from source subscription to destination subscription
> .\clone_db.ps1 -dsub an -ddb testing_stg -ssub sp -sdb testing_build

Create a new database from an existing database across different subscriptions
> .\clone_db.ps1 -dsub an -ddb testing_stg -ssub sp -sdb testing_build -new

Restore already existing database from bacpac URL
> .\clone_db.ps1 -dsub sp -ddb testing_build -restoreURL "https://myteststorageaccount.blob.core.windows.net/dbbackups/vic_dev_db-2018-10-09-12-53.bacpac"

Create a new database from bacpac URL
> .\clone_db.ps1 -dsub sp -ddb testing_build -restoreURL "https://myteststorageaccount.blob.core.windows.net/dbbackups/vic_dev_db-2018-10-09-12-53.bacpac" -new