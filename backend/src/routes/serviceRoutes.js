import express from 'express';
import { getServices, getServiceById } from '../controllers/serviceController.js';

const router = express.Router();

// Public routes - no auth required
router.get('/', getServices);
router.get('/:id', getServiceById);

export default router;
