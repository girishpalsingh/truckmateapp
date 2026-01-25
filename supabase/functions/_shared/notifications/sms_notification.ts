import { config } from "../config.ts";

export async function sendSMSNotification(
    to: string,
    body: string
): Promise<void> {
    const accountSid = config.twilio.account_sid;
    const authToken = config.twilio.auth_token;
    const fromNumber = config.twilio.phone_number;

    if (!accountSid || !authToken || !fromNumber) {
        console.warn("Skipping SMS: Twilio config missing.");
        return;
    }

    if (config.development.skip_twilio) {
        console.log(`[DEV] Skipping SMS to ${to}: ${body}`);
        return;
    }

    console.log(`Sending SMS to ${to}: ${body}`);

    // Twilio API requires form-urlencoded body
    const formData = new URLSearchParams();
    formData.append("To", to);
    formData.append("From", fromNumber);
    formData.append("Body", body);

    const response = await fetch(
        `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`,
        {
            method: "POST",
            headers: {
                Authorization: `Basic ${btoa(`${accountSid}:${authToken}`)}`,
                "Content-Type": "application/x-www-form-urlencoded",
            },
            body: formData,
        }
    );

    if (!response.ok) {
        const text = await response.text();
        console.error(`Twilio Error ${response.status}: ${text}`);
    } else {
        console.log("SMS sent successfully via Twilio.");
    }
}
