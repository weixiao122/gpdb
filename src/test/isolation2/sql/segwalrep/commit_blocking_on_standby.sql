--
-- Master/standby commit blocking scenarios.  These are different from
-- primary/mirror commit blocking because there is no FTS or a
-- third-party as external arbiter in case of master/standby.
--
-- Scenario1: Commits should block until standby confirms WAL flush
-- upto commit LSN.

-- Check that are starting with a clean slate, standby must be in sync
-- with master.
select application_name, state, sync_state from pg_stat_replication;

-- Inject fault on standby to skip WAL flush.
select gp_inject_fault_infinite2('walrecv_skip_flush', 'skip', dbid, hostname, port)
from gp_segment_configuration where content=-1 and role='m';

-- Should block in commit (SyncrepWaitForLSN()), waiting for commit
-- LSN to be flushed on standby.
1&: create table commit_blocking_on_standby_t1 (a int) distributed by (a);

select gp_wait_until_triggered_fault2('walrecv_skip_flush', 1, dbid, hostname, port)
from gp_segment_configuration where content=-1 and role='m';

-- The create table command should be seen as blocked.
select datname, waiting_reason, query from pg_stat_activity
where waiting_reason = 'replication';

select gp_inject_fault2('walrecv_skip_flush', 'reset', dbid, hostname, port)
from gp_segment_configuration where content=-1 and role='m';

-- Ensure that commits are no longer blocked.
create table commit_blocking_on_standby_t2 (a int) distributed by (a);

1<:

-- The blocked commit must have finished and the table should be ready
-- for insert.
insert into commit_blocking_on_standby_t1 values (1);