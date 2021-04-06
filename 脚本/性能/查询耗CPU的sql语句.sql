
-- 查看运行语句的CPU情况
SELECT  DB_NAME(sp.dbid) as db_name, --数据库名称
		sp.cpu,-- 进程的累计cpu时间
		er.cpu_time,--请求所使用的 CPU 时间
		sp.physical_io,
		er.wait_time,
        qt.text ,
        er.status , --运行状态 Background，Running，Runnable，Sleeping，Suspended
		session_id , -- 与此请求相关的会话的 ID	
        er.start_time
FROM    sys.dm_exec_requests er
        INNER JOIN sys.sysprocesses sp ON er.session_id = sp.spid
        CROSS APPLY sys.dm_exec_sql_text(er.sql_handle) AS qt
WHERE   session_id > 50 -- Ignore system spids.
        AND session_id NOT IN ( @@SPID ) -- Ignore this current statement.
ORDER BY  sp.cpu desc,start_time desc


-- =============================================
-- Create date: <2014/4/18>
-- Description: ²éÑ¯ºÄCPUµÄsqlÓï¾ä
-- =============================================



SELECT  t.[text] ,
        db_name(p.dbid) dbname,
        p.*
FROM    sys.sysprocesses p
        CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS T
WHERE   p.spid > 49
ORDER BY cpu  desc


--查询编译以来 cpu耗时总量最多的前50条(Total_woker_time)
SELECT TOP 50
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
