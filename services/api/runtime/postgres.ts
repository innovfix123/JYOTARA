import { Pool, types, type PoolClient } from 'pg';

// Millisecond timestamps and counts are stored as bigint. Never silently round.
types.setTypeParser(20, value => {
  const number = Number(value);
  if (!Number.isSafeInteger(number)) throw new Error('Database integer exceeds safe range');
  return number;
});

/** Compatibility for the application's fixed, parameterized SQL only.
 * Request data is always bound separately; this is not a general SQL parser. */
export function postgresSql(source: string) {
  let index = 0;
  let sql = source.replace(/`([a-z_]+)`/gi, '"$1"')
    .replace(/'(?:''|[^'])*'|\?/g, token => token === '?' ? `$${++index}` : token)
    .replace(/\bAS (factsJson|birthTimeKnown|createdAt)\b/g, 'AS "$1"')
    .replace('MAX(expires_at, excluded.expires_at)', 'GREATEST(deleted_chart_sessions.expires_at, excluded.expires_at)');
  if (/\bINSERT OR IGNORE\b/i.test(sql)) {
    sql = sql.replace(/\bINSERT OR IGNORE\b/i, 'INSERT').replace(/;\s*$/, '') + ' ON CONFLICT DO NOTHING';
  }
  return sql;
}

export class PostgresDatabase {
  readonly pool: Pool;
  constructor(connectionString: string) {
    this.pool = new Pool({ connectionString, max: 10, connectionTimeoutMillis: 5000,
      idleTimeoutMillis: 30000, statement_timeout: 10000 });
    this.pool.on('error', () => console.error('Database idle connection failed'));
  }
  prepare(sql: string) { return new Statement(this, sql); }
  async transaction<T>(operation: (client: PoolClient) => Promise<T>) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      // Preserve SQLite's serial write semantics for budget predicates and
      // deletion/reservation races across processes. No provider/model calls
      // occur inside this short transaction. Throughput must be load-tested.
      await client.query('SELECT pg_advisory_xact_lock(741920618)');
      const result = await operation(client);
      await client.query('COMMIT');
      return result;
    } catch (error) {
      await client.query('ROLLBACK').catch(() => undefined);
      throw error;
    } finally { client.release(); }
  }
  async batch(statements: Statement[]) {
    if (statements.some(s => s.database !== this)) throw new Error('Mixed database batch');
    return this.transaction(async client => {
      const result = [];
      for (const statement of statements) result.push(await statement.execute(client));
      return result;
    });
  }
  async close() { await this.pool.end(); }
}

class Statement {
  constructor(readonly database: PostgresDatabase, readonly sql: string, readonly values: unknown[] = []) {}
  bind(...values: unknown[]) { return new Statement(this.database, this.sql, values); }
  async execute(client: PoolClient) {
    const result = await client.query(postgresSql(this.sql), this.values);
    return { success: true, results: result.rows, meta: { changes: result.rowCount ?? 0 } };
  }
  async run() { return this.database.transaction(client => this.execute(client)); }
  async first<T>(column?: string): Promise<T | null> {
    const result = await this.database.pool.query(postgresSql(this.sql), this.values);
    const row = result.rows[0];
    return row ? (column ? row[column] : row) as T : null;
  }
  async all<T>() {
    const result = await this.database.pool.query(postgresSql(this.sql), this.values);
    return { success: true, results: result.rows as T[], meta: { changes: 0 } };
  }
}
