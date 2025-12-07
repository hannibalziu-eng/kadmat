import { supabase, supabaseAdmin } from '../config/supabase.js';

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
}

export const walletService = new WalletService();
