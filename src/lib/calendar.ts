import { execFile } from 'child_process';
import { promisify } from 'util';
import { resolve } from 'path';
import { logger } from './logger';
import type { CalendarEvent, CalendarLookupResult } from '../types';

const execFileAsync = promisify(execFile);

const CALENDAR_CLI_PATH = resolve(__dirname, '../../SeleneChat/.build/release/selene-calendar');

/**
 * Query Apple Calendar for events around a timestamp.
 * Best-effort: returns null on any failure.
 */
export async function queryCalendar(timestamp: string): Promise<CalendarLookupResult | null> {
  try {
    const { stdout, stderr } = await execFileAsync(CALENDAR_CLI_PATH, ['--at', timestamp], {
      timeout: 5000,
    });

    if (stderr) {
      logger.warn({ stderr }, 'selene-calendar stderr output');
    }

    const result: CalendarLookupResult = JSON.parse(stdout);
    return result;
  } catch (err) {
    logger.warn({ err, timestamp }, 'Calendar lookup failed (best-effort, continuing)');
    return null;
  }
}

/**
 * Pick the best matching event from a list.
 * Prefers shorter events (more specific) over longer ones.
 */
export function pickBestEvent(events: CalendarEvent[]): CalendarEvent | null {
  if (events.length === 0) return null;

  const timed = events.filter(e => !e.isAllDay);
  if (timed.length === 0) return null;

  return timed.sort((a, b) => {
    const durationA = new Date(a.endDate).getTime() - new Date(a.startDate).getTime();
    const durationB = new Date(b.endDate).getTime() - new Date(b.startDate).getTime();
    return durationA - durationB;
  })[0];
}
