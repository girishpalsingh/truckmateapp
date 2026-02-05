'use client';

/**
 * Rate Con Upload Page
 * Allows users to upload rate confirmations for processing
 */
import React, { useState, useRef, useCallback } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { useRouter } from 'next/navigation';
import { uploadRateCon, processDocument } from '@/services/upload';
import { ThemeToggle } from '@/components/common/ThemeToggle';
import '@/components/common/common.css';
import './upload.css';

// Upload states
type UploadState = 'idle' | 'uploading' | 'processing' | 'success' | 'error';

export default function UploadPage() {
  const { isAuthenticated, isLoading, profile, organization, logout } = useAuth();
  const router = useRouter();
  const fileInputRef = useRef<HTMLInputElement>(null);
  
  const [uploadState, setUploadState] = useState<UploadState>('idle');
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [progress, setProgress] = useState(0);
  const [error, setError] = useState('');
  const [rateConId, setRateConId] = useState<string | null>(null);
  const [isDragging, setIsDragging] = useState(false);

  // Redirect to login if not authenticated
  React.useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      router.push('/');
    }
  }, [isAuthenticated, isLoading, router]);

  // Handle file selection
  const handleFileSelect = (file: File) => {
    const validTypes = ['application/pdf', 'image/jpeg', 'image/png', 'image/heic'];
    
    if (!validTypes.includes(file.type)) {
      setError('Please upload a PDF or image file (JPG, PNG, HEIC)');
      return;
    }

    if (file.size > 50 * 1024 * 1024) {
      setError('File size must be less than 50MB');
      return;
    }

    setSelectedFile(file);
    setError('');
    setUploadState('idle');
  };

  // Handle drag events
  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  }, []);

  const handleDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
  }, []);

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    
    const file = e.dataTransfer.files[0];
    if (file) {
      handleFileSelect(file);
    }
  }, []);

  // Handle file input change
  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      handleFileSelect(file);
    }
  };

  // Handle upload and processing
  const handleUpload = async () => {
    if (!selectedFile || !organization?.id) {
      setError('Please select a file to upload');
      return;
    }

    setError('');
    setUploadState('uploading');
    setProgress(20);

    try {
      // Step 1: Upload file to storage
      const uploadResult = await uploadRateCon(selectedFile, organization.id);
      
      if (!uploadResult.success || !uploadResult.documentId) {
        throw new Error(uploadResult.error || 'Upload failed');
      }

      setProgress(50);
      setUploadState('processing');

      // Step 2: Process document with AI
      const processResult = await processDocument(
        uploadResult.documentId, 
        uploadResult.storagePath!
      );
      
      if (!processResult.success || !processResult.rateConId) {
        throw new Error(processResult.error || 'Processing failed');
      }

      setProgress(100);
      setRateConId(processResult.rateConId);
      setUploadState('success');

    } catch (err: unknown) {
      const errorMessage = err instanceof Error ? err.message : 'An error occurred';
      setError(errorMessage);
      setUploadState('error');
    }
  };

  // Handle navigation to dispatch sheet
  const handleContinue = () => {
    if (rateConId) {
      router.push(`/dispatch-sheet?id=${rateConId}`);
    }
  };

  // Handle logout
  const handleLogout = async () => {
    await logout();
    router.push('/');
  };

  // Show loading while checking auth
  if (isLoading) {
    return (
      <div className="flex-center" style={{ minHeight: '100vh' }}>
        <div className="spinner" style={{ width: '2.5rem', height: '2.5rem' }}></div>
      </div>
    );
  }

  return (
    <div className="upload-page">
      {/* Header */}
      <header className="upload-header">
        <div className="upload-header-content container">
          <div className="upload-brand">
            <span className="upload-brand-icon">🚛</span>
            <span className="upload-brand-name">TruckMate</span>
          </div>
          <div className="upload-user-info">
            <span className="upload-user-name">{profile?.full_name}</span>
            <span className="upload-org-name">{organization?.name}</span>
            <ThemeToggle />
            <button onClick={handleLogout} className="btn btn-secondary btn-sm">
              Logout
            </button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="upload-main container">
        <div className="upload-content slide-up">
          <h1 className="upload-title">Upload Rate Confirmation</h1>
          <p className="upload-subtitle">ਰੇਟ ਕਨਫਰਮੇਸ਼ਨ ਅੱਪਲੋਡ ਕਰੋ</p>

          {/* Dropzone */}
          <div 
            className={`dropzone ${isDragging ? 'active' : ''} ${selectedFile ? 'has-file' : ''}`}
            onDragOver={handleDragOver}
            onDragLeave={handleDragLeave}
            onDrop={handleDrop}
            onClick={() => fileInputRef.current?.click()}
          >
            <input
              ref={fileInputRef}
              type="file"
              accept=".pdf,.jpg,.jpeg,.png,.heic"
              onChange={handleInputChange}
              style={{ display: 'none' }}
            />
            
            {selectedFile ? (
              <div className="dropzone-file-info fade-in">
                <span className="dropzone-file-icon">📄</span>
                <span className="dropzone-file-name">{selectedFile.name}</span>
                <span className="dropzone-file-size">
                  {(selectedFile.size / 1024 / 1024).toFixed(2)} MB
                </span>
              </div>
            ) : (
              <>
                <div className="dropzone-icon">📁</div>
                <p className="dropzone-text">
                  Drag & drop your rate confirmation here
                </p>
                <p className="dropzone-hint">
                  or click to browse • PDF, JPG, PNG, HEIC (max 50MB)
                </p>
              </>
            )}
          </div>

          {/* Progress Bar */}
          {(uploadState === 'uploading' || uploadState === 'processing') && (
            <div className="upload-progress fade-in">
              <div className="progress-bar">
                <div 
                  className="progress-bar-fill" 
                  style={{ width: `${progress}%` }}
                ></div>
              </div>
              <p className="upload-progress-text">
                {uploadState === 'uploading' ? 'Uploading...' : 'Processing with AI...'}
              </p>
            </div>
          )}

          {/* Success State */}
          {uploadState === 'success' && (
            <div className="alert alert-success fade-in">
              <span>✅</span>
              <span>Rate confirmation processed successfully!</span>
            </div>
          )}

          {/* Error State */}
          {error && (
            <div className="alert alert-error fade-in">
              <span>⚠️</span>
              <span>{error}</span>
            </div>
          )}

          {/* Action Buttons */}
          <div className="upload-actions">
            {uploadState === 'success' ? (
              <button 
                onClick={handleContinue}
                className="btn btn-primary btn-lg"
              >
                Continue to Dispatch Sheet →
              </button>
            ) : (
              <button 
                onClick={handleUpload}
                disabled={!selectedFile || uploadState === 'uploading' || uploadState === 'processing'}
                className="btn btn-primary btn-lg"
              >
                {uploadState === 'uploading' || uploadState === 'processing' ? (
                  <>
                    <span className="spinner"></span>
                    {uploadState === 'uploading' ? 'Uploading...' : 'Processing...'}
                  </>
                ) : (
                  'Upload & Process'
                )}
              </button>
            )}
          </div>

          {/* Instructions */}
          <div className="upload-instructions card">
            <h3>How it works / ਇਹ ਕਿਵੇਂ ਕੰਮ ਕਰਦਾ ਹੈ</h3>
            <ol>
              <li>Upload your rate confirmation (PDF or image)</li>
              <li>AI extracts all important information</li>
              <li>Review and edit the extracted data</li>
              <li>Generate your dispatcher sheet</li>
            </ol>
          </div>
        </div>
      </main>
    </div>
  );
}
