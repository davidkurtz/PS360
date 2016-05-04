REM pstopaecomp.sql
DEF recname = 'BAT_TIMINGS_DTL'
@@psrecdefn
DEF lrecname = '&&lrecname._comp&&date_filter_suffix'
DEF recdescr = '&&recdescr. Application Engine steps profiled by compile time &&date_filter_desc'
DEF descrlong = 'Application Engine steps, aggregated by step and profiled by compilation timing &&date_filter_desc'
DEF report_abstract_2 = '<br>Requires batch timings to be written to database - set TraceAE=1024 in Process Scheduler configuration';
DEF report_abstract_3 = '<br>Steps with high compile times may be candidates for setting ReUseStatement';

BEGIN
  :sql_text_stub := '
WITH x AS (
SELECT l.process_instance, l.process_name
,      l.time_elapsed/1000 time_elapsed
,      l.enddttm-l.begindttm diffdttm
,      d.bat_program_name||''.''||d.detail_id detail_id
,      d.compile_count, GREATEST(0,d.compile_time)/1000 compile_time
,      d.execute_count, GREATEST(0,d.execute_time)/1000 execute_time
FROM   ps_bat_timings_dtl d
,      ps_bat_timings_log l
WHERE  d.process_instance = l.process_instance
AND    d.compile_count = d.execute_count 
AND    d.compile_count > 1 
AND    d.compile_time>=0 &&date_filter_sql
), y as (
SELECT x.*
,      GREATEST(0,60*(60*(24*EXTRACT(day FROM diffdttm)
                            +EXTRACT(hour FROM diffdttm))
                            +EXTRACT(minute FROM diffdttm))
                            +EXTRACT(second FROM diffdttm)-x.time_elapsed) delta 
FROM x
), z AS (
SELECT process_instance, process_name, detail_id
,      compile_count
,      execute_count
,      CASE WHEN time_elapsed < 0 THEN time_elapsed+delta  
            ELSE time_elapsed END time_elapsed
,      CASE WHEN compile_time < 0 THEN compile_time+delta
            ELSE compile_time END AS compile_time
,      CASE WHEN execute_time < 0 THEN execute_time+delta
            ELSE execute_time END AS execute_time
FROM y
), a AS (
SELECT detail_id
,      SUM(compile_time)+SUM(execute_time) step_time
,      SUM(compile_time) compile_time
,      SUM(compile_count) compile_count
,      SUM(execute_count) execute_count
,      COUNT(DISTINCT process_instance) processes
FROM   z
GROUP BY detail_id
), b AS (
SELECT row_number() over (ORDER BY compile_time DESC, step_time DESC, compile_count DESC) stmtrank
, a.* 
FROM a
WHERE compile_count >= &&threshold
)';
END;
/

COLUMN stmtrank        HEADING 'Stmt|Rank'        NEW_VALUE row_num
COLUMN processes       HEADING 'Number of|Process|Instances'
COLUMN process_name    HEADING 'Process|Name'
COLUMN detail_id       HEADING 'Statement ID'   
COLUMN step_time       HEADING 'Step|Secs' FORMAT 999990.00
COLUMN compile_time    HEADING 'Compile|Secs' FORMAT 999990.00
COLUMN compile_count   HEADING 'Compile|Count'
COLUMN execute_count   HEADING 'Execute|Count'

DEF piex="Statement ID"
DEF piey="Compile Time (seconds)"

BEGIN
  :sql_text := :sql_text_stub||'
SELECT '',[''''''||b.detail_id||'''''',''||b.compile_time||'']''
FROM   b
ORDER BY stmtrank'; 
END;				
/

REM DECODE(rownum,1,'''','','')||
@@psgenericpie.sql


BEGIN
  :sql_text := :sql_text_stub||'
SELECT b.*
FROM   b
ORDER BY stmtrank'; 
END;				
/

@@psgenerichtml.sql

