'use client';

/**
 * Authentication Context
 * Provides auth state and methods throughout the app
 */
import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { getCurrentSession, getCurrentUser, logout as authLogout, Profile, Organization, AuthUser, AuthSession } from '@/services/auth';
import { getSupabase } from '@/services/supabase';

// Interface for the context value
interface AuthContextValue {
  isAuthenticated: boolean;
  isLoading: boolean;
  user: AuthUser | null;
  profile: Profile | null;
  organization: Organization | null;
  session: AuthSession | null;
  login: (session: AuthSession, user: AuthUser, profile: Profile, organization: Organization) => void;
  logout: () => Promise<void>;
  refreshAuth: () => Promise<void>;
}

// Create the context with default values
const AuthContext = createContext<AuthContextValue>({
  isAuthenticated: false,
  isLoading: true,
  user: null,
  profile: null,
  organization: null,
  session: null,
  login: () => {},
  logout: async () => {},
  refreshAuth: async () => {}
});

// Custom hook to use the auth context
export const useAuth = () => useContext(AuthContext);

// Props for the provider component
interface AuthProviderProps {
  children: ReactNode;
}

/**
 * AuthProvider component
 * Wraps the app to provide authentication state
 */
export function AuthProvider({ children }: AuthProviderProps) {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [user, setUser] = useState<AuthUser | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [organization, setOrganization] = useState<Organization | null>(null);
  const [session, setSession] = useState<AuthSession | null>(null);

  // Check for existing session on mount
  useEffect(() => {
    checkAuth();
  }, []);

  // Check if user is authenticated
  const checkAuth = async () => {
    try {
      const currentSession = await getCurrentSession();
      const currentUser = await getCurrentUser();

      if (currentSession && currentUser) {
        setSession(currentSession);
        setUser(currentUser);
        setIsAuthenticated(true);

        // Fetch profile and organization
        await fetchUserDetails(currentUser.id);
      }
    } catch (error) {
      console.error('Auth check error:', error);
    } finally {
      setIsLoading(false);
    }
  };

  // Fetch user profile and organization details
  const fetchUserDetails = async (userId: string) => {
    try {
      const supabase = await getSupabase();
      
      // Get profile
      const { data: profileData } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .single();

      if (profileData) {
        setProfile(profileData);

        // Get organization
        if (profileData.organization_id) {
          const { data: orgData } = await supabase
            .from('organizations')
            .select('*')
            .eq('id', profileData.organization_id)
            .single();

          if (orgData) {
            setOrganization(orgData);
          }
        }
      }
    } catch (error) {
      console.error('Error fetching user details:', error);
    }
  };

  // Login handler - called after successful OTP verification
  const login = (
    newSession: AuthSession, 
    newUser: AuthUser, 
    newProfile: Profile, 
    newOrganization: Organization
  ) => {
    setSession(newSession);
    setUser(newUser);
    setProfile(newProfile);
    setOrganization(newOrganization);
    setIsAuthenticated(true);
  };

  // Logout handler
  const logout = async () => {
    try {
      await authLogout();
    } catch (error) {
      console.error('Logout error:', error);
    } finally {
      setSession(null);
      setUser(null);
      setProfile(null);
      setOrganization(null);
      setIsAuthenticated(false);
    }
  };

  // Refresh authentication state
  const refreshAuth = async () => {
    setIsLoading(true);
    await checkAuth();
  };

  const contextValue: AuthContextValue = {
    isAuthenticated,
    isLoading,
    user,
    profile,
    organization,
    session,
    login,
    logout,
    refreshAuth
  };

  return (
    <AuthContext.Provider value={contextValue}>
      {children}
    </AuthContext.Provider>
  );
}

export default AuthContext;
