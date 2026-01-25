import { Resend } from "resend";
import { config } from "../config.ts";

export async function sendEmailNotification(
    to: string,
    subject: string,
    html: string
): Promise<void> {
    const apiKey = config.resend.api_key;
    const fromEmail = config.resend.from_email;

    if (!apiKey || !fromEmail) {
        console.warn("Skipping Email: Resend config missing.");
        return;
    }

    // Note: config.development.skip_email check should happen before calling this or inside.
    // We'll keep it here for safety.
    if (config.development.skip_email) {
        console.log(`[DEV] Skipping email to ${to}: ${subject}`);
        return;
    }

    const resend = new Resend(apiKey);

    console.log(`Sending Email to ${to}: ${subject}`);

    try {
        const { data, error } = await resend.emails.send({
            from: fromEmail,
            to: [to],
            subject: subject,
            html: html,
        });

        if (error) {
            console.error("Resend Error:", error);
            // Constructing an error similar to before or just logging
        } else {
            console.log("Email sent successfully via Resend. ID:", data?.id);
        }
    } catch (err) {
        console.error("Resend Exception:", err);
    }
}
