// Specific prompts for extracting data from different document types
import { RATE_CON_PROMPT as rate_con } from "./prompts/rate_con.ts";
import bol from "./prompts/bol.ts";
import fuel_receipt from "./prompts/fuel_receipt.ts";
import lumper_receipt from "./prompts/lumper_receipt.ts";
import scale_ticket from "./prompts/scale_ticket.ts";
import odometer from "./prompts/odometer.ts";
import other from "./prompts/other.ts";

export const EXTRACTION_PROMPTS: Record<string, string> = {
  rate_con,
  bol,
  fuel_receipt,
  lumper_receipt,
  scale_ticket,
  odometer,
  other,
};
