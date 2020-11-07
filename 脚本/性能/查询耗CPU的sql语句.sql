
-- 查看运行语句的CPU情况
SELECT  DB_NAME(sp.dbid) as db_name, --数据库名称
		sp.cpu,
		er.cpu_time,
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
