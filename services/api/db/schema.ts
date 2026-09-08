import { index, integer, sqliteTable, text, uniqueIndex } from 'drizzle-orm/sqlite-core';

// Anonymous capability revocation; no chart, birth details or question content.
export const deletedChartSessions = sqliteTable('deleted_chart_sessions', {
  sessionId: text('session_id').primaryKey(),
  expiresAt: integer('expires_at').notNull(),
});

// Public astronomical context only; no names, birth dates, questions or answers.
export const currentContextCache = sqliteTable('current_context_cache', {
  id: text('id').primaryKey(),
  dayKey: text('day_key').notNull(),
  status: text('status').notNull(),
  payloadJson: text('payload_json'),
  calculatedAt: integer('calculated_at').notNull(),
  expiresAt: integer('expires_at').notNull(),
}, table => [index('idx_current_context_day').on(table.dayKey), index('idx_current_context_expiry').on(table.expiresAt)]);

// Immutable calculation snapshots. Owner identity must come from verified auth,
// never a request body's ownerId or a client-selected cookie.
export const birthChartSnapshots = sqliteTable('birth_chart_snapshots', {
  id: text('id').primaryKey(),
  ownerId: text('owner_id').notNull(),
  profileId: text('profile_id').notNull(),
  factsJson: text('facts_json').notNull(),
  birthTimeKnown: integer('birth_time_known', { mode: 'boolean' }).notNull(),
  createdAt: integer('created_at').notNull(),
}, table => [index('idx_birth_chart_snapshots_owner_profile').on(table.ownerId, table.profileId)]);

// Operational single-use guard only; no birth details or provider answers retained.
export const prokeralaAuditRuns = sqliteTable('prokerala_audit_runs', {
  id: text('id').primaryKey(),
  status: text('status').notNull(),
  createdAt: integer('created_at').notNull(),
  updatedAt: integer('updated_at').notNull(),
});

export const pilotEvents = sqliteTable(
  'pilot_events',
  {
    id: text('id').primaryKey(),
    sessionId: text('session_id').notNull(),
    eventType: text('event_type').notNull(),
    category: text('category'),
    language: text('language'),
    tradition: text('tradition'),
    helpful: integer('helpful', { mode: 'boolean' }),
    ageBand: text('age_band'),
    inputMode: text('input_mode'),
    acquisitionSource: text('acquisition_source'),
    createdAt: integer('created_at', { mode: 'timestamp' }).notNull(),
  },
  (table) => [
    index('idx_pilot_events_session').on(table.sessionId),
    index('idx_pilot_events_type_created').on(table.eventType, table.createdAt),
  ],
);

export const guideRequests = sqliteTable(
  'guide_requests',
  {
    id: text('id').primaryKey(),
    sessionId: text('session_id').notNull(),
    category: text('category').notNull(),
    language: text('language').notNull(),
    supportLevel: text('support_level').notNull(),
    answerMode: text('answer_mode').notNull(),
    questionText: text('question_text'),
    intent: text('intent'),
    researchConsentVersion: text('research_consent_version'),
    ageBand: text('age_band'),
    requestHash: text('request_hash'),
    responseCiphertext: text('response_ciphertext'),
    responseExpiresAt: integer('response_expires_at'),
    createdAt: integer('created_at', { mode: 'timestamp' }).notNull(),
  },
  (table) => [index('idx_guide_requests_session_created').on(table.sessionId, table.createdAt)],
);

export const profileGenerations = sqliteTable(
  'profile_generations',
  {
    id: text('id').primaryKey(),
    sessionId: text('session_id').notNull(),
    dayKey: text('day_key').notNull(),
    status: text('status').notNull(),
    credits: integer('credits').notNull().default(0),
    requestHash: text('request_hash'),
    responseCiphertext: text('response_ciphertext'),
    responseExpiresAt: integer('response_expires_at'),
    createdAt: integer('created_at', { mode: 'timestamp' }).notNull(),
    updatedAt: integer('updated_at', { mode: 'timestamp' }).notNull(),
  },
  (table) => [
    index('idx_profile_generations_day_status').on(table.dayKey, table.status),
    uniqueIndex('idx_profile_generations_session_day').on(table.sessionId, table.dayKey),
  ],
);
