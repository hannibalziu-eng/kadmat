import { supabaseAdmin } from '../config/supabase.js';

class WalletService {

    /**
     * Get user's wallet balance
     */
    /**
     * Get user's wallet balance
     */
    async getBalance(userId) {
        let { data: wallet, error } = await supabaseAdmin
            .from('wallets')
            .select('*')
            .eq('user_id', userId)
            .maybeSingle();

        if (error) throw error;

        // If no wallet exists, create one (Self-Healing)
        if (!wallet) {
            console.log(`Wallet missing for user ${userId}, creating now...`);
            // Use supabaseAdmin to bypass RLS for creation
            const { data: newWallet, error: createError } = await supabaseAdmin
                .from('wallets')
                .insert({ user_id: userId })
                .select()
                .maybeSingle();

            if (createError) throw createError;
            wallet = newWallet;
        }

        if (!wallet) throw new Error('Failed to retrieve or create wallet');

        return wallet;
    }

    /**
     * Get wallet transactions with pagination
     */
    async getTransactions(userId, page = 1, limit = 20) {
        // 1. Get Wallet ID (Auto-create if missing)
        const wallet = await this.getBalance(userId);

        // 2. Get Transactions
        const offset = (page - 1) * limit;

        const { data: transactions, error, count } = await supabaseAdmin
            .from('wallet_transactions')
            .select('*', { count: 'exact' })
            .eq('wallet_id', wallet.id)
            .order('created_at', { ascending: false })
            .range(offset, offset + limit - 1);

        if (error) throw error;

        return {
            transactions,
            total: count,
            page,
            totalPages: Math.ceil((count || 0) / limit)
        };
    }

    /**
     * Create a withdrawal request and reserve amount from wallet balance.
     */
    async requestWithdrawal(userId, amount, { bankAccount = null, notes = null } = {}) {
        const parsedAmount = Number(amount);
        if (!Number.isFinite(parsedAmount) || parsedAmount <= 0) {
            throw new Error('Invalid withdrawal amount');
        }

        const wallet = await this.getBalance(userId);
        const currentBalance = Number(wallet.balance || 0);

        if (currentBalance < parsedAmount) {
            throw new Error('Insufficient wallet balance');
        }

        const now = new Date().toISOString();
        const { data: request, error: requestError } = await supabaseAdmin
            .from('withdraw_requests')
            .insert({
                user_id: userId,
                wallet_id: wallet.id,
                amount: parsedAmount,
                currency: wallet.currency || 'SAR',
                status: 'pending',
                bank_account: bankAccount,
                notes
            })
            .select('*')
            .single();

        if (requestError) throw requestError;

        const { error: walletError } = await supabaseAdmin
            .from('wallets')
            .update({
                balance: currentBalance - parsedAmount,
                updated_at: now
            })
            .eq('id', wallet.id);

        if (walletError) throw walletError;

        const { error: transactionError } = await supabaseAdmin
            .from('wallet_transactions')
            .insert({
                wallet_id: wallet.id,
                amount: -parsedAmount,
                type: 'withdrawal',
                status: 'pending',
                reference_type: 'withdraw_request',
                reference_id: request.id,
                description: 'طلب سحب قيد المراجعة'
            });

        if (transactionError) throw transactionError;

        return request;
    }

    /**
     * Retrieve withdrawal requests for current user.
     */
    async getWithdrawals(userId, page = 1, limit = 20) {
        const pageNumber = Number(page) > 0 ? Number(page) : 1;
        const pageLimit = Number(limit) > 0 ? Number(limit) : 20;
        const offset = (pageNumber - 1) * pageLimit;

        const { data: withdrawals, error, count } = await supabaseAdmin
            .from('withdraw_requests')
            .select('*', { count: 'exact' })
            .eq('user_id', userId)
            .order('created_at', { ascending: false })
            .range(offset, offset + pageLimit - 1);

        if (error) throw error;

        return {
            withdrawals: withdrawals || [],
            total: count || 0,
            page: pageNumber,
            totalPages: Math.ceil((count || 0) / pageLimit)
        };
    }
}

export const walletService = new WalletService();
