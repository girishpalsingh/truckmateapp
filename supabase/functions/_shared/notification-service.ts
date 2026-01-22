import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Interface for notification parameters
export interface NotificationParams {
    userId?: string;          // If null, sends to organization (subject to RLS)
    organizationId: string;
    title: string;
    body: string;
    data?: Record<string, any>;
    type: string;             // e.g., 'rate_con_review', 'system_alert'
}

export class NotificationService {
    private supabase: SupabaseClient;

    constructor(supabaseClient: SupabaseClient) {
        this.supabase = supabaseClient;
    }

    /**
     * Sends a notification by inserting it into the database.
     * Realtime subscriptions in the client will pick this up.
     */
    async sendNotification(params: NotificationParams): Promise<void> {
        console.log(`Sending notification: ${params.title} to Org: ${params.organizationId}, User: ${params.userId || 'ALL'}`);

        const payload = {
            organization_id: params.organizationId,
            user_id: params.userId, // Can be null/undefined for org-wide
            title: params.title,
            body: params.body,
            data: {
                ...params.data,
                type: params.type,
            },
            is_read: false,
        };

        const { data: insertedData, error } = await this.supabase
            .from('notifications')
            .insert(payload)
            .select('id')
            .single();

        if (error) {
            console.error("Error creating notification:", error);
            // We usually don't want to throw here to prevent blocking the main flow
            // assuming notification failure is non-critical compared to data processing.
        } else {
            console.log("Notification created successfully, ID:", insertedData.id);

            // Trigger Push Notification (Fire and Forget)
            if (params.userId) {
                this.sendPushNotification(params, insertedData.id).catch(err => {
                    console.error("Error sending push notification:", err);
                });
            }
        }
    }

    /**
     * Sends a push notification via FCM if token exists for user
     */
    private async sendPushNotification(params: NotificationParams, notificationId: string): Promise<void> {
        if (!params.userId) return;

        // 1. Get FCM Token
        const { data: profile } = await this.supabase
            .from('profiles')
            .select('fcm_token')
            .eq('id', params.userId)
            .single();

        if (!profile?.fcm_token) {
            console.log(`No FCM token found for user ${params.userId}`);
            return;
        }

        // 2. Send to FCM (requires proper environment setup or service account)
        // For Supabase Edge Functions, we typically call the FCM API directly 
        // using a JWT from a service account or using the server key (legacy).
        // Since we didn't setup the service account JSON in this flow yet, 
        // I will implement a placeholder that LOGS the intent and describes the required config.

        const fcmServerKey = Deno.env.get('FCM_SERVER_KEY');
        if (!fcmServerKey) {
            console.warn("Skipping Push: FCM_SERVER_KEY not set in Edge Function secrets.");
            return;
        }

        console.log(`Sending Push to token: ${profile.fcm_token.substring(0, 10)}...`);

        const response = await fetch('https://fcm.googleapis.com/fcm/send', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `key=${fcmServerKey}`,
            },
            body: JSON.stringify({
                to: profile.fcm_token,
                notification: {
                    title: params.title,
                    body: params.body,
                },
                data: {
                    ...params.data,
                    type: params.type,
                    id: notificationId, // Critical for mark as read
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                },
                priority: 'high',
            }),
        });

        if (!response.ok) {
            const text = await response.text();
            console.error(`FCM Error ${response.status}: ${text}`);
        } else {
            console.log("Push notification sent successfully via FCM.");
        }
    }
}
