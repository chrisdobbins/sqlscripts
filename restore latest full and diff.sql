----------------------------------------------------------------------
--Database restore script that: 
--1. Gets the latest full and diff backups by timestamp. Compare
--the timestamp on the differential to the timestamp on the full
--backup before restoring the differential.
--2. Sets the appropriate variables for the full and diff backup files.
--3. Restores the latest full, then the latest differential.
----------------------------------------------------------------------
USE [MASTER]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE EZRESTORE
@DBNAME NVARCHAR(100)
AS
BEGIN

DECLARE @DIFFBACKUPFILE NVARCHAR(MAX), @FULLBACKUPFILE NVARCHAR(MAX);

---------------------------------------------------
-- gets latest full backup file for @DBNAME
---------------------------------------------------
SET @FULLBACKUPFILE = (select TOP(1) 
M.PHYSICAL_DEVICE_NAME 
FROM MSDB.DBO.backupset AS B
INNER JOIN MSDB.DBO.backupmediafamily AS M
ON B.MEDIA_SET_ID = M.MEDIA_SET_ID
WHERE B.TYPE = 'D' -- full backup type (note: differential is 'I')
AND B.DATABASE_NAME = @DBNAME
ORDER BY B.backup_finish_date DESC);
print @fullbackupfile;

----------------------------------------------------
-- gets latest diff backup file for @DBNAME
--IF AND ONLY IF diff's backup date is later than 
--full's backup date
----------------------------------------------------
SET @DIFFBACKUPFILE = CASE 
                      WHEN ((SELECT top(1) 
                      B.backup_finish_date
                       FROM MSDB.DBO.backupset AS B
                      INNER JOIN MSDB.DBO.backupmediafamily AS M
                      ON B.MEDIA_SET_ID = M.MEDIA_SET_ID
                      WHERE B.TYPE = 'I' -- differential backup type
                      AND B.DATABASE_NAME = @DBNAME
                      ORDER BY B.BACKUP_FINISH_DATE DESC) > (select TOP(1) 
                      B.BACKUP_FINISH_DATE
                      FROM MSDB.DBO.backupset AS B
                      INNER JOIN MSDB.DBO.backupmediafamily AS M
                      ON B.MEDIA_SET_ID = M.MEDIA_SET_ID
                      WHERE B.TYPE = 'D' -- full backup type
                      AND B.DATABASE_NAME = @DBNAME
                      ORDER BY B.backup_finish_date DESC))
                      THEN 
                      (SELECT top(1) 
                      M.PHYSICAL_DEVICE_NAME -- diff backup file
                       FROM MSDB.DBO.backupset AS B
                      INNER JOIN MSDB.DBO.backupmediafamily AS M
                      ON B.MEDIA_SET_ID = M.MEDIA_SET_ID
                      WHERE B.TYPE = 'I'
                      AND B.DATABASE_NAME = @DBNAME
                      ORDER BY B.BACKUP_FINISH_DATE DESC)
                      END;

IF ISNULL(@DIFFBACKUPFILE, '') = ''
  BEGIN
  -- FULL RESTORE ONLY
  RESTORE DATABASE @DBNAME
  FROM DISK =  @FULLBACKUPFILE
  WITH STATS = 10
  , RECOVERY 
  , REPLACE;
  END
ELSE 
  BEGIN
  ---- FULL RESTORE
  RESTORE DATABASE @DBNAME
  FROM DISK =  @FULLBACKUPFILE
  WITH STATS = 10
  , NORECOVERY -- DO NOT CHANGE!!!
  , REPLACE;   
  ----DIFF RESTORE
  RESTORE DATABASE @DBNAME
  FROM DISK = @DIFFBACKUPFILE
  WITH STATS = 10
  , RECOVERY;
  END
END
