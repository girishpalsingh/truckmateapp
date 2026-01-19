import Link from "next/link";

export default function HomePage() {
  return (
    <div className="flex items-center justify-center min-h-screen bg-gradient-to-br from-blue-900 to-blue-700">
      <div className="text-center text-white">
        <div className="text-8xl mb-6">🚛</div>
        <h1 className="text-5xl font-bold mb-2">TruckMate</h1>
        <p className="text-2xl text-blue-200 mb-8">ਟਰੱਕਮੇਟ</p>
        <p className="text-lg text-blue-300 mb-12">Admin Dashboard for Trucking Management</p>
        <Link
          href="/dashboard"
          className="inline-block bg-white text-blue-900 px-8 py-4 rounded-lg font-bold text-lg hover:bg-blue-100 transition-colors"
        >
          Enter Dashboard
        </Link>
      </div>
    </div>
  );
}
