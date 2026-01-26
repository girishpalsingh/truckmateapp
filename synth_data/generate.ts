
import { ensureDir } from "https://deno.land/std@0.224.0/fs/ensure_dir.ts";
import { join } from "https://deno.land/std@0.224.0/path/mod.ts";

const OUTPUT_DIR = "/Users/girish/development/truckmateapp/synth_data";

// --- Types ---

interface Address {
    name: string;
    address: string;
    city: string;
    state: string;
    zip: string;
    contact?: string;
    phone?: string;
    email?: string;
}

interface Load {
    id: string; // Internal ID
    loadNumber: string;
    bolNumber: string;
    poNumber: string;
    soNumber?: string;

    broker: Address & { mc: string; logoColor: string };
    carrier: Address & { mc: string; equipment: string };

    shipper: Address;
    consignee: Address;

    pickupDate: string; // ISO Date YYYY-MM-DD
    pickupTime: string;
    deliveryDate: string;
    deliveryTime: string;

    commodity: string;
    weight: number;
    qty: number;
    units: string;
    rate: number;

    clauses: string[];
    instructions: string[];
}

// --- Data Generators ---

function randomInt(min: number, max: number) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomItem<T>(arr: T[]): T {
    return arr[Math.floor(Math.random() * arr.length)];
}

const CITIES = [
    { city: "Chicago", state: "IL", zip: "60601" },
    { city: "Atlanta", state: "GA", zip: "30301" },
    { city: "Dallas", state: "TX", zip: "75201" },
    { city: "Los Angeles", state: "CA", zip: "90001" },
    { city: "New York", state: "NY", zip: "10001" },
    { city: "Miami", state: "FL", zip: "33101" },
    { city: "Seattle", state: "WA", zip: "98101" },
    { city: "Denver", state: "CO", zip: "80201" },
];

const COMMODITIES = [
    "General Freight", "Frozen Chicken", "Auto Parts", "Paper Rolls", "Electronics",
    "Fresh Produce", "Steel Coils", "Furniture"
];

const BROKERS = [
    "TQL Logistics", "CH Robinson", "XPO Logistics", "Coyote Logistics", "Echo Global",
    "Uber Freight", "Total Quality", "Landstar"
];

const CARRIERS = [
    "Swift Transport", "JB Hunt", "Knight Transport", "Schneider National", "Werner Enterprises"
];

const INSTRUCTIONS = [
    "Driver must call for dispatch 2 hours prior to pickup.",
    "MacroPoint tracking required explicitly.",
    "Pulp temperature check required -10F.",
    "Seal must remain intact until delivery.",
    "Lumper receipt required for reimbursement.",
    "No riders / passengers allowed.",
    "PPE (Vest, Boots) required at all facilities."
];

const CLAUSES = [
    // Red Light / Danger
    { text: "Carrier must notify Broker 2 hours BEFORE free time expires or detention will be denied.", type: "danger" },
    { text: "$250 Fine for missing check calls.", type: "danger" },
    { text: "Late delivery will result in a $500 claim against the carrier.", type: "danger" },
    { text: "Carrier agrees to indemnify Broker against ALL claims including Broker's own negligence.", type: "danger" },

    // Yellow/Green
    { text: "Standard detention rate: $50/hour after 2 hours free time.", type: "standard" },
    { text: "Any accessorial charges must be approved in writing.", type: "standard" },
    { text: "Double brokering is strictly prohibited and will result in non-payment.", type: "standard" },
];

function generateAddress(companyName: string): Address {
    const loc = randomItem(CITIES);
    return {
        name: companyName,
        address: `${randomInt(100, 9999)} ${randomItem(["Main St", "Industrial Blvd", "Commerce Way", "Logistics Dr"])}`,
        city: loc.city,
        state: loc.state,
        zip: loc.zip,
        contact: "Shipping Manager",
        phone: `555-${randomInt(100, 999)}-${randomInt(1000, 9999)}`,
        email: `dispatch@${companyName.replace(/\s/g, '').toLowerCase()}.com`
    };
}

function generateLoad(i: number): Load {
    const brokerName = randomItem(BROKERS);
    const carrierName = randomItem(CARRIERS);

    const pDate = new Date();
    pDate.setDate(pDate.getDate() + randomInt(1, 10));
    const dDate = new Date(pDate);
    dDate.setDate(dDate.getDate() + randomInt(1, 4));

    return {
        id: `LOAD-${i}`,
        loadNumber: `LN${randomInt(100000, 999999)}`,
        bolNumber: `BOL-${randomInt(1000000, 9999999)}`,
        poNumber: `PO${randomInt(50000, 99999)}`,
        broker: {
            ...generateAddress(brokerName),
            mc: `MC${randomInt(100000, 999999)}`,
            logoColor: randomItem(["red", "blue", "green", "orange", "black"])
        },
        carrier: {
            ...generateAddress(carrierName),
            mc: `MC${randomInt(100000, 999999)}`,
            equipment: randomItem(["53' Dry Van", "Reefer"])
        },
        shipper: generateAddress(`Shipper ${randomInt(1, 50)} Inc`),
        consignee: generateAddress(`Receiver ${randomInt(1, 50)} LLC`),

        pickupDate: pDate.toISOString().split('T')[0],
        pickupTime: `${randomInt(8, 11)}:00 AM`,
        deliveryDate: dDate.toISOString().split('T')[0],
        deliveryTime: `${randomInt(1, 4)}:00 PM`,

        commodity: randomItem(COMMODITIES),
        weight: randomInt(15000, 42000),
        qty: randomInt(1, 24),
        units: "Pallets",
        rate: randomInt(800, 3500),

        clauses: [
            randomItem(CLAUSES).text,
            randomItem(CLAUSES).text,
            "Standard 30 days payment terms."
        ],
        instructions: [
            randomItem(INSTRUCTIONS),
            randomItem(INSTRUCTIONS)
        ]
    };
}

// --- HTML Templates ---

const FONTS = [
    "'Arial', sans-serif",
    "'Times New Roman', serif",
    "'Courier New', monospace",
    "'Verdana', sans-serif"
];

function generateRateConHTML(load: Load, styleIndex: number): string {
    const font = FONTS[styleIndex % FONTS.length];
    const isModern = styleIndex % 2 === 0;

    // Simple SVG Logo
    const logo = `<svg width="100" height="40" style="background:${load.broker.logoColor}; border-radius:4px;">
    <text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle" fill="white" font-family="sans-serif" font-weight="bold">LOGO</text>
  </svg>`;

    if (isModern) {
        return `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: ${font}; margin: 40px; color: #333; }
          .header { display: flex; justify-content: space-between; border-bottom: 2px solid #333; padding-bottom: 20px; }
          .title { font-size: 24px; font-weight: bold; text-transform: uppercase; }
          .details-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-top: 20px; }
          .section { border: 1px solid #ddd; padding: 15px; border-radius: 4px; }
          .section-title { font-weight: bold; background: #f0f0f0; padding: 5px; margin: -15px -15px 10px -15px; border-bottom: 1px solid #ddd; }
          .stop { margin-bottom: 15px; border-left: 4px solid ${load.broker.logoColor}; padding-left: 10px; }
          .financials { margin-top: 30px; font-size: 18px; font-weight: bold; text-align: right; }
          .clauses { font-size: 12px; margin-top: 40px; color: #555; }
          .danger { color: red; font-weight: bold; }
        </style>
      </head>
      <body>
        <div class="header">
          <div>
            ${logo}
            <div style="margin-top:10px;">${load.broker.name}</div>
            <div>${load.broker.address}, ${load.broker.city}, ${load.broker.state}</div>
            <div>MC: ${load.broker.mc} | Ph: ${load.broker.phone}</div>
          </div>
          <div style="text-align:right;">
            <div class="title">Rate Confirmation</div>
            <div>Load #: ${load.loadNumber}</div>
            <div>Date: ${new Date().toLocaleDateString()}</div>
          </div>
        </div>

        <div class="details-grid">
          <div class="section">
            <div class="section-title">Carrier</div>
            <div>${load.carrier.name}</div>
            <div>MC: ${load.carrier.mc}</div>
            <div>Equipment: ${load.carrier.equipment}</div>
            <div>Driver: Assigned Driver</div>
          </div>
          <div class="section">
             <div class="section-title">References</div>
             <div><strong>PO #:</strong> ${load.poNumber}</div>
             <div><strong>BOL #:</strong> ${load.bolNumber}</div>
          </div>
        </div>

        <div class="section" style="margin-top:20px;">
          <div class="section-title">Route</div>
          <div class="stop">
            <strong>PICKUP [1]</strong><br>
            ${load.shipper.name}<br>
            ${load.shipper.address}, ${load.shipper.city}, ${load.shipper.state} ${load.shipper.zip}<br>
            Date: ${load.pickupDate} @ ${load.pickupTime}<br>
            Commodity: ${load.commodity} (${load.weight} lbs)
          </div>
          <div class="stop">
            <strong>DELIVERY [2]</strong><br>
            ${load.consignee.name}<br>
            ${load.consignee.address}, ${load.consignee.city}, ${load.consignee.state} ${load.consignee.zip}<br>
            Date: ${load.deliveryDate} @ ${load.deliveryTime}
          </div>
        </div>

        <div class="financials">
          <table style="width:100%; border-collapse:collapse;">
             <tr>
               <td style="text-align:left;">Line Haul</td>
               <td>$${(load.rate * 0.9).toFixed(2)}</td>
             </tr>
              <tr>
               <td style="text-align:left;">Fuel Surcharge</td>
               <td>$${(load.rate * 0.1).toFixed(2)}</td>
             </tr>
             <tr style="background:#eee;">
               <td style="text-align:left; padding:10px;"><strong>TOTAL RATE</strong></td>
               <td style="padding:10px;"><strong>$${load.rate.toFixed(2)}</strong></td>
             </tr>
          </table>
        </div>

        <div class="section" style="margin-top:20px;">
          <div class="section-title">Instructions</div>
          <ul>
            ${load.instructions.map(i => `<li>${i}</li>`).join('')}
          </ul>
        </div>

        <div class="clauses">
          <strong>TERMS & CONDITIONS</strong><br>
          ${load.clauses.map(c => `<p>${c}</p>`).join('')}
          <p>Detention: First 2 hours free. $40/hr thereafter. <strong>MUST NOTIFY broker 1 hour before detention starts.</strong></p>
        </div>
      </body>
      </html>
    `;
    } else {
        // Classic/Fax Style
        return `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: "Courier New", monospace; margin: 40px; font-size: 14px; }
          .box { border: 1px solid black; padding: 5px; margin-bottom: 5px; }
          table { width: 100%; border-collapse: collapse; }
          td, th { border: 1px solid black; padding: 5px; vertical-align: top; }
        </style>
      </head>
      <body>
        <div style="text-align:center; font-weight:bold; font-size: 20px; border:2px solid black; padding:10px; margin-bottom:10px;">
          RATE CONFIRMATION AGREEMENT
        </div>
        
        <table style="margin-bottom:20px;">
          <tr>
            <td width="50%">
              <strong>BROKER:</strong><br>
              ${load.broker.name}<br>
              ${load.broker.address}<br>
              ${load.broker.city}, ${load.broker.state}<br>
              MC: ${load.broker.mc}
            </td>
            <td width="50%">
               <strong>LOAD ID: ${load.loadNumber}</strong><br>
               DATE: ${new Date().toLocaleDateString()}<br>
               PHONE: ${load.broker.phone}<br>
               FAX: 555-000-0000
            </td>
          </tr>
        </table>

        <table>
          <tr>
            <td>
              <strong>CARRIER:</strong><br>
              ${load.carrier.name}<br>
              MC: ${load.carrier.mc}<br>
            </td>
             <td>
               <strong>EQUIPMENT:</strong> ${load.carrier.equipment}<br>
               <strong>DRIVER:</strong> TBD
            </td>
          </tr>
        </table>

         <br>
        <div style="font-weight:bold; border-bottom:1px solid black;">SHIPMENT DETAILS</div>
        <br>

        <table>
          <tr>
            <th width="5%">#</th>
            <th width="10%">Type</th>
            <th width="40%">Location</th>
            <th width="25%">Date/Time</th>
            <th width="20%">Notes</th>
          </tr>
          <tr>
            <td>1</td>
            <td>PU</td>
            <td>
              ${load.shipper.name}<br>
              ${load.shipper.address}<br>
              ${load.shipper.city}, ${load.shipper.state}
            </td>
            <td>${load.pickupDate}<br>${load.pickupTime}</td>
            <td>PO: ${load.poNumber}<br>${load.weight} lbs</td>
          </tr>
           <tr>
            <td>2</td>
            <td>DEL</td>
            <td>
              ${load.consignee.name}<br>
              ${load.consignee.address}<br>
              ${load.consignee.city}, ${load.consignee.state}
            </td>
             <td>${load.deliveryDate}<br>${load.deliveryTime}</td>
            <td></td>
          </tr>
        </table>

        <br>
        <div class="box">
          <strong>RATE AMOUNT: $${load.rate.toFixed(2)} FLAT</strong><br>
          (Includes Fuel & Linehaul)
        </div>

        <div style="margin-top:20px;">
          <strong>NOTES:</strong><br>
          ${load.instructions.join('<br>')}
        </div>

        <div style="margin-top:20px; font-size:10px;">
          <strong>CONTRACT TERMS:</strong><br>
          ${load.clauses.join('<br>')}
          <br>
          DRIVER MUST STAY WITH LOAD AT ALL TIMES.
        </div>
      </body>
      </html>
    `;
    }
}

function generateBOLHTML(load: Load, styleIndex: number): string {
    const font = FONTS[(styleIndex + 1) % FONTS.length]; // varying font from rate con

    return `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: ${font}; margin: 30px; }
        table { width: 100%; border-collapse: collapse; border: 1px solid black; }
        td, th { border: 1px solid black; padding: 4px; font-size: 12px; }
        .header { text-align: center; font-weight: bold; font-size: 18px; margin-bottom: 10px; }
        .bold { font-weight: bold; }
        .u-line { border-bottom: 1px solid black; display:inline-block; width: 100px; }
      </style>
    </head>
    <body>
      <div class="header">STRAIGHT BILL OF LADING - SHORT FORM</div>
      <div style="float:right; font-size:12px;">BOL #: <span class="bold">${load.bolNumber}</span></div>
      <div style="clear:both;"></div>

      <table style="margin-top:5px;">
        <tr>
           <td width="50%">
             <div class="bold">SHIP FROM:</div>
             ${load.shipper.name}<br>
             ${load.shipper.address}<br>
             ${load.shipper.city}, ${load.shipper.state} ${load.shipper.zip}
           </td>
           <td width="50%">
             <div class="bold">SHIP TO:</div>
             ${load.consignee.name}<br>
             ${load.consignee.address}<br>
             ${load.consignee.city}, ${load.consignee.state} ${load.consignee.zip}
           </td>
        </tr>
        <tr>
           <td>
             <div class="bold">THIRD PARTY FREIGHT CHARGES BILL TO:</div>
             ${load.broker.name}<br>
             ${load.broker.address}<br>
             ${load.broker.city}, ${load.broker.state} ${load.broker.zip}
           </td>
           <td>
              <div class="bold">CARRIER NAME:</div>
              ${load.carrier.name}<br>
              SCAC: ${load.carrier.mc.replace("MC", "SCAC")}
              <br><br>
              <div class="bold">Pro Number:</div>
              <div style="border:1px solid black; height: 30px; width: 80%;"></div>
           </td>
        </tr>
      </table>

      <table style="margin-top:10px;">
        <tr style="background:#ccc;">
           <th># Pkgs</th>
           <th>HM</th>
           <th>Description of Articles, Special Marks and Exceptions</th>
           <th>Weight (lbs)</th>
           <th>Class</th>
        </tr>
        <tr>
          <td>${load.qty} ${load.units}</td>
          <td></td>
          <td>${load.commodity}<br><span style="font-size:10px;">PO: ${load.poNumber}</span></td>
          <td>${load.weight}</td>
          <td>55</td>
        </tr>
        <tr>
           <td>&nbsp;</td>
           <td></td>
           <td></td>
           <td></td>
           <td></td>
        </tr>
         <tr>
           <td><strong>TOTAL: ${load.qty}</strong></td>
           <td></td>
           <td></td>
           <td><strong>${load.weight}</strong></td>
           <td></td>
        </tr>
      </table>

      <div style="margin-top:10px; font-size:10px;">
         RECEIVED, subject to the classifications and tariffs in effect on the date of the issue of this Bill of Lading.
      </div>

      <table style="margin-top:20px; border:0;">
         <tr style="border:0;">
            <td style="border:0; width:33%;">
              <div class="bold">SHIPPER SIGNATURE</div>
              <br><br>
              __________________________<br>
              Date: ${load.pickupDate}
            </td>
            <td style="border:0; width:33%;">
              <div class="bold">CARRIER SIGNATURE</div>
               <br><br>
              __________________________<br>
               Date:
            </td>
            <td style="border:0; width:33%;">
              <div class="bold">RECEIVER SIGNATURE</div>
               <br><br>
              __________________________<br>
               Date:
            </td>
         </tr>
      </table>
    </body>
    </html>
  `;
}

// --- Main ---

async function main() {
    await ensureDir(OUTPUT_DIR);

    for (let i = 1; i <= 10; i++) {
        const load = generateLoad(i);

        const rateConHTML = generateRateConHTML(load, i);
        const bolHTML = generateBOLHTML(load, i);

        await Deno.writeTextFile(join(OUTPUT_DIR, `load_${i}_rate_con.html`), rateConHTML);
        await Deno.writeTextFile(join(OUTPUT_DIR, `load_${i}_bol.html`), bolHTML);

        console.log(`Generated Load ${i} files.`);
    }
}

main();
