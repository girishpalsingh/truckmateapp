'use client';

/**
 * Landing/Login Page
 * Shows the OTP login component
 */
import OTPLogin from "@/components/auth/OTPLogin";
import { useAuth } from "@/contexts/AuthContext";
import { useRouter } from "next/navigation";
import { useEffect } from "react";

export default function HomePage() {
  const { isAuthenticated, isLoading } = useAuth();
  const router = useRouter();

  // Redirect to upload page if already authenticated
  useEffect(() => {
    if (!isLoading && isAuthenticated) {
      router.push('/upload');
    }
  }, [isAuthenticated, isLoading, router]);

  // Show loading state while checking auth
  if (isLoading) {
    return (
      <div className="flex-center" style={{ minHeight: '100vh' }}>
        <div className="spinner" style={{ width: '2.5rem', height: '2.5rem' }}></div>
      </div>
    );
  }

  // Show login if not authenticated
  return <OTPLogin />;
}
