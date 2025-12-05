import express from 'express';
import { getMyWallet, getTransactions } from '../controllers/walletController.js';
import { protect } from '../middleware/authMiddleware.js';

const router = express.Router();

router.use(protect);

router.get('/', getMyWallet);
router.get('/transactions', getTransactions);

export default router;
