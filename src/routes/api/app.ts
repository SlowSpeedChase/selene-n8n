import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import path from 'path';
import fs from 'fs';
import { execSync } from 'child_process';
import { config } from '../../lib/config';
import { logger } from '../../lib/logger';

const APP_DIR = path.join(config.projectRoot, 'build');
const APP_BUNDLE_NAME = 'SeleneChat.app';
const APP_ZIP_NAME = 'SeleneChat.zip';

/**
 * App distribution routes for client updates
 */
export async function appRoutes(fastify: FastifyInstance): Promise<void> {
  /**
   * GET /api/app/version
   * Returns the current app version info
   */
  fastify.get('/api/app/version', async (_request: FastifyRequest, reply: FastifyReply) => {
    try {
      const infoPlistPath = path.join(APP_DIR, APP_BUNDLE_NAME, 'Contents', 'Info.plist');

      if (!fs.existsSync(infoPlistPath)) {
        return reply.status(404).send({
          error: 'App bundle not found',
          message: 'Run scripts/build-selenechat-release.sh first',
        });
      }

      // Read Info.plist to get version (simple parsing)
      const infoPlist = fs.readFileSync(infoPlistPath, 'utf-8');

      // Extract version using regex
      const versionMatch = infoPlist.match(/<key>CFBundleShortVersionString<\/key>\s*<string>([^<]+)<\/string>/);
      const buildMatch = infoPlist.match(/<key>CFBundleVersion<\/key>\s*<string>([^<]+)<\/string>/);

      const version = versionMatch ? versionMatch[1] : 'unknown';
      const build = buildMatch ? buildMatch[1] : 'unknown';

      // Get app bundle modification time
      const stats = fs.statSync(path.join(APP_DIR, APP_BUNDLE_NAME));
      const buildDate = stats.mtime.toISOString();

      return reply.send({
        version,
        build,
        buildDate,
        downloadUrl: '/api/app/download',
      });
    } catch (error) {
      logger.error({ error }, 'Failed to get app version');
      return reply.status(500).send({
        error: 'Failed to get app version',
        message: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  });

  /**
   * GET /api/app/download
   * Downloads the app bundle as a zip file
   */
  fastify.get('/api/app/download', async (_request: FastifyRequest, reply: FastifyReply) => {
    try {
      const appBundlePath = path.join(APP_DIR, APP_BUNDLE_NAME);
      const zipPath = path.join(APP_DIR, APP_ZIP_NAME);

      if (!fs.existsSync(appBundlePath)) {
        return reply.status(404).send({
          error: 'App bundle not found',
          message: 'Run scripts/build-selenechat-release.sh first',
        });
      }

      // Create/update zip file if app bundle is newer or zip doesn't exist
      const shouldZip =
        !fs.existsSync(zipPath) ||
        fs.statSync(appBundlePath).mtime > fs.statSync(zipPath).mtime;

      if (shouldZip) {
        logger.info('Creating zip archive of app bundle...');
        // Remove old zip if exists
        if (fs.existsSync(zipPath)) {
          fs.unlinkSync(zipPath);
        }

        // Create zip (using ditto for proper macOS app bundle preservation)
        execSync(`cd "${APP_DIR}" && ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE_NAME}" "${APP_ZIP_NAME}"`, {
          stdio: 'inherit',
        });

        logger.info('Zip archive created');
      }

      // Get file stats for Content-Length
      const stats = fs.statSync(zipPath);

      // Send the file
      reply.header('Content-Type', 'application/zip');
      reply.header('Content-Disposition', `attachment; filename="${APP_ZIP_NAME}"`);
      reply.header('Content-Length', stats.size);

      const stream = fs.createReadStream(zipPath);
      return reply.send(stream);
    } catch (error) {
      logger.error({ error }, 'Failed to serve app download');
      return reply.status(500).send({
        error: 'Failed to serve app download',
        message: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  });

  /**
   * POST /api/app/build (optional - trigger rebuild)
   * Triggers a new release build
   */
  fastify.post('/api/app/build', async (_request: FastifyRequest, reply: FastifyReply) => {
    try {
      const buildScript = path.join(config.projectRoot, 'scripts', 'build-selenechat-release.sh');

      if (!fs.existsSync(buildScript)) {
        return reply.status(404).send({
          error: 'Build script not found',
        });
      }

      logger.info('Triggering app build...');
      execSync(`bash "${buildScript}"`, {
        cwd: config.projectRoot,
        stdio: 'inherit',
      });

      logger.info('App build complete');
      return reply.send({
        success: true,
        message: 'Build complete',
      });
    } catch (error) {
      logger.error({ error }, 'Build failed');
      return reply.status(500).send({
        error: 'Build failed',
        message: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  });
}
