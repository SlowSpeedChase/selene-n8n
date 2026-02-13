import { execSync } from 'child_process';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { join } from 'path';
import { createWorkflowLogger, config } from '../lib';

const log = createWorkflowLogger('send-digest');

function digestToHtml(digestText: string, date: string): string {
  const lines = digestText.split('\n').filter((l) => l.trim());
  const bodyHtml = lines.map((line) => `<p>${line}</p>`).join('\n');

  return `<h1>Selene Daily</h1>
<p style="color: #888; font-size: 14px;">Updated: ${date}</p>
<hr>
${bodyHtml}`;
}

function updateAppleNote(noteName: string, htmlBody: string): void {
  // Escape for AppleScript: backslashes, double quotes, backslash-n for newlines
  const escaped = htmlBody
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/\n/g, '\\n');

  const script = `osascript -e 'tell application "Notes"' \
    -e 'set noteName to "Selene Daily"' \
    -e 'set noteBody to "${escaped}"' \
    -e 'try' \
    -e 'set targetNote to first note whose name is noteName' \
    -e 'set body of targetNote to noteBody' \
    -e 'on error' \
    -e 'make new note with properties {name:noteName, body:noteBody}' \
    -e 'end try' \
    -e 'end tell'`;

  execSync(script, { timeout: 15000, stdio: 'pipe' });
}

export async function sendDigest(): Promise<{ sent: boolean; writtenToFile?: string }> {
  log.info({ env: config.env }, 'Starting send-digest');

  // In test mode, write to file instead of posting to Apple Notes
  if (config.isTestEnv) {
    return sendDigestToFile();
  }

  // Look for today's digest, fall back to yesterday's
  const today = new Date().toISOString().split('T')[0];
  const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];

  let digestPath = join(config.digestsPath, `${today}-digest.txt`);
  if (!existsSync(digestPath)) {
    digestPath = join(config.digestsPath, `${yesterday}-digest.txt`);
  }

  if (!existsSync(digestPath)) {
    log.info('No digest file found, skipping');
    return { sent: false };
  }

  const message = readFileSync(digestPath, 'utf-8').trim();
  if (!message) {
    log.info('Empty digest, skipping');
    return { sent: false };
  }

  try {
    const dateStr = new Date().toLocaleDateString('en-US', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
    const html = digestToHtml(message, dateStr);
    updateAppleNote('Selene Daily', html);
    log.info('Digest posted to Apple Notes');
    return { sent: true };
  } catch (err) {
    log.error({ err }, 'Failed to post digest to Apple Notes');
    return { sent: false };
  }
}

/**
 * Test mode: write digest to file instead of posting to Apple Notes
 */
async function sendDigestToFile(): Promise<{ sent: boolean; writtenToFile?: string }> {
  log.info('Test mode: writing digest to file instead of Apple Notes');

  // Look for today's digest, fall back to yesterday's
  const today = new Date().toISOString().split('T')[0];
  const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];

  let digestPath = join(config.digestsPath, `${today}-digest.txt`);
  if (!existsSync(digestPath)) {
    digestPath = join(config.digestsPath, `${yesterday}-digest.txt`);
  }

  if (!existsSync(digestPath)) {
    log.info('No digest file found, skipping');
    return { sent: false };
  }

  const message = readFileSync(digestPath, 'utf-8').trim();
  if (!message) {
    log.info('Empty digest, skipping');
    return { sent: false };
  }

  // Write to sent-digests subdirectory
  const sentDir = join(config.digestsPath, 'sent');
  mkdirSync(sentDir, { recursive: true });

  const sentPath = join(sentDir, `${today}-sent.txt`);
  const fullMessage = `🌅 Selene Daily Digest\n\n${message}`;
  writeFileSync(sentPath, fullMessage);

  log.info({ path: sentPath }, 'Digest written to file (test mode)');
  return { sent: true, writtenToFile: sentPath };
}

// CLI entry point
if (require.main === module) {
  sendDigest()
    .then((result) => {
      console.log('Send digest complete:', result);
      process.exit(0);
    })
    .catch((err) => {
      console.error('Send digest failed:', err);
      process.exit(1);
    });
}
