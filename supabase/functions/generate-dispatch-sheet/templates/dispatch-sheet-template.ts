
export const dispatchSheetTemplate = `
<!DOCTYPE html>
<html>
<head>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');
        @import url('https://fonts.googleapis.com/css2?family=Noto+Sans+Gurmukhi:wght@400;500;700&display=swap');

        :root {
            --primary: #2563eb;
            --primary-dark: #1e40af;
            --gray-50: #f9fafb;
            --gray-100: #f3f4f6;
            --gray-200: #e5e7eb;
            --gray-500: #6b7280;
            --gray-700: #374151;
            --gray-900: #111827;
            --danger: #ef4444;
            --success: #10b981;
            --warning: #f59e0b;
        }

        body { 
            font-family: 'Inter', sans-serif; 
            color: var(--gray-700);
            line-height: 1.5; 
            background: #fff;
            margin: 0;
            padding: 40px;
            -webkit-font-smoothing: antialiased;
        }

        .container {
            max-width: 1000px;
            margin: 0 auto;
        }

        /* Utils */
        .text-sm { font-size: 0.875rem; }
        .text-xs { font-size: 0.75rem; }
        .font-bold { font-weight: 700; }
        .text-gray-500 { color: var(--gray-500); }
        .uppercase { text-transform: uppercase; letter-spacing: 0.05em; }
        
        /* Cards */
        .card {
            background: white;
            border: 1px solid var(--gray-200);
            border-radius: 12px;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05), 0 2px 4px -1px rgba(0, 0, 0, 0.03);
            margin-bottom: 24px;
            overflow: hidden;
        }

        .card-header {
            background: var(--gray-50);
            padding: 16px 24px;
            border-bottom: 1px solid var(--gray-200);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .card-title {
            font-size: 1rem;
            font-weight: 700;
            color: var(--gray-900);
            text-transform: uppercase;
            letter-spacing: 0.05em;
            margin: 0;
        }

        .card-body {
            padding: 24px;
        }

        /* Header Section */
        .header-grid {
            display: grid;
            grid-template-columns: 1fr auto;
            gap: 40px;
            margin-bottom: 32px;
            align-items: start;
        }

        .brand-section {
            display: flex;
            flex-direction: column;
            gap: 12px;
        }

        .org-logo {
            height: 60px;
            object-fit: contain;
            object-position: left;
        }

        .org-name {
            font-size: 1.5rem;
            font-weight: 800;
            color: var(--gray-900);
            line-height: 1.2;
        }

        .org-details {
            font-size: 0.925rem;
            color: var(--gray-500);
            line-height: 1.6;
        }

        .meta-grid {
            display: grid;
            grid-template-columns: auto auto;
            gap: 8px 24px;
            text-align: right;
            background: var(--gray-50);
            padding: 20px;
            border-radius: 12px;
            border: 1px solid var(--gray-200);
        }

        .meta-label {
            color: var(--gray-500);
            font-size: 0.75rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.05em;
        }

        .meta-value {
            color: var(--gray-900);
            font-weight: 700;
            font-size: 0.925rem;
        }

        /* Itinerary */
        .timeline {
            position: relative;
        }

        .stop-row {
            display: grid;
            grid-template-columns: 100px 1fr 180px;
            gap: 24px;
            padding: 20px 0;
            border-bottom: 1px solid var(--gray-200);
        }

        .stop-row:last-child {
            border-bottom: none;
            padding-bottom: 0;
        }

        .stop-row:first-child {
            padding-top: 0;
        }

        .stop-badge {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 0.75rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: white;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }

        .bg-pickup { background-color: var(--success); }
        .bg-delivery { background-color: var(--danger); }
        .bg-other { background-color: var(--gray-500); }

        .location-group h4 {
            margin: 0 0 4px 0;
            color: var(--gray-900);
            font-size: 1.1rem;
        }

        .location-address {
            display: block;
            color: var(--primary);
            text-decoration: none;
            font-weight: 500;
        }
        
        .location-address:hover { text-decoration: underline; }

        .stop-notes {
            margin-top: 8px;
            font-size: 0.875rem;
            color: var(--danger);
            background: #fef2f2;
            padding: 8px 12px;
            border-radius: 6px;
            border-left: 3px solid var(--danger);
            display: inline-block;
        }

        .time-group {
            text-align: right;
            font-weight: 600;
            color: var(--gray-900);
        }

        /* Requirements Grid used for Equipment & Transit */
        .req-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 24px;
            margin-bottom: 24px;
        }

        .req-card {
            background: var(--gray-50);
            border: 1px solid var(--gray-200);
            border-radius: 8px;
            padding: 16px;
        }

        .req-title {
            font-size: 0.75rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--gray-500);
            font-weight: 700;
            margin-bottom: 8px;
        }

        .req-content {
            font-weight: 500;
            font-size: 0.925rem;
            color: var(--gray-900);
        }

        /* Instructions */
        .instruction-item {
            display: flex;
            gap: 16px;
            padding: 16px;
            border-bottom: 1px solid var(--gray-100);
        }

        .instruction-item:last-child { border-bottom: none; }

        .check-circle {
            width: 20px;
            height: 20px;
            border: 2px solid var(--gray-200);
            border-radius: 50%;
            flex-shrink: 0;
            margin-top: 2px;
        }

        .inst-title {
            font-weight: 700;
            color: var(--gray-900);
            margin-bottom: 4px;
        }

        .inst-text {
            color: var(--gray-500);
            font-size: 0.925rem;
        }

        .punjabi-text {
            font-family: 'Noto Sans Gurmukhi', sans-serif;
            color: var(--danger);
            font-size: 0.925rem;
            margin-top: 4px;
            display: block;
            font-weight: 500;
        }

        /* Footer */
        .footer {
            margin-top: 60px;
            border-top: 1px solid var(--gray-200);
            padding-top: 24px;
            display: flex;
            justify-content: space-between;
            align-items: flex-end;
        }

        .signature-line {
            width: 300px;
            border-top: 1px solid var(--gray-900);
            padding-top: 8px;
            font-size: 0.75rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            font-weight: 600;
        }

        .disclaimer {
            font-size: 0.75rem;
            color: var(--gray-500);
            max-width: 400px;
            text-align: right;
        }
    </style>
</head>
<body>

<div class="container">
    <!-- Header -->
    <div class="header-grid">
        <div class="brand-section">
            <img src="{{{orgLogoUrl}}}" class="org-logo" alt="Logo" />
            <div>
                <div class="org-name">{{orgName}}</div>
                <div class="org-details">{{{orgAddress}}}</div>
                {{#if mcDotNumber}}
                <div class="org-details" style="font-weight: 600; color: var(--gray-700); margin-top:4px;">DOT: {{mcDotNumber}}</div>
                {{/if}}
            </div>
        </div>
        
        <div class="meta-grid">
            <div class="meta-label">Trip ID</div>
            <div class="meta-value">{{tripId}}</div>
            
            <div class="meta-label">Reference</div>
            <div class="meta-value">{{refIds}}</div>
            
            <div class="meta-label">Broker</div>
            <div class="meta-value">{{brokerName}}</div>
            
            <div class="meta-label">Date</div>
            <div class="meta-value">{{generatedDate}}</div>
        </div>
    </div>

    <!-- Itinerary Card -->
    <div class="card">
        <div class="card-header">
            <h3 class="card-title">Itinerary</h3>
        </div>
        <div class="card-body">
            {{#each stops}}
            <div class="stop-row">
                <div>
                    <span class="stop-badge {{badgeClass}}">{{stopType}}</span>
                </div>
                <div class="location-group">
                    <h4>{{cityState}}</h4>
                    <a href="{{mapLink}}" target="_blank" class="location-address">
                        {{address}} ↗
                    </a>
                    {{#if notes}}
                        <div class="stop-notes">{{notes}}</div>
                    {{/if}}
                </div>
                <div class="time-group">
                    {{scheduledArrival}}
                </div>
            </div>
            {{/each}}
        </div>
    </div>

    <!-- Requirements Grid -->
    <div class="req-grid">
        <div class="req-card">
            <div class="req-title">Equipment Required</div>
            <div class="req-content">{{equipment}}</div>
        </div>
        <div class="req-card">
            <div class="req-title">Transit Requirements</div>
            <div class="req-content">{{transit}}</div>
        </div>
    </div>

    <!-- Instructions Card -->
    <div class="card">
        <div class="card-header">
            <h3 class="card-title">Dispatcher Instructions</h3>
        </div>
        <!-- Remove default padding for list flush look -->
        <div class="card-body" style="padding: 0;">
            {{#each instructions}}
            <div class="instruction-item">
                <div class="check-circle"></div>
                <div style="flex:1;">
                    <div class="inst-title">{{title_en}}</div>
                    <div class="inst-text">{{description_en}}</div>
                    {{#if hasPunjabi}}
                    <span class="punjabi-text">
                        <strong>{{title_punjab}}</strong> {{description_punjab}}
                    </span>
                    {{/if}}
                </div>
            </div>
            {{/each}}
            {{#unless instructions}}
                <div style="padding: 24px; text-align: center; color: var(--gray-500); font-style: italic;">
                    No specific instructions.
                </div>
            {{/unless}}
        </div>
    </div>

    <!-- Footer -->
    <div class="footer">
        <div class="signature-line">
            Driver Signature
        </div>
        <div class="disclaimer">
            Powered by TruckMate. Please drive safely and comply with all simple DOT regulations and transit & safety requirements.
        </div>
    </div>
</div>

</body>
</html>
`;
