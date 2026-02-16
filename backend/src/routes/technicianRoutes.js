import express from 'express';
import {
    updateLocation,
    toggleStatus,
    getTechnicianProfile,
    updateProfile,
    addPortfolioWork,
    deletePortfolioWork
} from '../controllers/technicianController.js';
import authMiddleware from '../middleware/authMiddleware.js';

const router = express.Router();

router.use(authMiddleware);

router.post('/location', updateLocation);
router.post('/status', toggleStatus);
router.get('/:id', getTechnicianProfile);

// Profile
router.put('/profile', updateProfile);

// Portfolio
router.post('/portfolio', addPortfolioWork);
router.delete('/portfolio/:id', deletePortfolioWork);

export default router;
