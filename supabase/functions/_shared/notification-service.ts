import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { sendFCMNotification } from "./notifications/fcm_notification.ts";
import { sendEmailNotification } from "./notifications/email_notification.ts";
import { sendSMSNotification } from "./notifications/sms_notification.ts";

export type NotificationChannel = "in_app" | "email" | "sms";

export interface NotificationParams {
    userId: string;
    organizationId: string;
    title: string;
    body: string;
    type: string;
    data?: Record<string, any>;
    channels?: NotificationChannel[];
}

export class NotificationService {
    private supabase: SupabaseClient;

    constructor(supabaseClient: SupabaseClient) {
        this.supabase = supabaseClient;
    }

    /**
     * Sends a notification via configured channels.
     */
    async sendNotification(params: NotificationParams): Promise<void> {
        console.log(
            `Sending notification: ${params.title} to Org: ${params.organizationId}, User: ${params.userId}`
        );

        // 1. Determine channels
        let channels = params.channels;
        if (!channels || channels.length === 0) {
            channels = this.getDefaultChannels(params.type);
        }

        // 2. Insert into database (always done if 'in_app' is requested, or maybe always for history?)
        // The previous implementation used DB insert as the primary "in-app" mechanism via realtime.
        // So if 'in_app' is in channels, we must insert.
        let notificationId: string | undefined;

        if (channels.includes("in_app")) {
            notificationId = await this.createDatabaseNotification(params);
        }

        // 3. Fetch user profile for contact info if needed
        // We need profile if we are sending to FCM, Email, or SMS
        if (channels.some(c => ["in_app", "email", "sms"].includes(c))) {
            const { data: profile, error } = await this.supabase
                .from("profiles")
                .select("fcm_token, email_address, phone_number")
                .eq("id", params.userId)
                .single();

            if (error || !profile) {
                console.error(`Error fetching profile for user ${params.userId}:`, error);
                throw new Error(`Profile not found for user ${params.userId}: ${error?.message || "No profile returned"}`);
            }

            // 4. Dispatch to channels
            const promises: Promise<void>[] = [];

            if (channels.includes("in_app") && profile.fcm_token) {
                // Note: We use the notificationId created above for tracking open events
                // We pass it in data.id
                const pushData = { ...params.data, id: notificationId, type: params.type, click_action: "FLUTTER_NOTIFICATION_CLICK" };
                promises.push(
                    sendFCMNotification(profile.fcm_token, params.title, params.body, pushData)
                        .catch(err => console.error("FCM failed:", err))
                );
            }

            if (channels.includes("email") && profile.email_address) {
                promises.push(
                    sendEmailNotification(profile.email_address, params.title, params.body) // Using body as HTML for now, or we could support templates
                        .catch(err => console.error("Email failed:", err))
                );
            }

            if (channels.includes("sms") && profile.phone_number) {
                promises.push(
                    sendSMSNotification(profile.phone_number, `${params.title}: ${params.body}`)
                        .catch(err => console.error("SMS failed:", err))
                );
            }

            await Promise.allSettled(promises);
        }
    }

    private getDefaultChannels(type: string): NotificationChannel[] {
        // Define logic based on type.
        // For now defaulting to in_app.
        // If type implies urgency, add others.
        switch (type) {
            case "security_alert":
            case "dispatch_update": // Example
                return ["in_app", "sms", "email"];
            default:
                return ["in_app"];
        }
    }

    private async createDatabaseNotification(params: NotificationParams): Promise<string> {
        const payload = {
            organization_id: params.organizationId,
            user_id: params.userId,
            title: params.title,
            body: params.body,
            data: {
                ...params.data,
                type: params.type,
            },
            is_read: false,
        };

        const { data, error } = await this.supabase
            .from("notifications")
            .insert(payload)
            .select("id")
            .single();

        if (error) {
            console.error("Error creating database notification:", error);
            throw error;
        }
        return data.id;
    }
}
