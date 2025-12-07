import express from 'express';
import { getWallet, getWalletTransactions } from '../controllers/walletController.js';
import { protect } from '../middleware/authMiddleware.js';

const router = express.Router();

router.use(protect);

router.get('/', getWallet);
router.get('/transactions', getWalletTransactions);

export default router;
