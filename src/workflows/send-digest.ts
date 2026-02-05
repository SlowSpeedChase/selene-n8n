import { execSync } from 'child_process';
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import { createWorkflowLogger, config } from '../lib';

const log = createWorkflowLogger('send-digest');

function sendIMessage(to: string, message: string): void {
  // Escape for AppleScript string - use single quotes to avoid escaping
  const escaped = message.replace(/'/g, "'\"'\"'");

  const script = `osascript -e 'tell application "Messages" to send "${escaped}" to buddy "${to}"'`;

  try {
    execSync(script, {
      timeout: 10000,
      stdio: 'pipe',
    });
  } catch (err: any) {
    // If direct buddy send fails, try with phone/email format
    if (err.status !== 0) {
      const fallbackScript = `osascript -e 'tell application "Messages"' -e 'set targetService to 1st service whose service type = iMessage' -e 'set targetBuddy to buddy "${to}" of targetService' -e 'send "${escaped}" to targetBuddy' -e 'end tell'`;
      execSync(fallbackScript, {
        timeout: 10000,
        stdio: 'pipe',
      });
    } else {
      throw err;
    }
  }
}

export async function sendDigest(): Promise<{ sent: boolean }> {
  log.info('Starting send-digest');

  if (!config.imessageDigestEnabled) {
    log.info('iMessage digest disabled');
    return { sent: false };
  }

  if (!config.imessageDigestTo) {
    log.warn('IMESSAGE_DIGEST_TO not configured');
    return { sent: false };
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
    sendIMessage(config.imessageDigestTo, `🌅 Selene Daily Digest\n\n${message}`);
    log.info({ to: config.imessageDigestTo }, 'Digest sent via iMessage');
    return { sent: true };
  } catch (err) {
    log.error({ err }, 'Failed to send iMessage digest');
    return { sent: false };
  }
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
