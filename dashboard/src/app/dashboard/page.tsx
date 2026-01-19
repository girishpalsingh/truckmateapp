"use client";

import { useEffect, useState } from "react";
import { getTrips, getExpenses } from "@/services/api";

interface DashboardStats {
    totalTrips: number;
    activeTrips: number;
    totalRevenue: number;
    totalExpenses: number;
    netProfit: number;
}

export default function DashboardPage() {
    const [stats, setStats] = useState<DashboardStats | null>(null);
    const [recentTrips, setRecentTrips] = useState<any[]>([]);

    useEffect(() => {
        loadData();
    }, []);

    async function loadData() {
        try {
            const orgId = "11111111-1111-1111-1111-111111111111";
            const trips = await getTrips(orgId, { limit: 5 });
            const expenses = await getExpenses(orgId);

            const revenue = trips.reduce((sum: number, t: any) => sum + (t.load?.primary_rate || 0), 0);
            const totalExp = expenses.reduce((sum: number, e: any) => sum + (e.amount || 0), 0);

            setStats({
                totalTrips: trips.length,
                activeTrips: trips.filter((t: any) => t.status === "active").length,
                totalRevenue: revenue,
                totalExpenses: totalExp,
                netProfit: revenue - totalExp,
            });
            setRecentTrips(trips);
        } catch (e) {
            console.error(e);
        }
    }

    return (
        <div className="p-8">
            <h1 className="text-3xl font-bold mb-2">Dashboard</h1>
            <p className="text-slate-500 mb-8">ਡੈਸ਼ਬੋਰਡ</p>

            {/* Stats Cards */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
                <StatCard title="Total Trips" subtitle="ਕੁੱਲ ਯਾਤਰਾਵਾਂ" value={stats?.totalTrips || 0} icon="🚛" />
                <StatCard title="Active Trips" subtitle="ਸਰਗਰਮ" value={stats?.activeTrips || 0} icon="🟢" color="green" />
                <StatCard title="Revenue" subtitle="ਆਮਦਨ" value={`$${(stats?.totalRevenue || 0).toLocaleString()}`} icon="💰" color="blue" />
                <StatCard title="Net Profit" subtitle="ਸਾਫ਼ ਲਾਭ" value={`$${(stats?.netProfit || 0).toLocaleString()}`} icon="📈" color={(stats?.netProfit || 0) >= 0 ? "green" : "red"} />
            </div>

            {/* Recent Trips */}
            <div className="bg-white rounded-xl shadow p-6">
                <h2 className="text-xl font-bold mb-4">Recent Trips</h2>
                <table className="w-full">
                    <thead className="border-b">
                        <tr className="text-left text-slate-500">
                            <th className="pb-3">Route</th>
                            <th className="pb-3">Driver</th>
                            <th className="pb-3">Status</th>
                            <th className="pb-3">Rate</th>
                        </tr>
                    </thead>
                    <tbody>
                        {recentTrips.map((trip) => (
                            <tr key={trip.id} className="border-b hover:bg-slate-50">
                                <td className="py-4">{trip.origin_address} → {trip.destination_address}</td>
                                <td className="py-4">{trip.driver?.full_name || "Unassigned"}</td>
                                <td className="py-4">
                                    <span className={`px-2 py-1 rounded text-sm ${trip.status === "active" ? "bg-green-100 text-green-700" : trip.status === "completed" ? "bg-blue-100 text-blue-700" : "bg-gray-100"}`}>
                                        {trip.status}
                                    </span>
                                </td>
                                <td className="py-4">${trip.load?.primary_rate || 0}</td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>
        </div>
    );
}

function StatCard({ title, subtitle, value, icon, color = "slate" }: { title: string; subtitle: string; value: string | number; icon: string; color?: string }) {
    const colorClasses: Record<string, string> = {
        slate: "bg-slate-50",
        green: "bg-green-50",
        blue: "bg-blue-50",
        red: "bg-red-50",
    };

    return (
        <div className={`${colorClasses[color]} rounded-xl p-6 shadow-sm`}>
            <div className="text-3xl mb-2">{icon}</div>
            <div className="text-2xl font-bold">{value}</div>
            <div className="text-slate-600">{title}</div>
            <div className="text-slate-400 text-sm">{subtitle}</div>
        </div>
    );
}
