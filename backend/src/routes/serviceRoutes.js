import express from 'express';
import { getServices, getServiceById, getServiceCatalogItems } from '../controllers/serviceController.js';

const router = express.Router();

// Public routes - no auth required
router.get('/', getServices);
router.get('/:id', getServiceById);
router.get('/:id/catalog-items', getServiceCatalogItems);

export default router;
