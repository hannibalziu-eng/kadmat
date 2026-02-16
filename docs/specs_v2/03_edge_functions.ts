// Edge Functions - push-notifications/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

serve(async (req) => {
    try {
        const { type, payload } = await req.json();

        switch (type) {
            case "bid_accepted":
                return await handleBidAccepted(payload);
            case "first_bid_received":
                return await handleFirstBid(payload);
            case "bidding_expired":
                return await handleBiddingExpired(payload);
            case "technician_cancelled":
                return await handleTechnicianCancelled(payload);
            case "waitlist_offer":
                return await handleWaitlistOffer(payload);
            case "payment_received":
                return await handlePaymentReceived(payload);
            case "new_dispute":
                return await handleNewDispute(payload);
            default:
                return new Response(
                    JSON.stringify({ error: "Unknown type" }),
                    { status: 400, headers: { "Content-Type": "application/json" } }
                );
        }
    } catch (error) {
        console.error("Error:", error);
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: { "Content-Type": "application/json" } }
        );
    }
});

async function handleBidAccepted(payload: any) {
    const { job_id, technician_id, amount, customer_id, confirmation_code } = payload;

    // Fetch technician details
    const { data: tech } = await supabase
        .from("users")
        .select("fcm_token, full_name")
        .eq("id", technician_id)
        .single();

    // Send FCM to technician
    if (tech?.fcm_token) {
        await sendFCM({
            token: tech.fcm_token,
            title: "🎉 تم قبول عرضك!",
            body: `العميل قبل عرضك بقيمة ${amount} ريال. كود التأكيد: ${confirmation_code}`,
            data: {
                type: "bid_accepted",
                job_id,
                confirmation_code,
                click_action: "OPEN_LOCKED_JOB"
            }
        });
    }

    // Add in-app notification for technician
    await supabase.from("notifications").insert({
        user_id: technician_id,
        type: "bid_accepted",
        title: "تم قبول عرضك!",
        body: `العميل قبل عرضك بقيمة ${amount} ريال`,
        data: { job_id, amount, confirmation_code },
        is_read: false
    });

    // Notify rejected technicians
    const { data: rejectedBids } = await supabase
        .from("bids")
        .select("technician_id")
        .eq("job_id", job_id)
        .neq("technician_id", technician_id);

    for (const bid of rejectedBids || []) {
        await supabase.from("notifications").insert({
            user_id: bid.technician_id,
            type: "bid_rejected",
            title: "تم اختيار فني آخر",
            body: "تم قبول عرض فني آخر لهذه المهمة",
            data: { job_id }
        });
    }

    return new Response(JSON.stringify({ success: true }));
}

async function handleWaitlistOffer(payload: any) {
    const { job_id, technician_id, amount, expires_at } = payload;

    const { data: tech } = await supabase
        .from("users")
        .select("fcm_token")
        .eq("id", technician_id)
        .single();

    if (tech?.fcm_token) {
        await sendFCM({
            token: tech.fcm_token,
            title: "⏰ عرض عاجل!",
            body: `فرصة جديدة بقيمة ${amount} ريال. تنتهي خلال 5 دقائق!`,
            data: {
                type: "waitlist_offer",
                job_id,
                expires_at,
                click_action: "OPEN_WAITLIST_OFFER"
            }
        });
    }

    await supabase.from("notifications").insert({
        user_id: technician_id,
        type: "waitlist_offer",
        title: "عرض عاجل متاح!",
        body: `فرصة عمل بقيمة ${amount} ريال - 5 دقائق للقبول`,
        data: { job_id, amount, expires_at },
        is_read: false,
        priority: "high"
    });

    return new Response(JSON.stringify({ success: true }));
}

async function handlePaymentReceived(payload: any) {
    const { job_id, technician_id, amount } = payload;

    const { data: tech } = await supabase
        .from("users")
        .select("fcm_token")
        .eq("id", technician_id)
        .single();

    if (tech?.fcm_token) {
        await sendFCM({
            token: tech.fcm_token,
            title: "💰 تم استلام الدفع!",
            body: `تم تأكيد دفع ${amount} ريال من العميل`,
            data: {
                type: "payment_received",
                job_id,
                amount,
                click_action: "OPEN_WALLET"
            }
        });
    }

    return new Response(JSON.stringify({ success: true }));
}

async function handleNewDispute(payload: any) {
    const { dispute_id, job_id, raised_by, type, whatsapp_link } = payload;

    const { data: job } = await supabase
        .from("jobs")
        .select("customer_id, technician_id")
        .eq("id", job_id)
        .single();

    const message = "تم فتح نزاع على هذه المهمة. فريق الدعم سيتواصل معك عبر واتساب.";

    for (const userId of [job.customer_id, job.technician_id]) {
        if (!userId) continue;

        const { data: user } = await supabase
            .from("users")
            .select("fcm_token")
            .eq("id", userId)
            .single();

        if (user?.fcm_token) {
            await sendFCM({
                token: user.fcm_token,
                title: "⚠️ نزاع مفتوح",
                body: message,
                data: {
                    type: "dispute_opened",
                    job_id,
                    dispute_id,
                    whatsapp_link
                }
            });
        }

        await supabase.from("notifications").insert({
            user_id: userId,
            type: "dispute_opened",
            title: "نزاع مفتوح على المهمة",
            body: message,
            data: { job_id, dispute_id, whatsapp_link },
            is_read: false,
            priority: "high"
        });
    }

    return new Response(JSON.stringify({ success: true }));
}

async function handleFirstBid(payload: any) {
    const { job_id, customer_id, technician_name } = payload;

    const { data: customer } = await supabase
        .from("users")
        .select("fcm_token")
        .eq("id", customer_id)
        .single();

    if (customer?.fcm_token) {
        await sendFCM({
            token: customer.fcm_token,
            title: "🎉 وصلك أول عرض!",
            body: `${technician_name} قدم عرضاً لطلبك`,
            data: {
                type: "first_bid",
                job_id,
                click_action: "OPEN_JOB_BIDS"
            }
        });
    }

    await supabase.from("notifications").insert({
        user_id: customer_id,
        type: "first_bid",
        title: "وصلك أول عرض!",
        body: `${technician_name} قدم عرضاً لطلبك`,
        data: { job_id },
        is_read: false
    });

    return new Response(JSON.stringify({ success: true }));
}

async function handleBiddingExpired(payload: any) {
    const { job_id, customer_id, can_reopen } = payload;

    const { data: customer } = await supabase
        .from("users")
        .select("fcm_token")
        .eq("id", customer_id)
        .single();

    const message = "انتهى وقت المزاد دون اختيار فني. يمكنك إعادة فتح الطلب.";

    if (customer?.fcm_token) {
        await sendFCM({
            token: customer.fcm_token,
            title: "⏳ انتهى وقت المزاد",
            body: message,
            data: {
                type: "bidding_expired",
                job_id,
                click_action: "OPEN_JOB_DETAILS"
            }
        });
    }

    await supabase.from("notifications").insert({
        user_id: customer_id,
        type: "bidding_expired",
        title: "انتهى وقت المزاد",
        body: message,
        data: { job_id },
        is_read: false
    });

    return new Response(JSON.stringify({ success: true }));
}

async function handleTechnicianCancelled(payload: any) {
    const { job_id, message, alternative_available } = payload;
    // Retrieve customer ID for this job - simplified, might need query
    const { data: job } = await supabase.from('jobs').select('customer_id').eq('id', job_id).single();
    if (!job) return new Response(JSON.stringify({ success: false, error: 'Job not found' }));

    const { data: customer } = await supabase
        .from("users")
        .select("fcm_token")
        .eq("id", job.customer_id)
        .single();

    if (customer?.fcm_token) {
        await sendFCM({
            token: customer.fcm_token,
            title: "🔴 تم إلغاء قبول الفني",
            body: message,
            data: {
                type: "technician_cancelled",
                job_id,
                alternative_available: alternative_available.toString()
            }
        });
    }

    await supabase.from("notifications").insert({
        user_id: job.customer_id,
        type: "technician_cancelled",
        title: "تم إلغاء قبول الفني",
        body: message,
        data: { job_id, alternative_available },
        is_read: false,
        priority: "high"
    });

    return new Response(JSON.stringify({ success: true }));
}


async function sendFCM({ token, title, body, data }: any) {
    const res = await fetch("https://fcm.googleapis.com/fcm/send", {
        method: "POST",
        headers: {
            Authorization: `key=${FCM_SERVER_KEY}`,
            "Content-Type": "application/json"
        },
        body: JSON.stringify({
            to: token,
            notification: { title, body, sound: "default" },
            data,
            priority: "high"
        })
    });
    return res.ok;
}
