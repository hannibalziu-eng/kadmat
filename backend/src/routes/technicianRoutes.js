import express from 'express';
import { updateLocation, toggleStatus } from '../controllers/technicianController.js';
import authMiddleware from '../middleware/authMiddleware.js';

const router = express.Router();

router.use(authMiddleware);

router.post('/location', updateLocation);
router.post('/status', toggleStatus);

export default router;
