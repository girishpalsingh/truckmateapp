'use client';

/**
 * OTP Login Component
 * Phone number input with OTP verification
 */
import React, { useState } from 'react';
import { sendOTP, verifyOTP } from '@/services/auth';
import { useAuth } from '@/contexts/AuthContext';
import { useRouter } from 'next/navigation';
import { ThemeToggle } from '../common/ThemeToggle';
import '../common/common.css';
import './OTPLogin.css';

// Step enum for login flow
enum LoginStep {
  PHONE = 'phone',
  OTP = 'otp'
}

export default function OTPLogin() {
  const [step, setStep] = useState<LoginStep>(LoginStep.PHONE);
  const [phoneNumber, setPhoneNumber] = useState('');
  const [otp, setOtp] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  
  const { login } = useAuth();
  const router = useRouter();

  // Handle phone number submission
  const handleSendOTP = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setMessage('');
    setIsLoading(true);

    // Validate phone number
    if (!phoneNumber || phoneNumber.length < 10) {
      setError('Please enter a valid phone number');
      setIsLoading(false);
      return;
    }

    try {
      const result = await sendOTP(phoneNumber);
      
      if (result.success) {
        setMessage(result.message);
        setStep(LoginStep.OTP);
      } else {
        setError(result.error || 'Failed to send OTP');
      }
    } catch (err) {
      setError('An unexpected error occurred');
    } finally {
      setIsLoading(false);
    }
  };

  // Handle OTP verification
  const handleVerifyOTP = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setIsLoading(true);

    // Validate OTP
    if (!otp || otp.length < 6) {
      setError('Please enter a valid 6-digit OTP');
      setIsLoading(false);
      return;
    }

    try {
      const result = await verifyOTP(phoneNumber, otp);
      
      if (result.success && result.data) {
        // Update auth context
        login(
          result.data.session,
          result.data.user,
          result.data.profile,
          result.data.organization
        );
        
        // Redirect to upload page
        router.push('/upload');
      } else {
        setError(result.error || 'Invalid OTP');
      }
    } catch (err) {
      setError('An unexpected error occurred');
    } finally {
      setIsLoading(false);
    }
  };

  // Handle going back to phone input
  const handleBack = () => {
    setStep(LoginStep.PHONE);
    setOtp('');
    setError('');
    setMessage('');
  };

  return (
    <div className="otp-login-container slide-up">
      <div className="otp-login-card card">
        {/* Theme Toggle */}
        <div className="otp-login-theme-toggle">
          <ThemeToggle />
        </div>

        {/* Header */}
        <div className="otp-login-header">
          <div className="otp-login-icon">🚛</div>
          <h1 className="otp-login-title">TruckMate</h1>
          <p className="otp-login-subtitle">ਟਰੱਕਮੇਟ</p>
          <p className="otp-login-desc">
            {step === LoginStep.PHONE 
              ? 'Enter your phone number to sign in'
              : 'Enter the verification code'}
          </p>
        </div>

        {/* Phone Number Step */}
        {step === LoginStep.PHONE && (
          <form onSubmit={handleSendOTP} className="otp-login-form">
            <div className="input-group">
              <label className="input-label" htmlFor="phone">
                Phone Number / ਫ਼ੋਨ ਨੰਬਰ
              </label>
              <input
                type="tel"
                id="phone"
                className={`input ${error ? 'input-error' : ''}`}
                placeholder="+1 (555) 123-4567"
                value={phoneNumber}
                onChange={(e) => setPhoneNumber(e.target.value)}
                disabled={isLoading}
                autoComplete="tel"
              />
            </div>

            {error && (
              <div className="alert alert-error fade-in">
                <span>⚠️</span>
                <span>{error}</span>
              </div>
            )}

            <button 
              type="submit" 
              className="btn btn-primary btn-lg otp-login-btn"
              disabled={isLoading}
            >
              {isLoading ? (
                <>
                  <span className="spinner"></span>
                  Sending OTP...
                </>
              ) : (
                'Send OTP'
              )}
            </button>
          </form>
        )}

        {/* OTP Verification Step */}
        {step === LoginStep.OTP && (
          <form onSubmit={handleVerifyOTP} className="otp-login-form">
            <div className="otp-sent-info fade-in">
              <span className="otp-sent-icon">📱</span>
              <span>Code sent to {phoneNumber}</span>
            </div>

            {message && (
              <div className="alert alert-info fade-in">
                <span>💡</span>
                <span>{message}</span>
              </div>
            )}

            <div className="input-group">
              <label className="input-label" htmlFor="otp">
                Verification Code / ਤਸਦੀਕ ਕੋਡ
              </label>
              <input
                type="text"
                id="otp"
                className={`input otp-input ${error ? 'input-error' : ''}`}
                placeholder="123456"
                value={otp}
                onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
                disabled={isLoading}
                autoComplete="one-time-code"
                maxLength={6}
              />
            </div>

            {error && (
              <div className="alert alert-error fade-in">
                <span>⚠️</span>
                <span>{error}</span>
              </div>
            )}

            <button 
              type="submit" 
              className="btn btn-primary btn-lg otp-login-btn"
              disabled={isLoading}
            >
              {isLoading ? (
                <>
                  <span className="spinner"></span>
                  Verifying...
                </>
              ) : (
                'Verify & Sign In'
              )}
            </button>

            <button 
              type="button" 
              className="btn btn-secondary otp-back-btn"
              onClick={handleBack}
              disabled={isLoading}
            >
              ← Change Phone Number
            </button>
          </form>
        )}

        {/* Footer */}
        <div className="otp-login-footer">
          <p>Dispatcher Sheet Generator</p>
        </div>
      </div>
    </div>
  );
}
