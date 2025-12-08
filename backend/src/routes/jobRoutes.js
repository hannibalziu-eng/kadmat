import express from 'express';
import {
    createJob,
    getNearbyJobs,
    acceptJob,
    getMyJobs,
    getJobById, // New import
    completeJob,
    setPrice,
    confirmPrice,
    rateJob,
    cancelJob
} from '../controllers/jobController.js';
import { protect } from '../middleware/authMiddleware.js';

const router = express.Router();

// All routes are protected
router.use(protect);

// Job CRUD
router.post('/', createJob);
router.get('/nearby', getNearbyJobs);
router.get('/my-jobs', getMyJobs);
router.get('/:id', getJobById); // New route

// Job Flow
router.post('/:id/accept', acceptJob);           // Technician accepts
router.post('/:id/set-price', setPrice);         // Technician sets price
router.post('/:id/confirm-price', confirmPrice); // Customer confirms price
router.post('/:id/complete', completeJob);       // Technician completes
router.post('/:id/rate', rateJob);               // Customer rates
router.post('/:id/cancel', cancelJob);           // Either cancels

export default router;
