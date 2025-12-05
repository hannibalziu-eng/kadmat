import { supabase } from '../config/supabase.js';

// 1. Get My Wallet Balance
export const getMyWallet = async (req, res, next) => {
    try {
        const userId = req.user.id;

        const { data: wallet, error } = await supabase
            .from('wallets')
            .select('id, balance, currency, is_frozen')
            .eq('user_id', userId)
            .maybeSingle(); // Use maybeSingle() instead of single() to avoid error on empty result

        if (error) return next(error);

        // If wallet doesn't exist, create one automatically
        if (!wallet) {
            const { data: newWallet, error: createError } = await supabase
                .from('wallets')
                .insert({ user_id: userId })
                .select()
                .single();

            if (createError) return next(createError);

            return res.json({
                success: true,
                wallet: newWallet,
                created: true
            });
        }

        res.json({ success: true, wallet });

    } catch (error) {
        next(error);
    }
};

// 2. Get Wallet Transactions
export const getTransactions = async (req, res, next) => {
    try {
        const userId = req.user.id;
        const { limit = 20, offset = 0 } = req.query;

        // First get wallet ID
        const { data: wallet, error: walletError } = await supabase
            .from('wallets')
            .select('id')
            .eq('user_id', userId)
            .maybeSingle();

        if (walletError) return next(walletError);

        if (!wallet) {
            return res.status(404).json({
                success: false,
                error: {
                    code: 'WALLET_NOT_FOUND',
                    message: 'Wallet not found. Please contact support.'
                }
            });
        }

        // Get transactions
        const { data: transactions, error } = await supabase
            .from('wallet_transactions')
            .select('*')
            .eq('wallet_id', wallet.id)
            .order('created_at', { ascending: false })
            .range(parseInt(offset), parseInt(offset) + parseInt(limit) - 1);

        if (error) return next(error);

        res.json({
            success: true,
            transactions: transactions || [],
            count: transactions?.length || 0
        });

    } catch (error) {
        next(error);
    }
};
