import { supabase } from '../config/supabase.js';

class WalletService {

    /**
     * Get user's wallet balance
     */
    async getBalance(userId) {
        const { data: wallet, error } = await supabase
            .from('wallets')
            .select('*')
            .eq('user_id', userId)
            .single();

        if (error) throw error;
        if (!wallet) throw new Error('Wallet not found');

        return wallet;
    }

    /**
     * Get wallet transactions with pagination
     */
    async getTransactions(userId, page = 1, limit = 20) {
        // 1. Get Wallet ID
        const { data: wallet } = await supabase
            .from('wallets')
            .select('id')
            .eq('user_id', userId)
            .single();

        if (!wallet) throw new Error('Wallet not found');

        // 2. Get Transactions
        const offset = (page - 1) * limit;

        const { data: transactions, error, count } = await supabase
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
}

export const walletService = new WalletService();
