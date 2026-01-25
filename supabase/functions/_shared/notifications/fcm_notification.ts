import { config } from "../config.ts";

export async function sendFCMNotification(
    token: string,
    title: string,
    body: string,
    data?: Record<string, any>
): Promise<void> {
    const fcmServerKey = config.fcm.server_key;
    if (!fcmServerKey) {
        console.warn("Skipping Push: FCM_SERVER_KEY not set in config.");
        return;
    }

    console.log(`Sending Push to token: ${token.substring(0, 10)}...`);

    // Supabase Edge Functions often use legacy FCM API or HTTP v1.
    // Assuming legacy based on previous code.
    const response = await fetch("https://fcm.googleapis.com/fcm/send", {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            Authorization: `key=${fcmServerKey}`,
        },
        body: JSON.stringify({
            to: token,
            notification: {
                title,
                body,
            },
            data: data,
            priority: "high",
        }),
    });

    if (!response.ok) {
        const text = await response.text();
        console.error(`FCM Error ${response.status}: ${text}`);
        throw new Error(`FCM Error ${response.status}: ${text}`);
    } else {
        console.log("Push notification sent successfully via FCM.");
    }
}
