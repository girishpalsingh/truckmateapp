'use client';

/**
 * Dispatch Sheet Page
 * Displays rate con data with all editable fields and generates dispatch sheets
 */
import React, { useState, useEffect, Suspense } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { useRouter, useSearchParams } from 'next/navigation';
import { getRateConfirmation, RateConfirmation, RCStop } from '@/services/upload';
import { generateDispatchSheet, getDispatchSheet } from '@/services/dispatch';
import { ThemeToggle } from '@/components/common/ThemeToggle';
import '@/components/common/common.css';
import './dispatch-sheet.css';

// Extended stop interface with editable fields
interface EditableStop extends RCStop {
  facility_address_punjabi?: string;
  special_instructions_punjabi?: string;
}

// Wrap the main content in a component that uses useSearchParams
function DispatchSheetContent() {
  const { isAuthenticated, isLoading, profile, organization, logout } = useAuth();
  const router = useRouter();
  const searchParams = useSearchParams();
  const rateConId = searchParams.get('id');
  
  const [rateCon, setRateCon] = useState<RateConfirmation | null>(null);
  const [stops, setStops] = useState<EditableStop[]>([]);
  const [isLoadingData, setIsLoadingData] = useState(true);
  const [isGenerating, setIsGenerating] = useState(false);
  const [error, setError] = useState('');
  const [dispatchSheetUrl, setDispatchSheetUrl] = useState<string | null>(null);
  
  // Editable rate con fields
  const [editedData, setEditedData] = useState<Partial<RateConfirmation> & {
    broker_name_punjabi?: string;
    carrier_name_punjabi?: string;
    special_notes?: string;
    special_notes_punjabi?: string;
  }>({});

  // Redirect to login if not authenticated
  useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      router.push('/');
    }
  }, [isAuthenticated, isLoading, router]);

  // Load rate confirmation data
  useEffect(() => {
    if (rateConId && isAuthenticated) {
      loadRateConfirmation();
    }
  }, [rateConId, isAuthenticated]);

  // Load rate confirmation from database
  const loadRateConfirmation = async () => {
    if (!rateConId) return;
    
    setIsLoadingData(true);
    setError('');

    try {
      const result = await getRateConfirmation(rateConId);
      
      if (result.success && result.rateCon) {
        setRateCon(result.rateCon);
        setStops(result.stops || []);
        setEditedData(result.rateCon);
        
        // Check if dispatch sheet already exists
        const existingSheet = await getDispatchSheet(rateConId);
        if (existingSheet.success && existingSheet.signedUrl) {
          setDispatchSheetUrl(existingSheet.signedUrl);
        }
      } else {
        setError(result.error || 'Failed to load rate confirmation');
      }
    } catch (err: unknown) {
      const errorMessage = err instanceof Error ? err.message : 'An error occurred';
      setError(errorMessage);
    } finally {
      setIsLoadingData(false);
    }
  };

  // Handle rate con field changes
  const handleFieldChange = (field: string, value: string | number) => {
    setEditedData(prev => ({
      ...prev,
      [field]: value
    }));
  };

  // Handle stop field changes
  const handleStopChange = (stopIndex: number, field: string, value: string) => {
    setStops(prev => {
      const updated = [...prev];
      updated[stopIndex] = {
        ...updated[stopIndex],
        [field]: value
      };
      return updated;
    });
  };

  // Generate dispatch sheet
  const handleGenerate = async () => {
    if (!rateConId) return;
    
    setIsGenerating(true);
    setError('');

    try {
      const result = await generateDispatchSheet(rateConId);
      
      if (result.success && result.url) {
        setDispatchSheetUrl(result.url);
      } else {
        setError(result.error || 'Failed to generate dispatch sheet');
      }
    } catch (err: unknown) {
      const errorMessage = err instanceof Error ? err.message : 'An error occurred';
      setError(errorMessage);
    } finally {
      setIsGenerating(false);
    }
  };

  // Handle logout
  const handleLogout = async () => {
    await logout();
    router.push('/');
  };

  // Get risk badge class
  const getRiskBadgeClass = (risk: string) => {
    switch (risk) {
      case 'RED': return 'badge-red';
      case 'YELLOW': return 'badge-yellow';
      case 'GREEN': return 'badge-green';
      default: return '';
    }
  };

  // Show loading while checking auth
  if (isLoading || isLoadingData) {
    return (
      <div className="flex-center" style={{ minHeight: '100vh' }}>
        <div style={{ textAlign: 'center' }}>
          <div className="spinner" style={{ width: '2.5rem', height: '2.5rem' }}></div>
          <p style={{ marginTop: '1rem', color: 'var(--text-secondary)' }}>
            Loading rate confirmation...
          </p>
        </div>
      </div>
    );
  }

  // No rate con ID provided
  if (!rateConId) {
    return (
      <div className="dispatch-page">
        <div className="dispatch-error-container flex-center">
          <div className="card" style={{ textAlign: 'center', maxWidth: '400px' }}>
            <h2>No Rate Confirmation Selected</h2>
            <p style={{ color: 'var(--text-secondary)', marginTop: '1rem' }}>
              Please upload a rate confirmation first.
            </p>
            <button 
              onClick={() => router.push('/upload')}
              className="btn btn-primary"
              style={{ marginTop: '1.5rem' }}
            >
              Go to Upload
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="dispatch-page">
      {/* Header */}
      <header className="dispatch-header">
        <div className="dispatch-header-content container">
          <div className="dispatch-brand">
            <button onClick={() => router.push('/upload')} className="dispatch-back-btn">
              ← Back
            </button>
            <span className="dispatch-brand-name">Dispatch Sheet / ਡਿਸਪੈਚ ਸ਼ੀਟ</span>
          </div>
          <div className="dispatch-user-info">
            <span className="dispatch-user-name">{profile?.full_name}</span>
            <ThemeToggle />
            <button onClick={handleLogout} className="btn btn-secondary btn-sm">
              Logout
            </button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="dispatch-main container">
        {error && (
          <div className="alert alert-error fade-in" style={{ marginBottom: '1.5rem' }}>
            <span>⚠️</span>
            <span>{error}</span>
          </div>
        )}

        <div className="dispatch-grid">
          {/* Left Column: Rate Con Details */}
          <div className="dispatch-details slide-up">
            <div className="card">
              <div className="card-header flex-between">
                <h2 className="card-title">Rate Confirmation / ਰੇਟ ਕਨਫਰਮੇਸ਼ਨ</h2>
                {rateCon?.risk_score && (
                  <span className={`badge ${getRiskBadgeClass(rateCon.risk_score)}`}>
                    {rateCon.risk_score} RISK
                  </span>
                )}
              </div>

              {/* Broker Info */}
              <section className="dispatch-section">
                <h3 className="dispatch-section-title">Broker Information / ਬ੍ਰੋਕਰ ਜਾਣਕਾਰੀ</h3>
                <div className="dispatch-form-grid">
                  <div className="input-group">
                    <label className="input-label">Broker Name / ਬ੍ਰੋਕਰ ਦਾ ਨਾਮ</label>
                    <input
                      type="text"
                      className="input"
                      value={editedData.broker_name || ''}
                      onChange={(e) => handleFieldChange('broker_name', e.target.value)}
                      placeholder="Enter broker name"
                    />
                  </div>
                  <div className="input-group">
                    <label className="input-label">Broker Name (ਪੰਜਾਬੀ)</label>
                    <input
                      type="text"
                      className="input"
                      value={editedData.broker_name_punjabi || ''}
                      onChange={(e) => handleFieldChange('broker_name_punjabi', e.target.value)}
                      placeholder="ਬ੍ਰੋਕਰ ਦਾ ਨਾਮ ਪੰਜਾਬੀ ਵਿੱਚ"
                    />
                  </div>
                  <div className="input-group">
                    <label className="input-label">MC Number / ਐਮਸੀ ਨੰਬਰ</label>
                    <input
                      type="text"
                      className="input"
                      value={editedData.broker_mc || ''}
                      onChange={(e) => handleFieldChange('broker_mc', e.target.value)}
                      placeholder="MC-123456"
                    />
                  </div>
                  <div className="input-group">
                    <label className="input-label">Phone / ਫ਼ੋਨ</label>
                    <input
                      type="tel"
                      className="input"
                      value={editedData.broker_phone || ''}
                      onChange={(e) => handleFieldChange('broker_phone', e.target.value)}
                      placeholder="+1 (555) 123-4567"
                    />
                  </div>
                  <div className="input-group full-width">
                    <label className="input-label">Email / ਈਮੇਲ</label>
                    <input
                      type="email"
                      className="input"
                      value={editedData.broker_email || ''}
                      onChange={(e) => handleFieldChange('broker_email', e.target.value)}
                      placeholder="broker@company.com"
                    />
                  </div>
                </div>
              </section>

              {/* Load Info */}
              <section className="dispatch-section">
                <h3 className="dispatch-section-title">Load Information / ਲੋਡ ਜਾਣਕਾਰੀ</h3>
                <div className="dispatch-form-grid">
                  <div className="input-group">
                    <label className="input-label">Load ID / ਲੋਡ ਆਈਡੀ</label>
                    <input
                      type="text"
                      className="input"
                      value={editedData.load_id || ''}
                      onChange={(e) => handleFieldChange('load_id', e.target.value)}
                      placeholder="LD-12345"
                    />
                  </div>
                  <div className="input-group">
                    <label className="input-label">Total Rate ($) / ਕੁੱਲ ਰੇਟ</label>
                    <input
                      type="number"
                      className="input"
                      value={editedData.total_rate || ''}
                      onChange={(e) => handleFieldChange('total_rate', parseFloat(e.target.value))}
                      placeholder="1500.00"
                    />
                  </div>
                  <div className="input-group">
                    <label className="input-label">Carrier Name / ਕੈਰੀਅਰ ਦਾ ਨਾਮ</label>
                    <input
                      type="text"
                      className="input"
                      value={editedData.carrier_name || ''}
                      onChange={(e) => handleFieldChange('carrier_name', e.target.value)}
                      placeholder="Your Company"
                    />
                  </div>
                  <div className="input-group">
                    <label className="input-label">Carrier Name (ਪੰਜਾਬੀ)</label>
                    <input
                      type="text"
                      className="input"
                      value={editedData.carrier_name_punjabi || ''}
                      onChange={(e) => handleFieldChange('carrier_name_punjabi', e.target.value)}
                      placeholder="ਕੈਰੀਅਰ ਦਾ ਨਾਮ ਪੰਜਾਬੀ ਵਿੱਚ"
                    />
                  </div>
                </div>
              </section>

              {/* Special Notes */}
              <section className="dispatch-section">
                <h3 className="dispatch-section-title">Special Notes / ਖ਼ਾਸ ਨੋਟਸ</h3>
                <div className="dispatch-form-grid">
                  <div className="input-group full-width">
                    <label className="input-label">Notes (English)</label>
                    <textarea
                      className="input textarea"
                      value={editedData.special_notes || ''}
                      onChange={(e) => handleFieldChange('special_notes', e.target.value)}
                      placeholder="Enter any special notes or instructions..."
                      rows={3}
                    />
                  </div>
                  <div className="input-group full-width">
                    <label className="input-label">Notes (ਪੰਜਾਬੀ)</label>
                    <textarea
                      className="input textarea"
                      value={editedData.special_notes_punjabi || ''}
                      onChange={(e) => handleFieldChange('special_notes_punjabi', e.target.value)}
                      placeholder="ਕੋਈ ਖ਼ਾਸ ਨੋਟ ਜਾਂ ਹਿਦਾਇਤਾਂ ਦਰਜ ਕਰੋ..."
                      rows={3}
                    />
                  </div>
                </div>
              </section>

              {/* Stops - All Editable */}
              <section className="dispatch-section">
                <h3 className="dispatch-section-title">Stops / ਸਟਾਪ ({stops.length})</h3>
                <div className="dispatch-stops">
                  {stops.length === 0 ? (
                    <p className="text-muted">No stops found / ਕੋਈ ਸਟਾਪ ਨਹੀਂ ਮਿਲੇ</p>
                  ) : (
                    stops.sort((a, b) => a.stop_sequence - b.stop_sequence).map((stop, index) => (
                      <div key={stop.stop_id || index} className="dispatch-stop-card">
                        {/* Stop Header */}
                        <div className="dispatch-stop-header">
                          <div className="stop-type-selector">
                            <label className="input-label">Type / ਕਿਸਮ</label>
                            <select
                              className="input input-sm"
                              value={stop.stop_type}
                              onChange={(e) => handleStopChange(index, 'stop_type', e.target.value)}
                            >
                              <option value="Pickup">Pickup / ਪਿਕਅੱਪ</option>
                              <option value="Delivery">Delivery / ਡਿਲਿਵਰੀ</option>
                            </select>
                          </div>
                          <span className="dispatch-stop-number">Stop #{stop.stop_sequence}</span>
                        </div>

                        {/* Address Fields */}
                        <div className="stop-field-group">
                          <div className="input-group">
                            <label className="input-label">📍 Address / ਪਤਾ</label>
                            <textarea
                              className="input textarea"
                              value={stop.facility_address || ''}
                              onChange={(e) => handleStopChange(index, 'facility_address', e.target.value)}
                              placeholder="Enter full address"
                              rows={2}
                            />
                          </div>
                          <div className="input-group">
                            <label className="input-label">📍 Address (ਪੰਜਾਬੀ)</label>
                            <textarea
                              className="input textarea"
                              value={stop.facility_address_punjabi || ''}
                              onChange={(e) => handleStopChange(index, 'facility_address_punjabi', e.target.value)}
                              placeholder="ਪੂਰਾ ਪਤਾ ਪੰਜਾਬੀ ਵਿੱਚ"
                              rows={2}
                            />
                          </div>
                        </div>

                        {/* Time & Contact */}
                        <div className="stop-inline-fields">
                          <div className="input-group">
                            <label className="input-label">🕐 Scheduled Time / ਸਮਾਂ</label>
                            <input
                              type="datetime-local"
                              className="input input-sm"
                              value={stop.scheduled_arrival ? stop.scheduled_arrival.slice(0, 16) : ''}
                              onChange={(e) => handleStopChange(index, 'scheduled_arrival', e.target.value)}
                            />
                          </div>
                          <div className="input-group">
                            <label className="input-label">👤 Contact / ਸੰਪਰਕ</label>
                            <input
                              type="text"
                              className="input input-sm"
                              value={stop.contact_name || ''}
                              onChange={(e) => handleStopChange(index, 'contact_name', e.target.value)}
                              placeholder="Contact name"
                            />
                          </div>
                          <div className="input-group">
                            <label className="input-label">📞 Phone / ਫ਼ੋਨ</label>
                            <input
                              type="tel"
                              className="input input-sm"
                              value={stop.contact_phone || ''}
                              onChange={(e) => handleStopChange(index, 'contact_phone', e.target.value)}
                              placeholder="+1 (555) 000-0000"
                            />
                          </div>
                        </div>

                        {/* Special Instructions */}
                        <div className="stop-field-group">
                          <div className="input-group">
                            <label className="input-label">📝 Instructions / ਹਿਦਾਇਤਾਂ</label>
                            <textarea
                              className="input textarea"
                              value={stop.special_instructions || ''}
                              onChange={(e) => handleStopChange(index, 'special_instructions', e.target.value)}
                              placeholder="Loading dock, appointment required, etc."
                              rows={2}
                            />
                          </div>
                          <div className="input-group">
                            <label className="input-label">📝 Instructions (ਪੰਜਾਬੀ)</label>
                            <textarea
                              className="input textarea"
                              value={stop.special_instructions_punjabi || ''}
                              onChange={(e) => handleStopChange(index, 'special_instructions_punjabi', e.target.value)}
                              placeholder="ਲੋਡਿੰਗ ਡੌਕ, ਅਪੌਇੰਟਮੈਂਟ ਜ਼ਰੂਰੀ, ਆਦਿ।"
                              rows={2}
                            />
                          </div>
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </section>
            </div>
          </div>

          {/* Right Column: Actions & Preview */}
          <div className="dispatch-actions slide-up" style={{ animationDelay: '0.1s' }}>
            <div className="card">
              <h2 className="card-title">Generate Dispatch Sheet</h2>
              <p className="card-subtitle">
                ਡਿਸਪੈਚ ਸ਼ੀਟ ਤਿਆਰ ਕਰੋ
              </p>

              <div className="dispatch-generate-actions">
                <button
                  onClick={handleGenerate}
                  disabled={isGenerating}
                  className="btn btn-primary btn-lg dispatch-generate-btn"
                >
                  {isGenerating ? (
                    <>
                      <span className="spinner"></span>
                      Generating...
                    </>
                  ) : dispatchSheetUrl ? (
                    '🔄 Regenerate Sheet'
                  ) : (
                    '📄 Generate Dispatch Sheet'
                  )}
                </button>

                {dispatchSheetUrl && (
                  <a
                    href={dispatchSheetUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="btn btn-secondary btn-lg dispatch-download-btn"
                  >
                    📥 Download PDF
                  </a>
                )}
              </div>

              {/* PDF Preview */}
              {dispatchSheetUrl && (
                <div className="dispatch-preview">
                  <h3 className="dispatch-preview-title">Preview / ਪ੍ਰੀਵਿਊ</h3>
                  <div className="dispatch-preview-frame">
                    <iframe
                      src={dispatchSheetUrl}
                      title="Dispatch Sheet Preview"
                      className="dispatch-preview-iframe"
                    />
                  </div>
                </div>
              )}

              {/* Quick Actions */}
              <div className="dispatch-quick-actions">
                <button
                  onClick={() => router.push('/upload')}
                  className="btn btn-secondary"
                >
                  📁 Upload Another
                </button>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}

// Main page component with Suspense boundary
export default function DispatchSheetPage() {
  return (
    <Suspense fallback={
      <div className="flex-center" style={{ minHeight: '100vh' }}>
        <div className="spinner" style={{ width: '2.5rem', height: '2.5rem' }}></div>
      </div>
    }>
      <DispatchSheetContent />
    </Suspense>
  );
}
