// Re-export database types
export { RawNote } from '../lib/db';

// Ingest workflow types
export interface IngestInput {
  title: string;
  content: string;
  created_at?: string;
  test_run?: string;
}

export interface IngestResult {
  id?: number;
  duplicate: boolean;
  existingId?: number;
}

// Webhook response types
export interface WebhookResponse {
  status: 'created' | 'duplicate' | 'error';
  id?: number;
  message?: string;
}

// Workflow result types
export interface WorkflowResult {
  processed: number;
  errors: number;
  details: Array<{ id: number; success: boolean; error?: string }>;
}
