--执行下面的SQL语句就知道了(下面的语句可以在SQL Server 2005及后续版本中运行，用你的数据库名替换掉这里的AdventureWorks)：
--使用下面的规则分析结果，你就可以找出哪里发生了索引碎片：
--1)ExternalFragmentation的值>10表示对应的索引发生了外部碎片;
--2)InternalFragmentation的值<75表示对应的索引发生了内部碎片。
SELECT object_name(dt.object_id) Tablename,si.name as IndexName,dt.avg_fragmentation_in_percent AS ExternalFragmentation,dt.avg_page_space_used_in_percent AS InternalFragmentation
FROM　　(
　　SELECT object_id,index_id,avg_fragmentation_in_percent,avg_page_space_used_in_percent
　　FROM sys.dm_db_index_physical_stats (db_id('AdventureWorks'),null,null,null,'DETAILED'
) WHERE index_id <>0) AS dt 
INNER JOIN sys.indexes si ON si.object_id=dt.object_id
AND si.index_id=dt.index_id AND dt.avg_fragmentation_in_percent>10
AND dt.avg_page_space_used_in_percent<75
ORDER BY avg_fragmentation_in_percent DESC


--示例：
--显示数据库里所有索引的碎片信息
--SET NOCOUNT ON
--USE pubs
DBCC SHOWCONTIG WITH ALL_INDEXES
GO


--显示指定表的所有索引的碎片信息
--SET NOCOUNT ONUSE pubs
DBCC SHOWCONTIG (authors) WITH ALL_INDEXES
GO


--显示指定索引的碎片信息
--SET NOCOUNT ON
--USE pubs
DBCC SHOWCONTIG (authors,aunmind)
GO

--扫描页数：如果你知道行的近似尺寸和表或索引里的行数，那么你可以估计出索引里的页数。看看扫描页数，如果明显比你估计的页数要高，说明存在内部碎片。
--扫描扩展盘区数：用扫描页数除以8,四舍五入到下一个最高值。该值应该和DBCC SHOWCONTIG返回的扫描扩展盘区数一致。如果DBCC SHOWCONTIG返回的数高，说明存在外部碎片。碎片的严重程度依赖于刚才显示的值比估计值高多少。
--扩展盘区开关数：该数应该等于扫描扩展盘区数减1。高了则说明有外部碎片。
--每个扩展盘区上的平均页数：该数是扫描页数除以扫描扩展盘区数，一般是8。小于8说明有外部碎片。
--扫描密度［最佳值:实际值］：DBCC SHOWCONTIG返回最有用的一个百分比。这是扩展盘区的最佳值和实际值的比率。该百分比应该尽可能靠近100％。低了则说明有外部碎片。
--逻辑扫描碎片：无序页的百分比。该百分比应该在0％到10％之间，高了则说明有外部碎片。
--扩展盘区扫描碎片：无序扩展盘区在扫描索引叶级页中所占的百分比。该百分比应该是0％，高了则说明有外部碎片。
--每页上的平均可用字节数：所扫描的页上的平均可用字节数。越高说明有内部碎片，不过在你用这个数字决定是否有内部碎片之前，应该考虑fill factor（填充因子）。
--平均页密度（完整）：每页上的平均可用字节数的百分比的相反数。低的百分比说明有内部碎
