import { existsSync, mkdirSync, readFileSync, writeFileSync, readdirSync, statSync, copyFileSync, unlinkSync } from 'fs';
import { join } from 'path';
import { execSync } from 'child_process';
import { createWorkflowLogger, config } from '../lib';
import type { ProcessedManifest, ProcessedFileEntry, VoiceMemoWorkflowResult } from '../types';

const log = createWorkflowLogger('transcribe-voice-memos');

const MANIFEST_FILENAME = '.processed.json';
const MIN_FILE_SIZE_BYTES = 1024; // 1KB - files smaller than this are likely not ready
const FILE_SETTLE_SECONDS = 5; // Skip files modified within the last N seconds
const WHISPER_TIMEOUT_MS = 10 * 60 * 1000; // 10 minutes

// ---------------------------------------------------------------------------
// macOS notification helper
// ---------------------------------------------------------------------------

function sendNotification(title: string, message: string): void {
  try {
    // Escape for AppleScript string (backslash and double-quote)
    const escapeAS = (s: string): string => s.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
    execSync(
      `osascript -e 'display notification "${escapeAS(message)}" with title "${escapeAS(title)}"'`
    );
  } catch {
    log.warn({ title, message }, 'Failed to send macOS notification');
  }
}

// ---------------------------------------------------------------------------
// Manifest management
// ---------------------------------------------------------------------------

function manifestPath(): string {
  return join(config.voiceMemosOutputDir, MANIFEST_FILENAME);
}

function loadManifest(): ProcessedManifest {
  const path = manifestPath();
  if (!existsSync(path)) {
    log.info('No existing manifest found, starting fresh');
    return { files: {} };
  }

  try {
    const raw = readFileSync(path, 'utf-8');
    const parsed = JSON.parse(raw) as ProcessedManifest;
    if (!parsed.files || typeof parsed.files !== 'object') {
      log.warn('Manifest missing "files" key, starting fresh');
      return { files: {} };
    }
    return parsed;
  } catch (err) {
    const error = err as Error;
    log.warn({ err: error }, 'Corrupt manifest file, starting fresh');
    return { files: {} };
  }
}

function saveManifest(manifest: ProcessedManifest): void {
  const dir = config.voiceMemosOutputDir;
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }
  writeFileSync(manifestPath(), JSON.stringify(manifest, null, 2));
}

// ---------------------------------------------------------------------------
// Preflight checks
// ---------------------------------------------------------------------------

function preflightChecks(): boolean {
  let ok = true;

  if (!existsSync(config.whisperBinary)) {
    const msg = `whisper.cpp binary not found at ${config.whisperBinary}`;
    log.error(msg);
    sendNotification('Selene Voice Memos', msg);
    ok = false;
  }

  if (!existsSync(config.whisperModel)) {
    const msg = `Whisper model not found at ${config.whisperModel}`;
    log.error(msg);
    sendNotification('Selene Voice Memos', msg);
    ok = false;
  }

  try {
    execSync('which ffmpeg', { stdio: 'pipe' });
  } catch {
    const msg = 'ffmpeg not found in PATH';
    log.error(msg);
    sendNotification('Selene Voice Memos', msg);
    ok = false;
  }

  return ok;
}

// ---------------------------------------------------------------------------
// File scanning
// ---------------------------------------------------------------------------

interface NewMemoFile {
  filename: string;
  fullPath: string;
}

function scanForNewFiles(manifest: ProcessedManifest): NewMemoFile[] {
  const recordingsDir = config.voiceMemosRecordingsDir;

  if (!existsSync(recordingsDir)) {
    log.warn({ recordingsDir }, 'Recordings directory does not exist');
    return [];
  }

  const now = Date.now();
  const entries = readdirSync(recordingsDir);
  const newFiles: NewMemoFile[] = [];

  for (const entry of entries) {
    // Only process .m4a files
    if (!entry.toLowerCase().endsWith('.m4a')) continue;

    // Skip already-processed files
    if (manifest.files[entry]) continue;

    const fullPath = join(recordingsDir, entry);

    try {
      const stat = statSync(fullPath);

      // Skip files that are too small (still being recorded)
      if (stat.size < MIN_FILE_SIZE_BYTES) {
        log.debug({ filename: entry, size: stat.size }, 'Skipping file: too small');
        continue;
      }

      // Skip files modified too recently (still being written)
      const ageSeconds = (now - stat.mtimeMs) / 1000;
      if (ageSeconds < FILE_SETTLE_SECONDS) {
        log.debug({ filename: entry, ageSeconds }, 'Skipping file: modified too recently');
        continue;
      }

      newFiles.push({ filename: entry, fullPath });
    } catch (err) {
      const error = err as Error;
      log.warn({ filename: entry, err: error }, 'Failed to stat file, skipping');
    }
  }

  return newFiles;
}

// ---------------------------------------------------------------------------
// Filename parsing
// ---------------------------------------------------------------------------

interface ParsedMemoName {
  date: string; // e.g. "2026-02-12"
  time: string; // e.g. "15:30:45"
  friendlyName: string; // e.g. "2026-02-12 15:30"
  filePrefix: string; // e.g. "2026-02-12-153045" (for output filenames)
}

function parseMemoFilename(filename: string): ParsedMemoName {
  // Voice Memos format: "20260212 153045.m4a" or "20260212 153045-HEXID.m4a"
  const match = filename.match(/^(\d{4})(\d{2})(\d{2})\s+(\d{2})(\d{2})(\d{2})(?:-[A-Fa-f0-9]+)?\.m4a$/);

  if (match) {
    const [, year, month, day, hour, minute, second] = match;
    return {
      date: `${year}-${month}-${day}`,
      time: `${hour}:${minute}:${second}`,
      friendlyName: `${year}-${month}-${day} ${hour}:${minute}`,
      filePrefix: `${year}-${month}-${day}-${hour}${minute}${second}`,
    };
  }

  // Fallback for unexpected naming: use current timestamp
  const now = new Date();
  const y = now.getFullYear();
  const mo = String(now.getMonth() + 1).padStart(2, '0');
  const d = String(now.getDate()).padStart(2, '0');
  const h = String(now.getHours()).padStart(2, '0');
  const mi = String(now.getMinutes()).padStart(2, '0');
  const s = String(now.getSeconds()).padStart(2, '0');
  const baseName = filename.replace(/\.m4a$/i, '');

  return {
    date: `${y}-${mo}-${d}`,
    time: `${h}:${mi}:${s}`,
    friendlyName: baseName,
    filePrefix: `${y}-${mo}-${d}-${h}${mi}${s}`,
  };
}

// ---------------------------------------------------------------------------
// Audio helpers
// ---------------------------------------------------------------------------

function convertToWav(inputPath: string, outputPath: string): void {
  execSync(
    `ffmpeg -i "${inputPath}" -ar 16000 -ac 1 -c:a pcm_s16le "${outputPath}" -y`,
    { stdio: 'pipe' }
  );
}

function transcribeWav(wavPath: string): string {
  const output = execSync(
    `"${config.whisperBinary}" -m "${config.whisperModel}" -f "${wavPath}" --no-timestamps -t ${config.whisperThreads} -l en`,
    { stdio: 'pipe', timeout: WHISPER_TIMEOUT_MS }
  );
  return output.toString().trim();
}

function getAudioDuration(filePath: string): string {
  try {
    const output = execSync(
      `ffprobe -v error -show_entries format=duration -of csv=p=0 "${filePath}"`,
      { stdio: 'pipe' }
    );
    const totalSeconds = Math.round(parseFloat(output.toString().trim()));
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}m ${seconds}s`;
  } catch {
    return 'unknown';
  }
}

// ---------------------------------------------------------------------------
// Selene webhook ingestion
// ---------------------------------------------------------------------------

async function ingestToSelene(title: string, content: string): Promise<boolean> {
  try {
    const response = await fetch(config.seleneWebhookUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        title,
        content,
        tags: ['voice-memo'],
        source: 'voice-memos',
      }),
    });

    if (!response.ok) {
      log.warn({ status: response.status, statusText: response.statusText }, 'Webhook returned non-OK status');
      return false;
    }

    const result = await response.json() as { status: string; id?: number };
    log.info({ status: result.status, id: result.id }, 'Ingested to Selene');
    return true;
  } catch (err) {
    const error = err as Error;
    log.warn({ err: error }, 'Failed to POST to Selene webhook');
    return false;
  }
}

// ---------------------------------------------------------------------------
// Process a single voice memo
// ---------------------------------------------------------------------------

async function processMemo(
  memo: NewMemoFile,
  manifest: ProcessedManifest
): Promise<{ success: boolean; error?: string }> {
  const { filename, fullPath } = memo;
  log.info({ filename }, 'Processing voice memo');

  const parsed = parseMemoFilename(filename);
  const outputDir = config.voiceMemosOutputDir;
  const archiveDir = join(outputDir, 'archive');
  const transcriptsDir = join(outputDir, 'transcripts');

  // Ensure output directories exist
  mkdirSync(archiveDir, { recursive: true });
  mkdirSync(transcriptsDir, { recursive: true });

  // Temp WAV path
  const wavPath = join(outputDir, `_temp_${parsed.filePrefix}.wav`);

  try {
    // Step 1: Convert to WAV
    log.info({ filename }, 'Converting to WAV');
    convertToWav(fullPath, wavPath);

    // Step 2: Transcribe
    log.info({ filename }, 'Transcribing with whisper.cpp');
    const transcription = transcribeWav(wavPath);

    if (!transcription) {
      log.warn({ filename }, 'Empty transcription result');
    }

    // Step 3: Get audio duration
    const duration = getAudioDuration(fullPath);

    // Step 4: Archive original
    const archivePath = join(archiveDir, `${parsed.filePrefix}.m4a`);
    copyFileSync(fullPath, archivePath);
    log.info({ filename, archivePath }, 'Archived original');

    // Step 5: Write markdown transcript
    const markdownPath = join(transcriptsDir, `${parsed.filePrefix}.md`);
    const relativeArchivePath = `../archive/${parsed.filePrefix}.m4a`;
    const markdown = `# Voice Memo: ${parsed.friendlyName}

**Recorded:** ${parsed.date} ${parsed.time}
**Duration:** ${duration}
**Audio:** [Original recording](${relativeArchivePath})

---

${transcription}
`;
    writeFileSync(markdownPath, markdown);
    log.info({ markdownPath }, 'Transcript written');

    // Step 6: Ingest to Selene
    const title = `Voice Memo ${parsed.friendlyName}`;
    const ingested = await ingestToSelene(title, transcription);

    // Step 7: Update manifest
    const entry: ProcessedFileEntry = {
      transcribedAt: new Date().toISOString(),
      archivedTo: archivePath,
      markdownPath,
      ingestedToSelene: ingested,
    };
    manifest.files[filename] = entry;
    saveManifest(manifest);

    // Step 8: Clean up temp WAV
    try {
      unlinkSync(wavPath);
    } catch {
      log.warn({ wavPath }, 'Failed to clean up temp WAV');
    }

    log.info({ filename, ingested }, 'Voice memo processed successfully');
    return { success: true };
  } catch (err) {
    const error = err as Error;

    // Clean up temp WAV on failure
    try {
      if (existsSync(wavPath)) unlinkSync(wavPath);
    } catch {
      // ignore cleanup errors
    }

    throw error;
  }
}

// ---------------------------------------------------------------------------
// Retry failed ingestions
// ---------------------------------------------------------------------------

async function retryFailedIngestions(manifest: ProcessedManifest): Promise<number> {
  let retried = 0;

  for (const [filename, entry] of Object.entries(manifest.files)) {
    if (entry.ingestedToSelene) continue;

    log.info({ filename }, 'Retrying failed Selene ingestion');

    // Read the transcript markdown to extract the transcription text
    try {
      if (!existsSync(entry.markdownPath)) {
        log.warn({ filename, markdownPath: entry.markdownPath }, 'Transcript file missing, cannot retry');
        continue;
      }

      const markdown = readFileSync(entry.markdownPath, 'utf-8');
      // Extract content after the "---" separator
      const parts = markdown.split('\n---\n');
      const transcription = parts.length > 1 ? parts.slice(1).join('\n---\n').trim() : markdown;

      const parsed = parseMemoFilename(filename);
      const title = `Voice Memo ${parsed.friendlyName}`;

      const ingested = await ingestToSelene(title, transcription);
      if (ingested) {
        entry.ingestedToSelene = true;
        saveManifest(manifest);
        retried++;
        log.info({ filename }, 'Retry successful');
      }
    } catch (err) {
      const error = err as Error;
      log.warn({ filename, err: error }, 'Retry failed');
    }
  }

  return retried;
}

// ---------------------------------------------------------------------------
// Main workflow
// ---------------------------------------------------------------------------

export async function transcribeVoiceMemos(): Promise<VoiceMemoWorkflowResult> {
  log.info('Starting voice memo transcription workflow');

  const result: VoiceMemoWorkflowResult = {
    processed: 0,
    errors: 0,
    retried: 0,
    details: [],
  };

  // Preflight checks
  if (!preflightChecks()) {
    log.error('Preflight checks failed, aborting');
    return result;
  }

  // Load manifest
  const manifest = loadManifest();
  const processedCount = Object.keys(manifest.files).length;
  log.info({ processedCount }, 'Manifest loaded');

  // Scan for new files
  const newFiles = scanForNewFiles(manifest);
  log.info({ newFileCount: newFiles.length }, 'Scanned for new voice memos');

  // Process each new file
  for (const memo of newFiles) {
    try {
      const fileResult = await processMemo(memo, manifest);
      result.processed++;
      result.details.push({ filename: memo.filename, success: fileResult.success });
    } catch (err) {
      const error = err as Error;
      log.error({ filename: memo.filename, err: error }, 'Failed to process voice memo');
      sendNotification('Selene Voice Memos', `Failed to transcribe ${memo.filename}: ${error.message}`);
      result.errors++;
      result.details.push({ filename: memo.filename, success: false, error: error.message });
    }
  }

  // Retry failed ingestions
  result.retried = await retryFailedIngestions(manifest);

  log.info(
    { processed: result.processed, errors: result.errors, retried: result.retried },
    'Voice memo transcription workflow complete'
  );

  return result;
}

// CLI entry point
if (require.main === module) {
  transcribeVoiceMemos()
    .then((result) => {
      console.log('Voice memo transcription complete:', result);
      process.exit(result.errors > 0 ? 1 : 0);
    })
    .catch((err) => {
      console.error('Voice memo transcription failed:', err);
      process.exit(1);
    });
}
