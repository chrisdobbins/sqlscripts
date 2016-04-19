# sqlscripts
A repo for useful (to me) T-SQL scripts/stored procedures. I only have access to SQL Server 2008R2; I can't guarantee that this will work with other versions.

Scripts
* restore latest diff and full.sql
 * This stored procedure takes one param, the name of the database that is to be restored. 
 * It queries the system tables to find the latest full and differential backup files and compares their timestamps. If the full is more recent than the differential, then only the full is restored. If the differential is more recent, then the full is restored, followed by the differential. 
 * Caveat: This won't work for backups that don't have corresponding records in the system tables (i.e., if a backup file is copied from another machine, this stored proc won't know it's there and therefore will not restore it)
