"use client";

import { useEffect, useState } from "react";
import { getDocuments, updateDocumentStatus, supabase } from "@/services/api";

export default function ApprovalQueuePage() {
    const [documents, setDocuments] = useState<any[]>([]);
    const [selected, setSelected] = useState<any | null>(null);

    useEffect(() => {
        loadDocuments();
    }, []);

    async function loadDocuments() {
        const orgId = "11111111-1111-1111-1111-111111111111";
        const data = await getDocuments(orgId, { status: "pending_review" });
        setDocuments(data || []);
        if (data?.length) setSelected(data[0]);
    }

    async function handleApprove() {
        if (!selected) return;
        await updateDocumentStatus(selected.id, "approved");
        loadDocuments();
    }

    async function handleReject() {
        if (!selected) return;
        await updateDocumentStatus(selected.id, "rejected");
        loadDocuments();
    }

    const imageUrl = selected?.image_url ? supabase.storage.from("documents").getPublicUrl(selected.image_url).data.publicUrl : null;

    return (
        <div className="p-8 h-screen flex flex-col">
            <h1 className="text-3xl font-bold mb-2">Document Approval</h1>
            <p className="text-slate-500 mb-6">ਦਸਤਾਵੇਜ਼ ਮਨਜ਼ੂਰੀ ਕਤਾਰ</p>

            <div className="flex-1 flex gap-6 min-h-0">
                {/* Document List */}
                <div className="w-64 bg-white rounded-xl shadow overflow-auto">
                    <div className="p-4 border-b font-bold">Pending ({documents.length})</div>
                    {documents.map((doc) => (
                        <button
                            key={doc.id}
                            onClick={() => setSelected(doc)}
                            className={`w-full p-4 text-left border-b hover:bg-slate-50 ${selected?.id === doc.id ? "bg-blue-50" : ""}`}
                        >
                            <div className="font-medium">{doc.type.replace("_", " ")}</div>
                            <div className="text-sm text-slate-500">{new Date(doc.created_at).toLocaleDateString()}</div>
                        </button>
                    ))}
                    {!documents.length && <div className="p-4 text-slate-500">No pending documents</div>}
                </div>

                {/* Split View */}
                {selected && (
                    <div className="flex-1 flex gap-6 min-h-0">
                        {/* Image Preview */}
                        <div className="flex-1 bg-white rounded-xl shadow p-4 overflow-auto">
                            <h3 className="font-bold mb-4">Scanned Document</h3>
                            {imageUrl ? (
                                <img src={imageUrl} alt="Document" className="max-w-full rounded border" />
                            ) : (
                                <div className="h-64 bg-slate-100 rounded flex items-center justify-center text-slate-400">No preview available</div>
                            )}
                        </div>

                        {/* Extracted Data */}
                        <div className="flex-1 bg-white rounded-xl shadow p-4 flex flex-col">
                            <h3 className="font-bold mb-4">Extracted Data</h3>
                            <div className="flex-1 overflow-auto">
                                {selected.ai_data ? (
                                    <pre className="text-sm bg-slate-50 p-4 rounded overflow-auto">{JSON.stringify(selected.ai_data, null, 2)}</pre>
                                ) : (
                                    <div className="text-slate-500">No extracted data yet</div>
                                )}
                                {selected.dangerous_clauses && (
                                    <div className="mt-4 p-4 bg-red-50 rounded">
                                        <h4 className="font-bold text-red-700 mb-2">⚠️ Dangerous Clauses</h4>
                                        {selected.dangerous_clauses.map((c: any, i: number) => (
                                            <div key={i} className="mb-2 text-sm">{c.clause_text || c}</div>
                                        ))}
                                    </div>
                                )}
                            </div>

                            {/* Actions */}
                            <div className="flex gap-4 mt-4 pt-4 border-t">
                                <button onClick={handleApprove} className="flex-1 bg-green-600 text-white py-3 rounded-lg font-bold hover:bg-green-700">
                                    ✓ Approve
                                </button>
                                <button onClick={handleReject} className="flex-1 bg-red-600 text-white py-3 rounded-lg font-bold hover:bg-red-700">
                                    ✗ Reject
                                </button>
                            </div>
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
}
