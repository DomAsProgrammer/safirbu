-- enforce foreign keys
PRAGMA foreign_keys = ON;

-- AUTOINCREMENT
-- ...is not required. INT PKs use the ROWID if
-- availabe. The only difference is: AUTOINCREMENT sees any tried
-- id as used some time ago and prevents reuse for more database
-- integrety.

-- from job names
CREATE TABLE jobs (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  UNIQUE (name)
  );

CREATE TABLE backup_status (
  job_id INTEGER NOT NULL,
  inode INTEGER NOT NULL,
  mtime INTEGER NOT NULL,
  dirname VARCHAR(200) NOT NULL,
  "path" TEXT NOT NULL,
  successful BOOLEAN NOT NULL,
  PRIMARY KEY (job_id, inode),
  UNIQUE (job_id, dirname),
  FOREIGN KEY (job_id) REFERENCES jobs(id) ON UPDATE CASCADE ON DELETE CASCADE
  ) WITHOUT ROWID;

CREATE TABLE source_groups (
  id INTEGER PRIMARY KEY,
  name VARCHAR NOT NULL, -- hex
  UNIQUE (name)
  );

CREATE INDEX idx_source_group
  ON source_groups (name);

CREATE TABLE source_pathes (
  id INTEGER PRIMARY KEY,
  "path" TEXT NOT NULL,
  UNIQUE ("path")
  );

CREATE INDEX idx_source_path
  ON source_pathes ("path");

-- Dummy for full directory listing
INSERT INTO source_pathes ("path")
  VALUES ('NONE'); -- STR_DummyLocation - must not be changed!!

CREATE TABLE source_allocs (
  sgroup_id INTEGER NOT NULL,
  path_id INTEGER NOT NULL,
  job_id INTEGER NOT NULL,
  PRIMARY KEY (sgroup_id,path_id,job_id),
  FOREIGN KEY (sgroup_id) REFERENCES source_groups (id) ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (path_id) REFERENCES source_pathes (id) ON UPDATE CASCADE ON DELETE CASCADE
  FOREIGN KEY (job_id) REFERENCES jobs (id) ON UPDATE CASCADE ON DELETE CASCADE
  ) WITHOUT ROWID;

-- this are the size run times
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY,
  time INTEGER NOT NULL,
  job_id INTEGER NOT NULL,
  UNIQUE (time,job_id),
  FOREIGN KEY (job_id) REFERENCES jobs (id) ON UPDATE CASCADE ON DELETE CASCADE
  );

-- increase speed on time
CREATE INDEX idx_task_time
  ON tasks (time);

CREATE TABLE notations (
  id INTEGER PRIMARY KEY,
  notation TEXT NOT NULL,
  UNIQUE (notation)
  );

CREATE INDEX idx_notations
  ON notations (notation);

-- actual data
CREATE TABLE backups (
  id INTEGER PRIMARY KEY,
  inode INTEGER NOT NULL,
  mtime INTEGER NOT NULL,
  nid TEXT NOT NULL,
  spath_id INTEGER NOT NULL,
  elements INTEGER NOT NULL,
  size INTEGER NOT NULL,
  UNIQUE (inode,mtime,spath_id),
  UNIQUE (nid,spath_id),
  FOREIGN KEY (spath_id) REFERENCES source_pathes (id) ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (nid) REFERENCES notations (id) ON UPDATE CASCADE ON DELETE CASCADE
  );

CREATE INDEX idx_backup_mtime_inode
  ON backups (inode,mtime);
CREATE INDEX idx_backup_notation
  ON backups (nid);

-- allocation table for m to n between tasks, backup, and notation (three dimensions)
CREATE TABLE mixed_alloc_delta (
  task_id INTEGER NOT NULL,
  backup_id INTEGER NOT NULL,
  delta_id INTEGER DEFAULT NULL,
  delta_size INTEGER DEFAULT NULL,
  PRIMARY KEY (task_id,backup_id),
  --UNIQUE (task_id,delta_id), -- Is no longer valid, since spath_id is part of backups table
  FOREIGN KEY (task_id) REFERENCES tasks (id) ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (backup_id) REFERENCES backups (id) ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (delta_id) REFERENCES backups (id) ON UPDATE CASCADE ON DELETE CASCADE
  ) WITHOUT ROWID;

-- increase speed on unique constraint
CREATE UNIQUE INDEX idx_allocation_unique
  ON mixed_alloc_delta (task_id,backup_id,delta_id);

-- increase speed on gathering all sizing tasks from a job
CREATE INDEX idx_task_id_index
  ON mixed_alloc_delta (task_id);

-- Join tables
CREATE VIEW complete AS
  SELECT
      jobs.id                             AS job_id,
      jobs.name                           AS job_name,
      tasks.id                            AS task_id,
      tasks.time                          AS task_time,
      backups.id                          AS backup_id,
      notations.notation                  AS notation,
      backups.inode                       AS backup_inode,
      backups.mtime                       AS backup_mtime,
      SUM(backups.size)                   AS backup_size,
      SUM(backups.elements)               AS backup_elements,
      CASE COUNT(*) WHEN COUNT(mixed_alloc_delta.delta_id) THEN mixed_alloc_delta.delta_id ELSE NULL           END AS delta_id,
      CASE COUNT(*) WHEN COUNT(mixed_alloc_delta.delta_size) THEN SUM(mixed_alloc_delta.delta_size) ELSE NULL  END AS delta_size,
      CASE COUNT(*) WHEN COUNT(deltas.inode) THEN deltas.inode ELSE NULL                                       END AS delta_inode,
      CASE COUNT(*) WHEN COUNT(deltas.mtime) THEN deltas.mtime ELSE NULL                                       END AS delta_mtime,
      source_groups.id                    AS sgroup_id,
      source_groups.name                  AS sgroup_name
    FROM jobs
    INNER JOIN tasks
      ON tasks.job_id = jobs.id
    INNER JOIN mixed_alloc_delta
      ON mixed_alloc_delta.task_id = tasks.id
    INNER JOIN backups
      ON mixed_alloc_delta.backup_id = backups.id
    INNER JOIN notations
      ON backups.nid = notations.id
    INNER JOIN (
      -- Unique pathes, especially for parents per group
      SELECT
        sp1.pid, sp1.gid, sp1.jid
      FROM (
        SELECT g.id gid, p."path", p.id pid, a.job_id jid
          FROM source_groups g
          INNER JOIN source_allocs a
            ON g.id = a.sgroup_id
          INNER JOIN source_pathes p
            ON a.path_id = p.id
        ) sp1
      LEFT JOIN (
        SELECT g.id gid, p."path", p.id pid, a.job_id jid
          FROM source_groups g
          INNER JOIN source_allocs a
            ON g.id = a.sgroup_id
          INNER JOIN source_pathes p
            ON a.path_id = p.id
        ) sp2
        ON sp1.gid = sp2.gid
        AND sp1.jid = sp2.jid
        AND ( sp1."path" LIKE sp2."path" || '%' OR sp2."path" LIKE sp1."path" || '%' )
        AND sp2."path" NOT LIKE sp1."path" || '%'
      WHERE sp2.pid IS NULL
      ) spathes
      ON backups.spath_id = spathes.pid
      AND jobs.id = spathes.jid
    INNER JOIN source_groups
      ON spathes.gid = source_groups.id
    INNER JOIN source_pathes sp
      ON spathes.pid = sp.id
    INNER JOIN ( -- Count how much pathes belong to each group
      SELECT g.id gid, COUNT(*) pathes
        FROM source_groups g
        INNER JOIN source_allocs a
          ON g.id = a.sgroup_id
        INNER JOIN source_pathes p
          ON a.path_id = p.id
        GROUP BY g.name, g.id
      ) gc -- Group Count
      ON source_groups.id = gc.gid 
    LEFT JOIN backups AS deltas
      ON mixed_alloc_delta.delta_id = deltas.id
  GROUP BY jobs.id, tasks.id, source_groups.id, notations.notation
    HAVING COUNT(sp.id) = gc.pathes -- Omit grouped lines, which make no sense for the source path groups
  ORDER BY jobs.name, tasks.time, source_groups.name, backups.mtime DESC;

