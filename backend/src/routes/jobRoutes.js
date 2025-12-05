import express from 'express';
import { createJob, getNearbyJobs, acceptJob, getMyJobs, completeJob } from '../controllers/jobController.js';
import { protect } from '../middleware/authMiddleware.js';

const router = express.Router();

// All routes are protected
router.use(protect);

router.post('/', createJob);
router.get('/nearby', getNearbyJobs);
router.post('/:id/accept', acceptJob);
router.post('/:id/complete', completeJob); // New Route
router.get('/my-jobs', getMyJobs);

export default router;
