import React, { useEffect, useState, useCallback } from 'react';
import api, { getBillsSummary, confirmPayment } from '../services/api';

// ── Status badge ────────────────────────────────────────────────────────────
const StatusBadge = ({ status }) => {
  const map = {
    unpaid:  { cls: 'badge-warning', label: 'UNPAID' },
    paid:    { cls: 'badge-success', label: 'PAID' },
    overdue: { cls: 'badge-danger',  label: 'OVERDUE' },
  };
  const { cls, label } = map[status] || { cls: 'badge-info', label: (status || '—').toUpperCase() };
  return <span className={`badge ${cls}`}>{label}</span>;
};

// ── Summary cards ────────────────────────────────────────────────────────────
const SummaryCards = ({ refreshKey }) => {
  const [summary, setSummary] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    let cancelled = false;
    getBillsSummary()
      .then(res => { if (!cancelled) setSummary(res.data); })
      .catch(() => { if (!cancelled) setError('Failed to load summary'); });
    return () => { cancelled = true; };
  }, [refreshKey]);

  const loading = summary === null && error === null;

  if (loading) return (
    <div style={{ display: 'flex', gap: '1.5rem', marginBottom: '1.5rem' }}>
      {[1, 2, 3].map(i => (
        <div key={i} className="glass-panel" style={{ flex: 1, padding: '1.25rem', opacity: 0.4, minHeight: 80 }} />
      ))}
    </div>
  );

  if (error) return (
    <div className="error-message" style={{ marginBottom: '1.5rem' }}>{error}</div>
  );

  const cards = [
    {
      label: 'Unpaid Bills',
      count: summary?.totalUnpaid ?? 0,
      amount: summary?.totalAmountUnpaid ?? 0,
      color: 'var(--warning)',
      bg: 'rgba(245,158,11,0.08)',
    },
    {
      label: 'Overdue Bills',
      count: summary?.totalOverdue ?? 0,
      amount: summary?.totalAmountOverdue ?? 0,
      color: 'var(--danger)',
      bg: 'rgba(239,68,68,0.08)',
    },
    {
      label: 'Paid Bills',
      count: summary?.totalPaid ?? 0,
      amount: null,
      color: 'var(--success)',
      bg: 'rgba(16,185,129,0.08)',
    },
  ];

  return (
    <div style={{ display: 'flex', gap: '1.5rem', marginBottom: '1.5rem', flexWrap: 'wrap' }}>
      {cards.map(card => (
        <div
          key={card.label}
          className="glass-panel"
          style={{ flex: '1 1 180px', padding: '1.25rem', borderLeft: `3px solid ${card.color}`, background: card.bg }}
        >
          <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)', marginBottom: '0.4rem' }}>{card.label}</div>
          <div style={{ fontSize: '1.6rem', fontWeight: 700, color: card.color }}>{card.count}</div>
          {card.amount !== null && (
            <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)', marginTop: '0.25rem' }}>
              RWF {card.amount.toLocaleString()}
            </div>
          )}
        </div>
      ))}
    </div>
  );
};

// ── Confirm Payment Modal ────────────────────────────────────────────────────
const ConfirmPaymentModal = ({ bill, onClose, onSuccess }) => {
  const [method, setMethod] = useState('cash');
  const [reference, setReference] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const handleSubmit = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await confirmPayment(bill._id, { paymentMethod: method, paymentReference: reference || undefined });
      onSuccess(res.data);
    } catch (err) {
      setError(err?.message || 'Failed to confirm payment');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="glass-panel modal-content" style={{ maxWidth: 420 }} onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <span className="modal-title">Confirm Payment</span>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>

        <div style={{ marginBottom: '0.5rem', color: 'var(--text-secondary)', fontSize: '0.875rem' }}>
          Bill for <strong style={{ color: 'var(--text-primary)' }}>{bill.userId?.fullName || 'N/A'}</strong>
          {' · '}RWF {bill.totalAmountVatInclusive?.toLocaleString() ?? '—'}
        </div>

        {error && <div className="error-message" style={{ marginBottom: '1rem' }}>{error}</div>}

        <div className="form-group">
          <label className="form-label">Payment Method</label>
          <select
            className="form-input"
            value={method}
            onChange={e => setMethod(e.target.value)}
          >
            <option value="cash">Cash</option>
            <option value="bank">Bank</option>
            <option value="momo">MoMo</option>
          </select>
        </div>

        <div className="form-group">
          <label className="form-label">Payment Reference <span style={{ color: 'var(--text-secondary)' }}>(optional)</span></label>
          <input
            className="form-input"
            type="text"
            placeholder="e.g. REC-2024-001"
            value={reference}
            onChange={e => setReference(e.target.value)}
          />
        </div>

        <div style={{ display: 'flex', gap: '0.75rem', justifyContent: 'flex-end', marginTop: '1.5rem' }}>
          <button
            onClick={onClose}
            disabled={loading}
            style={{
              padding: '0.6rem 1.2rem', borderRadius: 'var(--radius-sm)',
              background: 'transparent', border: '1px solid var(--glass-border)',
              color: 'var(--text-primary)', cursor: 'pointer',
            }}
          >
            Cancel
          </button>
          <button
            onClick={handleSubmit}
            disabled={loading}
            className="btn btn-primary"
            style={{ opacity: loading ? 0.7 : 1, cursor: loading ? 'not-allowed' : 'pointer' }}
          >
            {loading ? 'Confirming…' : 'Confirm'}
          </button>
        </div>
      </div>
    </div>
  );
};

// ── Filter tabs ──────────────────────────────────────────────────────────────
const TABS = ['All', 'Unpaid', 'Paid', 'Overdue'];

const FilterTabs = ({ active, onChange }) => (
  <div style={{ display: 'flex', gap: '0.5rem', marginBottom: '1rem' }}>
    {TABS.map(tab => (
      <button
        key={tab}
        onClick={() => onChange(tab)}
        style={{
          padding: '0.4rem 1rem',
          borderRadius: 'var(--radius-sm)',
          border: '1px solid',
          borderColor: active === tab ? 'var(--accent-primary)' : 'var(--glass-border)',
          background: active === tab ? 'rgba(59,130,246,0.15)' : 'transparent',
          color: active === tab ? 'var(--accent-primary)' : 'var(--text-secondary)',
          cursor: 'pointer',
          fontWeight: active === tab ? 600 : 400,
          fontSize: '0.875rem',
          transition: 'all 0.15s',
        }}
      >
        {tab}
      </button>
    ))}
  </div>
);

// ── Paid details line ────────────────────────────────────────────────────────
const PaidDetails = ({ bill }) => {
  if (bill.status !== 'paid' || !bill.paidAt) return null;
  const date = new Date(bill.paidAt).toLocaleDateString();
  const method = bill.paymentMethod ? bill.paymentMethod.toUpperCase() : '—';
  const ref = bill.paymentReference || 'No reference';
  return (
    <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)', marginTop: '0.25rem' }}>
      Paid on {date} via {method} · Ref: {ref}
    </div>
  );
};

// ── Main Bills page ──────────────────────────────────────────────────────────
const Bills = () => {
  const [bills, setBills] = useState([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('All');
  const [confirmingBill, setConfirmingBill] = useState(null);
  const [summaryKey, setSummaryKey] = useState(0);

  const fetchBills = useCallback(async () => {
    setLoading(true);
    try {
      const response = await api.get('/admin/bills');
      setBills(response.data || []);
    } catch (err) {
      console.error('Failed to load bills', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchBills(); }, [fetchBills]);

  const handlePaymentSuccess = (updatedBill) => {
    setBills(prev => prev.map(b => b._id === updatedBill._id ? { ...b, ...updatedBill } : b));
    setConfirmingBill(null);
    setSummaryKey(k => k + 1); // refresh summary counts
  };

  const filtered = activeTab === 'All'
    ? bills
    : bills.filter(b => b.status === activeTab.toLowerCase());

  return (
    <div>
      <h1 className="page-title">Invoices & Bills</h1>

      <SummaryCards refreshKey={summaryKey} />

      <FilterTabs active={activeTab} onChange={setActiveTab} />

      {loading ? (
        <div className="loader"></div>
      ) : (
        <div className="glass-panel table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Customer</th>
                <th>Consumption</th>
                <th>Total (Inc. VAT)</th>
                <th>Due Date</th>
                <th>Generated</th>
                <th>Status</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan="7" style={{ textAlign: 'center', color: 'var(--text-secondary)', padding: '2rem' }}>
                    No bills found
                  </td>
                </tr>
              ) : (
                filtered.map(bill => (
                  <tr key={bill._id}>
                    <td>
                      <div style={{ fontWeight: 500 }}>{bill.userId?.fullName || 'N/A'}</div>
                      <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>
                        {bill.userId?.accountNumber}
                      </div>
                      <PaidDetails bill={bill} />
                    </td>
                    <td>{bill.consumption != null ? `${bill.consumption} m³` : '—'}</td>
                    <td style={{ fontWeight: 500, color: 'var(--success)' }}>
                      {bill.totalAmountVatInclusive != null
                        ? `RWF ${bill.totalAmountVatInclusive.toLocaleString()}`
                        : '—'}
                    </td>
                    <td style={{ color: bill.status === 'overdue' ? 'var(--danger)' : 'var(--text-secondary)', fontSize: '0.875rem' }}>
                      {bill.dueDate ? new Date(bill.dueDate).toLocaleDateString() : '—'}
                    </td>
                    <td style={{ fontSize: '0.875rem', color: 'var(--text-secondary)' }}>
                      {new Date(bill.generatedDate).toLocaleDateString()}
                    </td>
                    <td><StatusBadge status={bill.status} /></td>
                    <td>
                      {(bill.status === 'unpaid' || bill.status === 'overdue') && (
                        <button
                          onClick={() => setConfirmingBill(bill)}
                          style={{
                            padding: '0.35rem 0.85rem',
                            borderRadius: 'var(--radius-sm)',
                            background: 'rgba(16,185,129,0.1)',
                            border: '1px solid var(--success)',
                            color: 'var(--success)',
                            cursor: 'pointer',
                            fontSize: '0.8rem',
                            fontWeight: 600,
                            whiteSpace: 'nowrap',
                          }}
                        >
                          Confirm Payment
                        </button>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}

      {confirmingBill && (
        <ConfirmPaymentModal
          bill={confirmingBill}
          onClose={() => setConfirmingBill(null)}
          onSuccess={handlePaymentSuccess}
        />
      )}
    </div>
  );
};

export default Bills;
