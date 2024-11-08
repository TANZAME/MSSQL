


-- 查看最近执行的语句
SELECT TOP 1000 
       ST.text AS '执行的SQL语句',
       QS.execution_count AS '执行次数',
       QS.total_elapsed_time AS '耗时',
       QS.total_logical_reads AS '逻辑读取次数',
       QS.total_logical_writes AS '逻辑写入次数',
       QS.total_physical_reads AS '物理读取次数',       
       QS.creation_time AS '执行时间' ,  
       QS.*
FROM   sys.dm_exec_query_stats QS
       CROSS APPLY 
sys.dm_exec_sql_text(QS.sql_handle) ST
WHERE  QS.creation_time BETWEEN dateadd(minute,-2,getdate()) AND getdate()
ORDER BY QS.creation_time desc;


SELECT --TOP 2000 
       ST.text AS '执行的SQL语句',
       QS.execution_count AS '执行次数',
       QS.total_elapsed_time AS '耗时',
       QS.total_logical_reads AS '逻辑读取次数',
       QS.total_logical_writes AS '逻辑写入次数',
       QS.total_physical_reads AS '物理读取次数',       
       QS.creation_time AS '执行时间' ,  
       QS.*
FROM   sys.dm_exec_query_stats QS
       CROSS APPLY 
sys.dm_exec_sql_text(QS.sql_handle) ST
WHERE  QS.creation_time BETWEEN dateadd(minute,-2,getdate()) AND getdate()
ORDER BY
     QS.execution_count desc--QS.total_elapsed_time DESC

	 
--查询编译以来 cpu耗时总量最多的前50条(Total_woker_time)
SELECT TOP 100
    total_worker_time/1000 AS [总消耗CPU 时间(ms)],
    execution_count [运行次数],
    qs.total_worker_time/qs.execution_count/1000 AS [平均消耗CPU 时间(ms)],
    last_execution_time AS [最后一次执行时间],
    max_worker_time /1000 AS [最大执行时间(ms)],
    SUBSTRING(qt.text,qs.statement_start_offset/2+1, 
        (CASE WHEN qs.statement_end_offset = -1 
        THEN DATALENGTH(qt.text) 
        ELSE qs.statement_end_offset END -qs.statement_start_offset)/2 + 1) 
    AS [使用CPU的语法], qt.text [完整语法],
    qt.dbid, dbname=db_name(qt.dbid),
    qt.objectid,object_name(qt.objectid,qt.dbid) ObjectName
FROM sys.dm_exec_query_stats qs WITH(nolock)
CROSS apply sys.dm_exec_sql_text(qs.sql_handle) AS qt
WHERE execution_count>1
ORDER BY  qs.total_worker_time/qs.execution_count DESC

SELECT TOP 20
[session_id],
[request_id],
[start_time] AS '开始时间',
[status] AS '状态',
[command] AS '命令',
dest.[text] AS 'sql语句',
DB_NAME([database_id]) AS '数据库名',
[blocking_session_id] AS '正在阻塞其他会话的会话ID',
[wait_type] AS '等待资源类型',
[wait_time] AS '等待时间',
[wait_resource] AS '等待的资源',
[reads] AS '物理读次数',
[writes] AS '写次数',
[logical_reads] AS '逻辑读次数',
[row_count] AS '返回结果行数',
[cpu_time]
FROM sys.[dm_exec_requests] AS der
CROSS APPLY
sys.[dm_exec_sql_text](der.[sql_handle]) AS dest
WHERE [session_id]>50 AND DB_NAME(der.[database_id])='Selmuch1004'
ORDER BY [cpu_time] DESC

  -- 按照逻辑读的页面数排序 前50名
SELECT TOP 50
qs.total_logical_reads,
qs.execution_count,
qs.max_elapsed_time,
qs.min_elapsed_time,
qs.total_logical_reads/qs.execution_count AS [AVG IO],
SUBSTRING(qt.text,qs.statement_start_offset/2,
(CASE WHEN qs.statement_end_offset=-1 
THEN LEN(CONVERT(NVARCHAR(max),qt.text)) *2
ELSE qs.statement_end_offset END -qs.statement_start_offset)/2) 
AS query_text,
qt.dbid,
dbname=DB_NAME(qt.dbid),
qt.objectid,
qs.sql_handle,
creation_time,
qs.plan_handle
from sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
ORDER BY qs.total_logical_reads/qs.execution_count DESC
	 
-- 1，查看CPU占用量最高的会话及SQL语句
select spid,cmd,cpu,physical_io,memusage,
(select top 1 [text] from ::fn_get_sql(sql_handle)) sql_text
from master..sysprocesses order by cpu desc,physical_io desc

--2，查看缓存重用次数少，内存占用大的SQL语句 
SELECT TOP 100 usecounts, objtype, p.size_in_bytes,[sql].[text] 
FROM sys.dm_exec_cached_plans p OUTER APPLY sys.dm_exec_sql_text (p.plan_handle) sql 
ORDER BY usecounts,p.size_in_bytes  desc


-- 看一下当前的数据库用户连接有多少
--如果要指定数据库就把注释去掉
SELECT * FROM sys.[sysprocesses] WHERE [spid]>50 --AND DB_NAME([dbid])='gposdb'
SELECT COUNT(*) FROM [sys].[dm_exec_sessions] WHERE [session_id]>50

SELECT TOP 10  dest.[text] AS 'sql语句' 
,der.[cpu_time] as 'cpu时间'
FROM sys.[dm_exec_requests] AS der  CROSS APPLY  sys.[dm_exec_sql_text](der.[sql_handle]) AS dest  
 WHERE [session_id]>50  ORDER BY [cpu_time] DESC 

 
几段排查SQL Server占用CPU过高的SQL
2019-03-21阅读 1K0
1.查看当前的数据库用户连接有多少

 USE master
 GO
 --如果要指定数据库就把注释去掉
 SELECT * FROM sys.[sysprocesses] WHERE [spid]>50 --AND DB_NAME([dbid])='gposdb'
 SELECT COUNT(*) FROM [sys].[dm_exec_sessions] WHERE [session_id]>50
 
2.查看各项指标是否正常，是否有阻塞，选取了前10个最耗CPU时间的会话
SELECT TOP 10
[session_id],
[request_id],
[start_time] AS '开始时间',
[status] AS '状态',
[command] AS '命令',
dest.[text] AS 'sql语句', 
DB_NAME([database_id]) AS '数据库名',
[blocking_session_id] AS '正在阻塞其他会话的会话ID',
[wait_type] AS '等待资源类型',
[wait_time] AS '等待时间',
[wait_resource] AS '等待的资源',
[reads] AS '物理读次数',
[writes] AS '写次数',
[logical_reads] AS '逻辑读次数',
[row_count] AS '返回结果行数'
FROM sys.[dm_exec_requests] AS der 
CROSS APPLY 
sys.[dm_exec_sql_text](der.[sql_handle]) AS dest 
WHERE [session_id]>50 AND DB_NAME(der.[database_id])='gposdb'  
ORDER BY [cpu_time] DESC

3.查看具体的SQL语句，需要在SSMS里选择以文本格式显示结果
--在SSMS里选择以文本格式显示结果
SELECT TOP 10 
dest.[text] AS 'sql语句'
FROM sys.[dm_exec_requests] AS der 
CROSS APPLY 
sys.[dm_exec_sql_text](der.[sql_handle]) AS dest 
WHERE [session_id]>50  
ORDER BY [cpu_time] DESC

4.查看CPU数和user scheduler数和最大工作线程数，检查worker是否用完也可以排查CPU占用情况
 --查看CPU数和user scheduler数目
 SELECT cpu_count,scheduler_count FROM sys.dm_os_sys_info
 --查看最大工作线程数
 SELECT max_workers_count FROM sys.dm_os_sys_info
 
5.查看worker是否用完，如果达到最大线程数的时候需要检查blocking
SELECT
scheduler_address,
scheduler_id,
cpu_id,
status,
current_tasks_count,
current_workers_count,active_workers_count
FROM sys.dm_os_schedulers

对照表：
各种CPU和SQLSERVER版本组合自动配置的最大工作线程数

CPU数

32位计算机

64位计算机

<=4

256

512

8

288

576

16

352

704

32

480

960

6.查看会话中有多少个worker在等待

 SELECT TOP 10
 [session_id],
 [request_id],
 [start_time] AS '开始时间',
 [status] AS '状态',
 [command] AS '命令',
 dest.[text] AS 'sql语句', 
 DB_NAME([database_id]) AS '数据库名',
 [blocking_session_id] AS '正在阻塞其他会话的会话ID',
 der.[wait_type] AS '等待资源类型',
 [wait_time] AS '等待时间',
 [wait_resource] AS '等待的资源',
 [dows].[waiting_tasks_count] AS '当前正在进行等待的任务数',
 [reads] AS '物理读次数',
 [writes] AS '写次数',
 [logical_reads] AS '逻辑读次数',
 [row_count] AS '返回结果行数'
 FROM sys.[dm_exec_requests] AS der 
 INNER JOIN [sys].[dm_os_wait_stats] AS dows 
 ON der.[wait_type]=[dows].[wait_type]
 CROSS APPLY 
 sys.[dm_exec_sql_text](der.[sql_handle]) AS dest 
 WHERE [session_id]>50  
 ORDER BY [cpu_time] DESC
7.查看ASYNC_NETWORK_IO等待

（注：比如我当前执行了查询SalesOrderDetail_test表100次，由于表数据非常多，所以SSMS需要把SQLSERVER执行的结果慢慢的取走，造成了ASYNC_NETWORK_IO等待）

 USE [AdventureWorks]
 GO
 SELECT * FROM dbo.[SalesOrderDetail_test]
 GO 100
 
8.查询CPU占用高的语句
SELECT TOP 10
   total_worker_time/execution_count AS avg_cpu_cost, plan_handle,
   execution_count,
   (SELECT SUBSTRING(text, statement_start_offset/2 + 1,
      (CASE WHEN statement_end_offset = -1
         THEN LEN(CONVERT(nvarchar(max), text)) * 2
         ELSE statement_end_offset
      END - statement_start_offset)/2)
   FROM sys.dm_exec_sql_text(sql_handle)) AS query_text
FROM sys.dm_exec_query_stats
ORDER BY [avg_cpu_cost] DESC



9.查询缺失索引
SELECT 
    DatabaseName = DB_NAME(database_id)
    ,[Number Indexes Missing] = count(*) 
FROM sys.dm_db_missing_index_details
GROUP BY DB_NAME(database_id)
ORDER BY 2 DESC;
SELECT  TOP 10 
        [Total Cost]  = ROUND(avg_total_user_cost * avg_user_impact * (user_seeks + user_scans),0) 
        , avg_user_impact
        , TableName = statement
        , [EqualityUsage] = equality_columns 
        , [InequalityUsage] = inequality_columns
        , [Include Cloumns] = included_columns
FROM        sys.dm_db_missing_index_groups g 
INNER JOIN    sys.dm_db_missing_index_group_stats s 
       ON s.group_handle = g.index_group_handle 
INNER JOIN    sys.dm_db_missing_index_details d 
       ON d.index_handle = g.index_handle
ORDER BY [Total Cost] DESC;
172.19.55.208,42951



基本上所有解决办法都是基于对索引的重建和整理，只是方式不同
1.删除索引并重建
   这种方式并不好.在删除索引期间，索引不可用.会导致阻塞发生。而对于删除聚集索引，则会导致对应的非聚集索引重建两次(删除时重建，建立时再重建).虽然这种方法并不好，但是对于索引的整理最为有效
2.使用DROP_EXISTING语句重建索引
   为了避免重建两次索引，使用DROP_EXISTING语句重建索引，因为这个语句是原子性的，不会导致非聚集索引重建两次，但同样的，这种方式也会造成阻塞
3.如前面文章所示，使用ALTER INDEX REBUILD语句重建索引
   使用这个语句同样也是重建索引，但是通过动态重建索引而不需要卸载并重建索引.是优于前两种方法的，但依旧会造成阻塞。可以通过ONLINE关键字减少锁，但会造成重建时间加长.
4.使用 ALTER INDEX all ON 表名 REORGANIZE
   这种方式不会重建索引，也不会生成新的页，仅仅是整理，当遇到加锁的页时跳过，所以不会造成阻塞。但同时，整理效果会差于前三种.

sys.dm_db_index_physical_stats
补充一点：sys.dm_db_index_physical_stats函数中五个参数都可以为null。
select * from sys.dm_db_index_physical_stats(db_id(),null,null,null,null)

查询当前库的所有表的索引情况
select * from sys.dm_db_index_physical_stats(null,null,null,null,null)

12. 重整索引碎片
alter index all on Amz_AdGroupBidKwHourReport reorganize
alter index all on Amz_AdGroupHourReport reorganize
alter index all on Amz_AdGroupPATHourReport reorganize
alter index all on Amz_CampaignHourReport reorganize
alter index all on Amz_CampaignPosHourReport reorganize
alter index all on Amz_PortfolioHourReport reorganize
alter index all on Amz_ProductAdHourReport reorganize

-- 查看数据库分区情况
SELECT OBJECT_NAME(p.object_id) AS ObjectName,
      i.name                   AS IndexName,
      p.index_id               AS IndexID,
      ds.name                  AS PartitionScheme,   
      p.partition_number       AS PartitionNumber,
      fg.name                  AS FileGroupName,
      prv_left.value           AS LowerBoundaryValue,
      prv_right.value          AS UpperBoundaryValue,
      CASE pf.boundary_value_on_right
            WHEN 1 THEN 'RIGHT'
            ELSE 'LEFT' END    AS Range,
      p.rows AS Rows
FROM sys.partitions                  AS p
JOIN sys.indexes                     AS i
      ON i.object_id = p.object_id
      AND i.index_id = p.index_id
JOIN sys.data_spaces                 AS ds
      ON ds.data_space_id = i.data_space_id
JOIN sys.partition_schemes           AS ps
      ON ps.data_space_id = ds.data_space_id
JOIN sys.partition_functions         AS pf
      ON pf.function_id = ps.function_id
JOIN sys.destination_data_spaces     AS dds2
      ON dds2.partition_scheme_id = ps.data_space_id 
      AND dds2.destination_id = p.partition_number
JOIN sys.filegroups                  AS fg
      ON fg.data_space_id = dds2.data_space_id
LEFT JOIN sys.partition_range_values AS prv_left
      ON ps.function_id = prv_left.function_id
      AND prv_left.boundary_id = p.partition_number - 1
LEFT JOIN sys.partition_range_values AS prv_right
      ON ps.function_id = prv_right.function_id
      AND prv_right.boundary_id = p.partition_number 
WHERE
      OBJECTPROPERTY(p.object_id, 'ISMSShipped') = 0
UNION ALL
SELECT
      OBJECT_NAME(p.object_id)    AS ObjectName,
      i.name                      AS IndexName,
      p.index_id                  AS IndexID,
      NULL                        AS PartitionScheme,
      p.partition_number          AS PartitionNumber,
      fg.name                     AS FileGroupName,  
      NULL                        AS LowerBoundaryValue,
      NULL                        AS UpperBoundaryValue,
      NULL                        AS Boundary, 
      p.rows                      AS Rows
FROM sys.partitions     AS p
JOIN sys.indexes        AS i
      ON i.object_id = p.object_id
      AND i.index_id = p.index_id
JOIN sys.data_spaces    AS ds
      ON ds.data_space_id = i.data_space_id
JOIN sys.filegroups           AS fg
      ON fg.data_space_id = i.data_space_id
WHERE
      OBJECTPROPERTY(p.object_id, 'ISMSShipped') = 0
ORDER BY
      ObjectName,
      IndexID,
      PartitionNumber
	  
	  
Select s.name As SchemaName, t.name As TableName
From sys.tables t
Inner Join sys.schemas s On t.schema_id = s.schema_id
Inner Join sys.partitions p on p.object_id = t.object_id
Where p.index_id In (0, 1)
Group By s.name, t.name 
--Having Count(*) > 1 
Order By s.name, t.name;

	  
	  -- 查询SqlServer总体的内存使用情况
select type
 ,sum(virtual_memory_reserved_kb) VM_Reserved
 ,sum(virtual_memory_committed_kb) VM_Commited
 ,sum(awe_allocated_kb) AWE_Allocated
 ,sum(shared_memory_reserved_kb) Shared_Reserved
 ,sum(shared_memory_committed_kb) Shared_Commited
 --, sum(single_pages_kb)    --SQL2005、2008
 --, sum(multi_pages_kb)        --SQL2005、2008
from    sys.dm_os_memory_clerks
group by type
order by type
查询结果中：
--CACHESTORE_OBJCP：存储过程、函数等的执行计划
--CACHESTORE_SQLCP：SQL语句的执行计划
--MEMORYCLERK_SQLBUFFERPOOL：Buffer pool
--OBJECTSTORE_LOCK_MANAGER：锁

-- 查询当前数据库缓存的所有数据页面，哪些数据表，缓存的数据页面数量
-- 从这些信息可以看出，系统经常要访问的都是哪些表，有多大？
select p.object_id, object_name=object_name(p.object_id), p.index_id, buffer_pages=count(*) 
from sys.allocation_units a, 
    sys.dm_os_buffer_descriptors b, 
    sys.partitions p 
where a.allocation_unit_id=b.allocation_unit_id 
    and a.container_id=p.hobt_id 
    and b.database_id=db_id()
group by p.object_id,p.index_id 
order by buffer_pages desc 

select OBJECT_NAME(object_id) 表名,COUNT(*) 页数,COUNT(*)*8/1024.0 Mb                            
from   sys.dm_os_buffer_descriptors a,sys.allocation_units b,sys.partitions c                            
where  a.allocation_unit_id=b.allocation_unit_id 
       and b.container_id=c.hobt_id           
       and database_id=DB_ID()                            
group by OBJECT_NAME(object_id)                         
order by 2 desc

-- 查询缓存的各类执行计划，及分别占了多少内存
-- 可以对比动态查询与参数化SQL（预定义语句）的缓存量
select    cacheobjtype
,objtype
,sum(cast(size_in_bytes as bigint))/1024 as size_in_kb
,count(bucketid) as cache_count
from    sys.dm_exec_cached_plans
group by cacheobjtype, objtype
order by cacheobjtype, objtype


-- 查询缓存中具体的执行计划，及对应的SQL
-- 将此结果按照数据表或SQL进行统计，可以作为基线，调整索引时考虑
-- 查询结果会很大，注意将结果集输出到表或文件中
SELECT  usecounts ,
        refcounts ,
        size_in_bytes ,
        cacheobjtype ,
        objtype ,
        TEXT
FROM    sys.dm_exec_cached_plans cp
        CROSS APPLY sys.dm_exec_sql_text(plan_handle)
ORDER BY objtype DESC ;
GO


-- 执行中的sql，根据 start_time和wait_type可大致判断执行语句是否被锁住了
SELECT  [Spid] = session_Id, ecid, [Database] = DB_NAME(sp.dbid),
[User] = nt_username,[Status] = er.status,start_time,[Wait] = wait_type, 
[Individual Query] = SUBSTRING(qt.text, er.statement_start_offset / 2, (CASE WHEN er.statement_end_offset = - 1 THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 ELSE er.statement_end_offset END - er.statement_start_offset) / 2),                       
[Parent Query] = qt.text,                       
Program = program_name, Hostname,nt_domain
FROM  sys.dm_exec_requests er 
INNER JOIN  sys.sysprocesses sp ON er.session_id = sp.spid  
CROSS APPLY sys.dm_exec_sql_text(er.sql_handle) AS qt 
WHERE     session_Id > 50 /* Ignore system spids.*/ AND session_Id NOT IN (@@SPID)
--where sp.spid=249

-- 查询锁
 select spid 进程,STATUS 状态, 登录帐号=SUBSTRING(SUSER_SNAME(sid),1,30)
,用户机器名称=SUBSTRING(hostname,1,12)
,是否被锁住=convert(char(3),blocked)
,数据库名称=SUBSTRING(db_name(dbid),1,20),cmd 命令,waittype as 等待类型
,last_batch 最后批处理时间,open_tran 未提交事务的数量
from master.sys.sysprocesses
Where  status='sleeping' and waittype=0x0000 and open_tran>0
