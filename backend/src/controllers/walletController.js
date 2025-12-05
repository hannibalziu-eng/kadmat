import { walletService } from '../services/walletService.js';

// Get Wallet Balance
export const getWallet = async (req, res) => {
    try {
        const wallet = await walletService.getBalance(req.user.id);
        res.json({ success: true, wallet });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// Get Wallet Transactions
export const getWalletTransactions = async (req, res) => {
    try {
        const { page = 1, limit = 20 } = req.query;
        const result = await walletService.getTransactions(
            req.user.id,
            parseInt(page),
            parseInt(limit)
        );

        res.json({ success: true, ...result });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};
