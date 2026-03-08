import dotenv from 'dotenv';
import logger from './utils/logger.js';
import { startSchedulerRuntime, stopSchedulerRuntime } from './jobs/schedulerRuntime.js';

dotenv.config();

function shutdown(signal) {
  logger.info(`🛑 Scheduler worker received ${signal}; shutting down...`);
  try {
    stopSchedulerRuntime();
  } finally {
    process.exit(0);
  }
}

startSchedulerRuntime({ includeFirebase: true });
logger.info('🧵 Scheduler worker started');

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
