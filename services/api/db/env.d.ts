declare namespace Cloudflare {
  interface Env {
    DB: D1Database;
    JYOTARA_QUESTION_LIMIT?: string;
    PROKERALA_CLIENT_ID?: string;
    PROKERALA_CLIENT_SECRET?: string;
    PROKERALA_ENVIRONMENT?: 'test' | 'production';
    OPENAI_API_KEY?: string;
    OPENAI_MODEL?: string;
    OPENROUTER_API_KEY?: string;
    JYOTARA_CHART_TICKET_KEY?: string;
    NIRAYANA_CHART_TICKET_KEY?: string;
    OPENROUTER_MODEL?: string;
  }
}
