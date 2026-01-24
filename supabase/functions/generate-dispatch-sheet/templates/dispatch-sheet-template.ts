export const dispatchSheetTemplate = `
<!DOCTYPE html>
<html>
<head>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap');
        @import url('https://fonts.googleapis.com/css2?family=Noto+Sans+Gurmukhi:wght@400;500;700&display=swap');

        body { 
            font-family: 'Inter', sans-serif; 
            color: #1f2937; 
            line-height: 1.5; 
            padding: 0; 
            margin: 0;
            max-width: 100%;
        }

        .container {
            padding: 40px;
        }

        /* Header */
        .header-table {
            width: 100%;
            margin-bottom: 30px;
            border-bottom: 2px solid #e5e7eb;
            padding-bottom: 20px;
        }

        .org-branding {
            vertical-align: top;
        }

        .org-logo {
            max-height: 60px;
            max-width: 200px;
            object-fit: contain;
            margin-bottom: 10px;
        }

        .org-name {
            font-size: 20px;
            font-weight: 700;
            color: #111827;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .org-address {
            font-size: 12px;
            color: #6b7280;
            white-space: pre-line;
            margin-top: 4px;
        }

        .doc-info {
            text-align: right;
            vertical-align: top;
        }

        .doc-title {
            font-size: 24px;
            font-weight: 800;
            color: #2563eb;
            text-transform: uppercase;
            margin: 0;
        }

        .meta-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
        }

        .meta-label {
            font-size: 11px;
            text-transform: uppercase;
            color: #6b7280;
            font-weight: 600;
            text-align: right;
            padding-right: 8px;
            padding-bottom: 4px;
        }

        .meta-value {
            font-size: 13px;
            font-weight: 600;
            color: #374151;
            text-align: right;
            padding-bottom: 4px;
        }

        /* Sections */
        .section-title { 
            font-size: 14px;
            font-weight: 700;
            text-transform: uppercase;
            color: #374151;
            border-bottom: 2px solid #2563eb;
            padding-bottom: 6px;
            margin-top: 25px;
            margin-bottom: 15px;
            letter-spacing: 0.5px;
        }

        /* Itinerary Table */
        .stops-table { 
            width: 100%; 
            border-collapse: collapse; 
            margin-top: 10px; 
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }

        .stops-table th { 
            text-align: left; 
            background: #f3f4f6; 
            padding: 12px; 
            border-bottom: 1px solid #e5e7eb; 
            font-size: 11px; 
            text-transform: uppercase; 
            color: #4b5563;
            font-weight: 600;
        }

        .stops-table td { 
            padding: 12px; 
            border-bottom: 1px solid #e5e7eb; 
            font-size: 13px; 
            vertical-align: top;
        }

        .stop-badge { 
            display: inline-block; 
            padding: 4px 8px; 
            border-radius: 4px; 
            font-size: 11px; 
            font-weight: bold; 
            color: white; 
            text-transform: uppercase;
            min-width: 60px;
            text-align: center;
        }

        .bg-pickup { background-color: #059669; }
        .bg-delivery { background-color: #dc2626; }
        .bg-other { background-color: #6b7280; }

        .location-name {
            font-weight: 700;
            display: block;
            margin-bottom: 2px;
        }

        .location-address {
            color: #6b7280;
            font-size: 12px;
        }
        
        .stop-notes {
            color: #ef4444; 
            font-weight: 500;
        }

        /* Requirements Grid */
        .req-grid {
            display: table;
            width: 100%;
            margin-top: 10px;
        }
        .req-col {
            display: table-cell;
            width: 50%;
            vertical-align: top;
            padding-right: 20px;
        }
        .req-box {
            background: #f9fafb;
            border: 1px solid #e5e7eb;
            padding: 12px;
            border-radius: 6px;
            font-size: 13px;
        }

        /* Instructions */
        .instruction-container {
            background: #fff;
            border: 1px solid #e5e7eb;
            border-radius: 6px;
            overflow: hidden;
        }

        .instruction-item {
            border-bottom: 1px solid #f3f4f6;
            padding: 12px 15px;
            display: flex;
            align-items: flex-start;
        }

        .instruction-item:last-child {
            border-bottom: none;
        }

        .checkbox {
            width: 16px;
            height: 16px;
            border: 2px solid #d1d5db;
            border-radius: 3px;
            margin-right: 12px;
            margin-top: 3px;
            flex-shrink: 0;
        }

        .instruction-content {
            flex: 1;
        }

        .instruction-title {
            font-weight: 700;
            font-size: 14px;
            color: #111827;
            margin-bottom: 2px;
        }

        .instruction-desc {
            font-size: 13px;
            color: #4b5563;
        }

        .punjabi-text {
            font-family: 'Noto Sans Gurmukhi', sans-serif;
            color: #dc2626; /* Dark red */
            font-weight: 500;
            margin-top: 2px;
            display: block;
            font-size: 13px;
        }

        .no-data {
             padding:15px; text-align:center; color:#6b7280; font-style:italic;
        }

        /* Footer & Signature */
        .footer {
            margin-top: 60px;
            page-break-inside: avoid;
        }

        .signature-box {
            border-top: 1px solid #9ca3af;
            width: 300px;
            padding-top: 8px;
            margin-top: 40px;
        }

        .signature-label {
            font-size: 12px;
            color: #6b7280;
            text-transform: uppercase;
            font-weight: 600;
        }

        .disclaimer {
            margin-top: 30px;
            font-size: 10px;
            color: #9ca3af;
            text-align: center;
            border-top: 1px solid #f3f4f6;
            padding-top: 10px;
        }
    </style>
</head>
<body>
<div class="container">
    <table class="header-table">
        <tr>
            <td class="org-branding">
                {{#if orgLogoUrl}}
                <img src="{{orgLogoUrl}}" class="org-logo" />
                {{/if}}
                <div class="org-name">{{orgName}}</div>
                <div class="org-address">{{{orgAddress}}}</div>
                {{#if mcDotNumber}}
                <div class="org-address" style="margin-top:2px; font-weight:600;">DOT: {{mcDotNumber}}</div>
                {{/if}}
            </td>
            <td class="doc-info">
                <h1 class="doc-title">Dispatcher Sheet</h1>
                <table class="meta-table" align="right">
                    <tr>
                        <td class="meta-label">Trip ID</td>
                        <td class="meta-value">{{tripId}}</td>
                    </tr>
                    <tr>
                        <td class="meta-label">Reference ID</td>
                        <td class="meta-value">{{refIds}}</td>
                    </tr>
                    <tr>
                        <td class="meta-label">Broker</td>
                        <td class="meta-value">{{brokerName}}</td>
                    </tr>
                    <tr>
                        <td class="meta-label">Date</td>
                        <td class="meta-value">{{generatedDate}}</td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>

    <div class="section-title">Itinerary</div>
    <table class="stops-table">
        <thead>
            <tr>
                <th width="12%">Type</th>
                <th width="45%">Location</th>
                <th width="25%">Time</th>
                <th width="18%">Notes</th>
            </tr>
        </thead>
        <tbody>
            {{#each stops}}
            <tr>
                <td>
                    <span class="stop-badge {{badgeClass}}">
                        {{stopType}}
                    </span>
                </td>
                <td>
                    <span class="location-name">{{cityState}}</span>
                    <a href="{{mapLink}}" target="_blank" class="location-address" style="text-decoration:underline; color:#2563eb;">{{address}}</a>
                </td>
                <td><strong>{{scheduledArrival}}</strong></td>
                <td><span class="stop-notes">{{notes}}</span></td>
            </tr>
            {{/each}}
        </tbody>
    </table>

    <div class="req-grid">
        <div class="req-col">
            <div class="section-title" style="margin-top: 0;">Equipment</div>
            <div class="req-box">
                {{#if equipment}} {{equipment}} {{else}} Standard {{/if}}
            </div>
        </div>
        <div class="req-col" style="padding-right:0;">
            <div class="section-title" style="margin-top: 0;">Transit Req</div>
            <div class="req-box">
                {{#if transit}} {{transit}} {{else}} Standard {{/if}}
            </div>
        </div>
    </div>

    <div class="section-title">Dispatcher Instructions</div>
    <div class="instruction-container">
        {{#each instructions}}
        <div class="instruction-item">
            <div class="checkbox"></div>
            <div class="instruction-content">
                <div class="instruction-title">{{title_en}}</div>
                <div class="instruction-desc">{{description_en}}</div>
                {{#if hasPunjabi}}
                <span class="punjabi-text"><strong>{{title_punjab}}</strong> {{description_punjab}}</span>
                {{/if}}
            </div>
        </div>
        {{else}}
         <div class="no-data">No specific instructions for this load.</div>
        {{/each}}
    </div>

    <div class="footer">
        <div class="signature-box">
            <div class="signature-label">Driver Signature</div>
        </div>
        
        <div class="disclaimer">
            Generated by TruckMate. Please drive safely and comply with all DOT regulations.
        </div>
    </div>
</div>
</body>
</html>
`;
