import express from 'express';
import {
    createJob,
    getNearbyJobs,
    acceptJob,
    submitOffer, // New import
    acceptOffer, // New import
    getMyJobs,
    getJobById, // New import
    completeJob, // Maps to POST /:id/complete (Request Completion)
    confirmJobCompletion, // New export
    setPrice,
    confirmPrice,
    updateTechnicianProgress,
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
router.post('/:id/accept', acceptJob);           // Legacy endpoint: intentionally disabled (bidding-only flow)
router.post('/:id/submit-offer', submitOffer);   // New: Technician submits offer
router.post('/:id/accept-offer', acceptOffer);   // New: Customer accepts offer

router.post('/:id/set-price', setPrice);         // Technician sets price
router.post('/:id/confirm-price', confirmPrice); // Customer confirms price
router.post('/:id/technician-progress', updateTechnicianProgress); // Technician updates: arrived/start_work
router.post('/:id/complete', completeJob);       // Technician requests completion (was completes)
router.post('/:id/request-completion', completeJob); // Alias for clarity
router.post('/:id/confirm-completion', confirmJobCompletion); // Customer confirms completion
router.post('/:id/rate', rateJob);               // Customer rates
router.post('/:id/cancel', cancelJob);           // Either cancels

export default router;
