"use client";

import { useEffect, useState } from "react";
import { getTrips } from "@/services/api";
import Link from "next/link";

type ViewMode = "trip" | "driver" | "truck";

export default function TripsPage() {
    const [trips, setTrips] = useState<any[]>([]);
    const [viewMode, setViewMode] = useState<ViewMode>("trip");
    const [statusFilter, setStatusFilter] = useState("");

    useEffect(() => {
        loadTrips();
    }, [statusFilter]);

    async function loadTrips() {
        const orgId = "11111111-1111-1111-1111-111111111111";
        const data = await getTrips(orgId, { status: statusFilter || undefined, limit: 100 });
        setTrips(data || []);
    }

    const groupedData = groupBy(trips, viewMode);

    return (
        <div className="p-8">
            <div className="flex justify-between items-center mb-6">
                <div>
                    <h1 className="text-3xl font-bold">Trips</h1>
                    <p className="text-slate-500">ਯਾਤਰਾਵਾਂ</p>
                </div>
                <div className="flex gap-2">
                    {(["trip", "driver", "truck"] as ViewMode[]).map((mode) => (
                        <button
                            key={mode}
                            onClick={() => setViewMode(mode)}
                            className={`px-4 py-2 rounded-lg ${viewMode === mode ? "bg-blue-600 text-white" : "bg-slate-200"}`}
                        >
                            By {mode.charAt(0).toUpperCase() + mode.slice(1)}
                        </button>
                    ))}
                </div>
            </div>

            {/* Filter */}
            <div className="flex gap-4 mb-6">
                <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)} className="px-4 py-2 border rounded-lg">
                    <option value="">All Status</option>
                    <option value="active">Active</option>
                    <option value="completed">Completed</option>
                    <option value="deadhead">Deadhead</option>
                </select>
            </div>

            {/* Data */}
            {viewMode === "trip" ? (
                <div className="bg-white rounded-xl shadow overflow-hidden">
                    <table className="w-full">
                        <thead className="bg-slate-50 border-b">
                            <tr className="text-left">
                                <th className="p-4">Route</th>
                                <th className="p-4">Driver</th>
                                <th className="p-4">Truck</th>
                                <th className="p-4">Miles</th>
                                <th className="p-4">Rate</th>
                                <th className="p-4">Status</th>
                            </tr>
                        </thead>
                        <tbody>
                            {trips.map((trip) => (
                                <tr key={trip.id} className="border-b hover:bg-slate-50">
                                    <td className="p-4 font-medium">{trip.origin_address} → {trip.destination_address}</td>
                                    <td className="p-4">{trip.driver?.full_name || "-"}</td>
                                    <td className="p-4">{trip.truck?.truck_number || "-"}</td>
                                    <td className="p-4">{trip.total_miles || "-"}</td>
                                    <td className="p-4">${trip.load?.primary_rate || 0}</td>
                                    <td className="p-4">
                                        <span className={`px-2 py-1 rounded text-sm ${trip.status === "active" ? "bg-green-100 text-green-700" : "bg-blue-100 text-blue-700"}`}>
                                            {trip.status}
                                        </span>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    {Object.entries(groupedData).map(([key, items]: [string, any[]]) => (
                        <div key={key} className="bg-white rounded-xl shadow p-6">
                            <h3 className="text-lg font-bold mb-2">{key || "Unassigned"}</h3>
                            <p className="text-3xl font-bold text-blue-600 mb-2">{items.length} trips</p>
                            <p className="text-slate-500">Revenue: ${items.reduce((s, t) => s + (t.load?.primary_rate || 0), 0).toLocaleString()}</p>
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
}

function groupBy(trips: any[], mode: ViewMode) {
    return trips.reduce((acc, trip) => {
        const key = mode === "driver" ? trip.driver?.full_name : mode === "truck" ? trip.truck?.truck_number : trip.id;
        if (!acc[key]) acc[key] = [];
        acc[key].push(trip);
        return acc;
    }, {} as Record<string, any[]>);
}
