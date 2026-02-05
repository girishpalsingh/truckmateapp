/**
 * Authentication service
 * Handles phone OTP login via the auth-otp edge function
 */
import { getSupabase } from './supabase';
import { getConfig } from '@/lib/config';

// Types for auth responses
export interface AuthUser {
  id: string;
  phone?: string;
  email?: string;
}

export interface Profile {
  id: string;
  full_name: string;
  phone_number: string;
  role: string;
  organization_id: string;
  is_active: boolean;
}

export interface Organization {
  id: string;
  name: string;
  is_active: boolean;
}

export interface AuthSession {
  access_token: string;
  refresh_token: string;
  expires_at: number;
}

export interface VerifyOTPResponse {
  success: boolean;
  session: AuthSession;
  user: AuthUser;
  profile: Profile;
  organization: Organization;
  message: string;
}

/**
 * Sends an OTP to the provided phone number
 * @param phoneNumber - Phone number with country code (e.g., +1234567890)
 */
export async function sendOTP(phoneNumber: string): Promise<{ success: boolean; message: string; error?: string }> {
  const supabase = await getSupabase();
  const config = await getConfig();
  
  // Normalize phone number
  const normalizedPhone = phoneNumber.startsWith('+') ? phoneNumber : `+${phoneNumber}`;
  
  try {
    const response = await supabase.functions.invoke('auth-otp', {
      body: {
        action: 'send',
        phone_number: normalizedPhone
      }
    });

    if (response.error) {
      return { success: false, message: 'Failed to send OTP', error: response.error.message };
    }

    const data = response.data;
    
    if (data.error) {
      return { success: false, message: data.error, error: data.error };
    }

    // In development mode, show the default OTP hint
    if (config.development?.enabled) {
      return { 
        success: true, 
        message: `OTP sent! (Dev mode: use ${config.development.default_otp})` 
      };
    }

    return { success: true, message: 'OTP sent successfully' };
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return { success: false, message: 'Network error', error: errorMessage };
  }
}

/**
 * Verifies the OTP and logs in the user
 * @param phoneNumber - Phone number with country code
 * @param otp - One-time password received via SMS
 */
export async function verifyOTP(
  phoneNumber: string, 
  otp: string
): Promise<{ success: boolean; data?: VerifyOTPResponse; error?: string }> {
  const supabase = await getSupabase();
  
  // Normalize phone number
  const normalizedPhone = phoneNumber.startsWith('+') ? phoneNumber : `+${phoneNumber}`;
  
  try {
    const response = await supabase.functions.invoke('auth-otp', {
      body: {
        action: 'verify',
        phone_number: normalizedPhone,
        otp: otp
      }
    });

    if (response.error) {
      return { success: false, error: response.error.message };
    }

    const data = response.data;
    
    if (data.error) {
      return { success: false, error: data.error };
    }

    // Store the session
    if (data.session) {
      await supabase.auth.setSession({
        access_token: data.session.access_token,
        refresh_token: data.session.refresh_token
      });
    }

    return { success: true, data };
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return { success: false, error: errorMessage };
  }
}

/**
 * Logs out the current user
 */
export async function logout(): Promise<{ success: boolean; error?: string }> {
  const supabase = await getSupabase();
  
  try {
    const response = await supabase.functions.invoke('auth-otp', {
      body: {
        action: 'logout'
      }
    });

    if (response.error) {
      return { success: false, error: response.error.message };
    }

    // Also sign out from Supabase client
    await supabase.auth.signOut();

    return { success: true };
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return { success: false, error: errorMessage };
  }
}

/**
 * Gets the current session
 */
export async function getCurrentSession(): Promise<AuthSession | null> {
  const supabase = await getSupabase();
  const { data } = await supabase.auth.getSession();
  
  if (data.session) {
    return {
      access_token: data.session.access_token,
      refresh_token: data.session.refresh_token,
      expires_at: data.session.expires_at || 0
    };
  }
  
  return null;
}

/**
 * Gets the current user from Supabase auth
 */
export async function getCurrentUser(): Promise<AuthUser | null> {
  const supabase = await getSupabase();
  const { data } = await supabase.auth.getUser();
  
  if (data.user) {
    return {
      id: data.user.id,
      phone: data.user.phone,
      email: data.user.email
    };
  }
  
  return null;
}
