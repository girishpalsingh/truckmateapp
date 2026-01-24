// Polyfill for regeneratorRuntime
import regeneratorRuntime from "https://esm.sh/regenerator-runtime@0.13.11";
(globalThis as any).regeneratorRuntime = regeneratorRuntime;
(self as any).regeneratorRuntime = regeneratorRuntime;

import { PDFDocument, rgb, StandardFonts, PDFName, PDFString, PDFArray } from 'https://esm.sh/pdf-lib@1.17.1?target=es2015&no-check';
import fontkit from 'https://esm.sh/@pdf-lib/fontkit@1.1.1?target=es2015&no-check';
import { NOTO_SANS_GURMUKHI_BASE64 } from './resources/font-data.ts';
import { decode } from "https://deno.land/std@0.168.0/encoding/base64.ts";

interface DispatcherSheetData {
    rateConId: string;
    brokerName?: string;
    stops: any[];
    dispatchInstructions: any[];
    loadId?: string;
    driverView?: any;
}

/**
 * Filtering Punjabi text to remove invisible control characters 
 * that frequently crash font shapers (like zero-width joiners).
 */
function cleanPunjabiText(text: string): string {
    if (!text) return "";
    return String(text)
        .replace(/[\u200B-\u200D\uFEFF]/g, '') // Remove ZWSP, ZWNJ, ZWJ, BOM
        .trim();
}

/**
 * Helper to add a link annotation
 */
function addLink(page: any, url: string, x: number, y: number, width: number, height: number) {
    const context = page.doc.context;
    const linkAnnotation = context.obj({
        Type: 'Annot',
        Subtype: 'Link',
        Rect: [x, y, x + width, y + height],
        Border: [0, 0, 0],
        A: {
            Type: 'Action',
            S: 'URI',
            URI: PDFString.of(url),
        },
    });

    // Check if the page already has annotations
    const annots = page.node.get(PDFName.of('Annots'));
    if (annots instanceof PDFArray) {
        annots.push(linkAnnotation);
    } else {
        page.node.set(PDFName.of('Annots'), context.obj([linkAnnotation]));
    }
}

/**
 * Generates the Dispatcher Sheet PDF
 */
export async function generateDispatchSheetPDF(data: DispatcherSheetData): Promise<Uint8Array> {
    const pdfDoc = await PDFDocument.create();
    pdfDoc.registerFontkit(fontkit);

    // Embed Standard Fonts
    const font = await pdfDoc.embedFont(StandardFonts.Helvetica);
    const boldFont = await pdfDoc.embedFont(StandardFonts.HelveticaBold);

    // Embed Punjabi Font from Base64 constant (Guaranteed reliability)
    let punjabiFont;
    try {
        const fontBytes = decode(NOTO_SANS_GURMUKHI_BASE64);
        punjabiFont = await pdfDoc.embedFont(fontBytes);
        console.log("Punjabi font embedded successfully from constant");
    } catch (e) {
        console.error("Critical: Failed to embed constant Punjabi font:", e);
    }

    const page = pdfDoc.addPage();
    const { width, height } = page.getSize();

    const fontSize = 12;
    const lineHeight = 15;
    let y = height - 50;

    // --- Header ---
    page.drawText('Dispatcher Sheet', { x: 50, y, size: 20, font: boldFont });
    y -= 30;

    // --- Load Info ---
    page.drawText(`Load Ref: ${data.rateConId}`, { x: 50, y, size: fontSize, font });
    y -= lineHeight;
    page.drawText(`Broker: ${data.brokerName || 'N/A'}`, { x: 50, y, size: fontSize, font });
    y -= lineHeight * 2;

    // --- Stops ---
    page.drawText('Stops:', { x: 50, y, size: 14, font: boldFont });
    y -= lineHeight;

    if (data.stops && data.stops.length > 0) {
        // Ensure sorted by sequence
        const sortedStops = [...data.stops].sort((a: any, b: any) => (a.sequence_number || 0) - (b.sequence_number || 0));

        for (const stop of sortedStops) {
            const stopType = stop.stop_type || 'Stop';
            const address = stop.address || 'N/A';
            const displayText = `${stop.sequence_number || '•'}. ${stopType}: ${address}`;

            // Create clickable map link logic
            const mapUrl = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(address)}`;

            page.drawText(displayText, {
                x: 50,
                y,
                size: 10,
                font,
                color: rgb(0, 0.4, 0.8) // Blue to indicate link
            });

            // Add annotation for link
            const textWidth = font.widthOfTextAtSize(displayText, 10);
            addLink(page, mapUrl, 50, y, textWidth, 10);

            y -= lineHeight;

            if (stop.scheduled_arrival) {
                const arrival = new Date(stop.scheduled_arrival).toLocaleString();
                page.drawText(`   Arrival: ${arrival}`, { x: 50, y, size: 10, font });
                y -= lineHeight;
            }
        }
    } else {
        page.drawText('No stops found.', { x: 50, y, size: 10, font });
    }
    y -= lineHeight;

    // --- Dispatch Instructions ---
    page.drawText('Dispatch Instructions:', { x: 50, y, size: 14, font: boldFont });
    y -= lineHeight;

    const instructions = data.dispatchInstructions || [];
    if (instructions.length > 0) {
        for (const inst of instructions) {
            // Check for page break
            if (y < 80) {
                const newPage = pdfDoc.addPage();
                y = newPage.getSize().height - 50;
            }

            // English Title
            const title = inst.title_en || 'Instruction';
            page.drawText(`- ${title}`, { x: 50, y, size: 11, font: boldFont });
            y -= lineHeight;

            // Punjabi Title (Drawn and Guarded separately)
            if (inst.title_punjab && punjabiFont) {
                try {
                    const pbTitle = cleanPunjabiText(inst.title_punjab);
                    // Draw opening paren with standard font
                    page.drawText('  (', { x: 50, y, size: 11, font });
                    const offset = font.widthOfTextAtSize('  (', 11);
                    // Draw Punjabi text with Gurmukhi font
                    page.drawText(pbTitle, { x: 50 + offset, y, size: 11, font: punjabiFont });
                    const pbWidth = punjabiFont.widthOfTextAtSize(pbTitle, 11);
                    // Draw closing paren with standard font
                    page.drawText(')', { x: 50 + offset + pbWidth, y, size: 11, font });
                    y -= lineHeight;
                } catch (e) {
                    console.error("Error drawing Punjabi title line:", e);
                }
            }

            // English Description
            if (inst.description_en) {
                const cleanDesc = inst.description_en.replace(/\n/g, ' ');
                const desc = cleanDesc.substring(0, 90) + (cleanDesc.length > 90 ? '...' : '');
                page.drawText(`  ${desc}`, { x: 50, y, size: 10, font });
                y -= lineHeight;
            }

            // Punjabi Description (Guarded)
            if (inst.description_punjab && punjabiFont) {
                try {
                    const pbDescRaw = cleanPunjabiText(inst.description_punjab);
                    const cleanDescPb = pbDescRaw.replace(/\n/g, ' ');
                    const descPb = cleanDescPb.substring(0, 70) + (cleanDescPb.length > 70 ? '...' : '');
                    page.drawText(`  ${descPb}`, { x: 50, y, size: 10, font: punjabiFont });
                    y -= lineHeight;
                } catch (e) {
                    console.error("Error drawing Punjabi description line:", e);
                }
            }
            y -= 5;
        }
    } else {
        page.drawText('No specific special instructions.', { x: 50, y, size: 10, font });
        y -= lineHeight;
    }
    y -= lineHeight * 2;

    // --- Driver View / Requirements ---
    if (data.driverView) {
        // Check for page break
        if (y < 120) {
            const newPage = pdfDoc.addPage();
            y = newPage.getSize().height - 50;
        }

        page.drawText('Requirements & Equipment:', { x: 50, y, size: 14, font: boldFont });
        y -= lineHeight;

        const equipment = data.driverView.special_equipment_needed || [];
        const transit = data.driverView.transit_requirements || [];
        const combined = [...equipment, ...transit];

        if (combined.length > 0) {
            combined.forEach((req: string) => {
                page.drawText(`[ ] ${req}`, { x: 50, y, size: 10, font });
                y -= lineHeight;
            });
        } else {
            page.drawText('See instructions above.', { x: 50, y, size: 10, font });
            y -= lineHeight;
        }
    }

    // Example Footer or additional info
    page.drawText('Generated by TruckMate - Map links are clickable', { x: 50, y: 30, size: 8, font, color: rgb(0.5, 0.5, 0.5) });

    return await pdfDoc.save();
}
