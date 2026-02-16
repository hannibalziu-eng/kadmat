import express from 'express';
import {
    getWallet,
    getWalletTransactions,
    requestWithdrawal,
    getWithdrawals
} from '../controllers/walletController.js';
import { protect } from '../middleware/authMiddleware.js';

const router = express.Router();

router.use(protect);

router.get('/', getWallet);
router.get('/transactions', getWalletTransactions);
router.post('/withdraw', requestWithdrawal);
router.get('/withdrawals', getWithdrawals);

export default router;
