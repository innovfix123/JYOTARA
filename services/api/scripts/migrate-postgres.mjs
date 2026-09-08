import { Pool } from 'pg';
import { readFile, readdir, realpath } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';

export async function migrate(pool) {
  const directory = new URL('../drizzle/', import.meta.url);
  const files = (await readdir(directory)).filter(name => /^\d+_.*\.sql$/.test(name)).sort();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT pg_advisory_xact_lock(741920618)');
    await client.query('CREATE TABLE IF NOT EXISTS jyotara_migrations (name text PRIMARY KEY, checksum text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now())');
    for (const name of files) {
      const original = await readFile(new URL(name, directory), 'utf8');
      const checksum = createHash('sha256').update(original).digest('hex');
      const prior = await client.query('SELECT checksum FROM jyotara_migrations WHERE name = $1', [name]);
      if (prior.rowCount) {
        if (prior.rows[0].checksum !== checksum) throw new Error('Applied migration was changed');
        continue;
      }
      // The checked-in migrations use portable CREATE/ALTER/INDEX statements.
      // bigint preserves existing epoch-millisecond values on PostgreSQL.
      const sql = original.replace(/`([a-z_]+)`/gi, '"$1"').replace(/\binteger\b/gi, 'bigint');
      await client.query(sql);
      await client.query('INSERT INTO jyotara_migrations (name, checksum) VALUES ($1, $2)', [name, checksum]);
    }
    await client.query('COMMIT');
    return files.length;
  } catch (error) {
    await client.query('ROLLBACK').catch(() => undefined);
    throw error;
  } finally { client.release(); }
}

if (process.argv[1] && import.meta.url === pathToFileURL(await realpath(process.argv[1])).href) {
  if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');
  const pool = new Pool({ connectionString: process.env.DATABASE_URL, max: 1 });
  try { console.log(`Verified ${await migrate(pool)} database migrations`); }
  catch { console.error('Database migration failed; no partial migration was committed.'); process.exitCode = 1; }
  finally { await pool.end(); }
}
