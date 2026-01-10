import pino from 'pino';
import { join } from 'path';
import { existsSync, mkdirSync } from 'fs';
import { config } from './config';

// Ensure logs directory exists
if (!existsSync(config.logsPath)) {
  mkdirSync(config.logsPath, { recursive: true });
}

const logFile = join(config.logsPath, 'selene.log');

// Create logger with console + file output
export const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  transport: {
    targets: [
      {
        target: 'pino-pretty',
        level: 'info',
        options: { colorize: true },
      },
      {
        target: 'pino/file',
        level: 'debug',
        options: { destination: logFile },
      },
    ],
  },
});

// Create child loggers per workflow
export function createWorkflowLogger(workflow: string) {
  return logger.child({ workflow });
}
