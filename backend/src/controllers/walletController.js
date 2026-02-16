import { walletService } from '../services/walletService.js';

// Get Wallet Balance
export const getWallet = async (req, res) => {
    try {
        const wallet = await walletService.getBalance(req.user.id);
        res.json({ success: true, data: wallet });
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

        res.json({
            success: true,
            data: result.transactions,
            pagination: {
                total: result.total,
                page: result.page,
                totalPages: result.totalPages
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

export const requestWithdrawal = async (req, res) => {
    try {
        const { amount, bank_account, notes } = req.body || {};

        const request = await walletService.requestWithdrawal(
            req.user.id,
            amount,
            { bankAccount: bank_account, notes }
        );

        res.status(201).json({
            success: true,
            data: request,
            message: 'تم إرسال طلب السحب بنجاح'
        });
    } catch (error) {
        const normalized = error.message || 'Failed to create withdrawal request';
        const isValidationError =
            normalized.includes('Invalid withdrawal amount') ||
            normalized.includes('Insufficient wallet balance');

        res.status(isValidationError ? 400 : 500).json({
            success: false,
            message: normalized
        });
    }
};

export const getWithdrawals = async (req, res) => {
    try {
        const { page = 1, limit = 20 } = req.query;
        const result = await walletService.getWithdrawals(
            req.user.id,
            parseInt(page),
            parseInt(limit)
        );

        res.json({
            success: true,
            data: result.withdrawals,
            pagination: {
                total: result.total,
                page: result.page,
                totalPages: result.totalPages
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};
