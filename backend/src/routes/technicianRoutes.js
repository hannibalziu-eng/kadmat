import express from 'express';
import { updateLocation, toggleStatus, getTechnicianProfile } from '../controllers/technicianController.js';
import authMiddleware from '../middleware/authMiddleware.js';

const router = express.Router();

router.use(authMiddleware);

router.post('/location', updateLocation);
router.post('/status', toggleStatus);
router.get('/:id', getTechnicianProfile);

export default router;
