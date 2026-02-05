import type { Metadata } from "next";
import "./globals.css";
import { AuthProvider } from "@/contexts/AuthContext";
import { ThemeProvider } from "@/contexts/ThemeContext";

/**
 * Metadata for the TruckMate Dispatcher Webapp
 */
export const metadata: Metadata = {
  title: "TruckMate - Dispatcher Sheet Generator",
  description: "Upload rate confirmations and generate dispatcher sheets with AI-powered extraction",
  keywords: ["trucking", "dispatcher", "rate confirmation", "dispatch sheet", "TruckMate"],
  icons: {
    icon: "/favicon.ico",
  },
};

/**
 * Root Layout Component
 * Wraps the entire app with AuthProvider and ThemeProvider
 */
export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body>
        <ThemeProvider>
          <AuthProvider>
            {children}
          </AuthProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
