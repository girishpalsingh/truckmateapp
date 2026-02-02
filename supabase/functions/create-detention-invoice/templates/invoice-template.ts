/**
 * Detention Invoice Template
 * Matches the professional styling of the dispatch sheet template
 */

export const invoiceTemplate = `
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

        /* Invoice Title */
        .invoice-title {
            text-align: center;
            font-size: 2rem;
            font-weight: 800;
            color: var(--danger);
            text-transform: uppercase;
            letter-spacing: 0.1em;
            margin-bottom: 32px;
            padding: 16px;
            background: linear-gradient(135deg, #fef2f2 0%, #fee2e2 100%);
            border-radius: 12px;
            border: 2px solid var(--danger);
        }

        /* Details Grid */
        .details-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 24px;
        }

        .detail-card {
            background: var(--gray-50);
            border: 1px solid var(--gray-200);
            border-radius: 8px;
            padding: 16px;
        }

        .detail-title {
            font-size: 0.75rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--gray-500);
            font-weight: 700;
            margin-bottom: 8px;
        }

        .detail-content {
            font-weight: 500;
            font-size: 0.925rem;
            color: var(--gray-900);
        }

        /* Timeline */
        .timeline-row {
            display: grid;
            grid-template-columns: 100px 1fr 1fr;
            gap: 24px;
            padding: 16px 0;
            border-bottom: 1px solid var(--gray-200);
        }

        .timeline-row:last-child {
            border-bottom: none;
        }

        .time-badge {
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

        .bg-start { background-color: var(--success); }
        .bg-end { background-color: var(--danger); }

        /* Billing Table */
        .billing-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 16px;
        }

        .billing-table th {
            text-align: left;
            padding: 12px 16px;
            background: var(--gray-100);
            font-size: 0.75rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--gray-500);
            font-weight: 700;
            border-bottom: 2px solid var(--gray-200);
        }

        .billing-table th:last-child {
            text-align: right;
        }

        .billing-table td {
            padding: 16px;
            border-bottom: 1px solid var(--gray-100);
            color: var(--gray-700);
        }

        .billing-table td:last-child {
            text-align: right;
            font-weight: 600;
        }

        .total-row td {
            background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
            font-weight: 700;
            font-size: 1.1rem;
            color: var(--primary-dark);
            border-bottom: none;
        }

        /* Photo Section */
        .photo-section {
            text-align: center;
        }

        .photo-section img {
            max-width: 100%;
            max-height: 300px;
            border-radius: 8px;
            border: 2px solid var(--gray-200);
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }

        /* Footer */
        .footer {
            margin-top: 40px;
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
            {{#if orgLogoUrl}}
            <img src="{{{orgLogoUrl}}}" class="org-logo" alt="Logo" />
            {{/if}}
            <div>
                <div class="org-name">{{orgName}}</div>
                <div class="org-details">{{{orgAddress}}}</div>
            </div>
        </div>
        
        <div class="meta-grid">
            <div class="meta-label">Invoice #</div>
            <div class="meta-value">{{invoiceNumber}}</div>
            
            <div class="meta-label">Date</div>
            <div class="meta-value">{{generatedDate}}</div>
            
            <div class="meta-label">Broker</div>
            <div class="meta-value">{{brokerName}}</div>
            
            <div class="meta-label">Load #</div>
            <div class="meta-value">{{loadNumber}}</div>
        </div>
    </div>

    <!-- Invoice Title -->
    <div class="invoice-title">⏱ Detention Invoice</div>

    <!-- Reference Details Card -->
    <div class="card">
        <div class="card-header">
            <h3 class="card-title">📋 Reference Information</h3>
        </div>
        <div class="card-body">
            <div class="details-grid">
                {{#if rateConId}}
                <div class="detail-card">
                    <div class="detail-title">Rate Con ID</div>
                    <div class="detail-content">#{{rateConId}}</div>
                </div>
                {{/if}}
                {{#if brokerMcNumber}}
                <div class="detail-card">
                    <div class="detail-title">Broker MC #</div>
                    <div class="detail-content">{{brokerMcNumber}}</div>
                </div>
                {{/if}}
                {{#if poNumber}}
                <div class="detail-card">
                    <div class="detail-title">PO Number</div>
                    <div class="detail-content">{{poNumber}}</div>
                </div>
                {{/if}}
                {{#if bolNumber}}
                <div class="detail-card">
                    <div class="detail-title">BOL Number</div>
                    <div class="detail-content">{{bolNumber}}</div>
                </div>
                {{/if}}
                {{#each referenceNumbers}}
                <div class="detail-card">
                    <div class="detail-title">{{this.refType}}</div>
                    <div class="detail-content">{{this.refValue}}</div>
                </div>
                {{/each}}
            </div>
        </div>
    </div>


    <!-- Facility Card -->
    <div class="card">
        <div class="card-header">
            <h3 class="card-title">📍 Facility Details</h3>
        </div>
        <div class="card-body">
            <div class="details-grid">
                <div class="detail-card">
                    <div class="detail-title">Facility Name</div>
                    <div class="detail-content">{{facilityName}}</div>
                </div>
                <div class="detail-card">
                    <div class="detail-title">Address</div>
                    <div class="detail-content">{{facilityAddress}}</div>
                </div>
            </div>
        </div>
    </div>

    <!-- Detention Timeline Card -->
    <div class="card">
        <div class="card-header">
            <h3 class="card-title">⏱ Detention Timeline</h3>
        </div>
        <div class="card-body">
            <div class="timeline-row">
                <div><span class="time-badge bg-start">Arrival</span></div>
                <div>
                    <strong>{{startTime}}</strong>
                    <div style="font-size: 0.875rem; color: var(--gray-500);">GPS: {{startCoordinates}}</div>
                </div>
                <div></div>
            </div>
            <div class="timeline-row">
                <div><span class="time-badge bg-end">Departure</span></div>
                <div>
                    <strong>{{endTime}}</strong>
                    <div style="font-size: 0.875rem; color: var(--gray-500);">GPS: {{endCoordinates}}</div>
                </div>
                <div style="text-align: right;">
                    <div style="font-size: 0.75rem; color: var(--gray-500); text-transform: uppercase;">Total Duration</div>
                    <div style="font-size: 1.25rem; font-weight: 700; color: var(--gray-900);">{{totalDuration}}</div>
                </div>
            </div>
        </div>
    </div>

    <!-- Billing Card -->
    <div class="card">
        <div class="card-header">
            <h3 class="card-title">💰 Billing Details</h3>
        </div>
        <div class="card-body" style="padding: 0;">
            <table class="billing-table">
                <thead>
                    <tr>
                        <th>Description</th>
                        <th>Rate</th>
                        <th>Billable Hours</th>
                        <th>Amount</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td>
                            <strong>Detention Charge</strong>
                            <div style="font-size: 0.875rem; color: var(--gray-500);">Time exceeding {{freeTime}} free time allowance</div>
                        </td>
                        <td>${"$"}{{ratePerHour}}/hr</td>
                        <td>{{payableHours}} hrs</td>
                        <td>${"$"}{{totalDue}}</td>
                    </tr>
                    <tr class="total-row">
                        <td colspan="3" style="text-align: right;">Total Due</td>
                        <td>${"$"}{{totalDue}} {{currency}}</td>
                    </tr>
                </tbody>
            </table>
        </div>
    </div>

    {{#if photoUrl}}
    <!-- Photo Evidence Card -->
    <div class="card">
        <div class="card-header">
            <h3 class="card-title">📷 Photo Evidence</h3>
        </div>
        <div class="card-body photo-section">
            <img src="{{{photoUrl}}}" alt="Detention Evidence" />
            <div style="margin-top: 12px; font-size: 0.875rem; color: var(--gray-500);">
                Captured: {{photoTime}}
            </div>
        </div>
    </div>
    {{/if}}

    <!-- Footer -->
    <div class="footer">
        <div class="signature-line">
            Authorized Signature
        </div>
        <div class="disclaimer">
            This invoice is generated based on GPS-verified arrival and departure times. 
            Powered by TruckMate.
        </div>
    </div>
</div>

</body>
</html>
`;
