import React, { useEffect, useState, useCallback } from 'react';
import { Users, Gauge, FileCheck, FileText, TrendingUp, AlertCircle, Trash2 } from 'lucide-react';
import {
  PieChart, Pie, Cell, Tooltip, Legend, ResponsiveContainer,
  BarChart, Bar, XAxis, YAxis, CartesianGrid,
  AreaChart, Area,
} from 'recharts';
import api from '../services/api';
import { resetSystem } from '../services/api';

const COLORS = {
  paid: '#22c55e',
  unpaid: '#f59e0b',
  overdue: '#ef4444',
};

const CustomTooltip = ({ active, payload, label }) => {
  if (!active || !payload?.length) return null;
  return (
    <div style={{
      background: 'var(--bg-secondary)',
      border: '1px solid var(--border-color)',
      borderRadius: 8, padding: '0.6rem 1rem', fontSize: 13,
    }}>
      {label && <div style={{ color: 'var(--text-secondary)', marginBottom: 4 }}>{label}</div>}
      {payload.map((p, i) => (
        <div key={i} style={{ color: p.color || 'var(--text-primary)', fontWeight: 600 }}>
          {p.name}: {typeof p.value === 'number' ? p.value.toLocaleString() : p.value}
        </div>
      ))}
    </div>
  );
};

const Dashboard = () => {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [showConfirm, setShowConfirm] = useState(false);
  const [resetting, setResetting] = useState(false);
  const [notification, setNotification] = useState(null);

  const fetchStats = useCallback(async () => {
    try {
      const response = await api.get('/admin/stats');
      setStats(response.data);
    } catch (err) {
      console.error('Failed to load stats', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchStats(); }, [fetchStats]);

  const handleResetConfirm = async () => {
    setResetting(true);
    try {
      await resetSystem();
      setShowConfirm(false);
      setNotification({ type: 'success', message: 'System reset successfully. All readings, bills, meters, and users have been cleared.' });
      await fetchStats();
    } catch (err) {
      setShowConfirm(false);
      setNotification({ type: 'error', message: err?.message || 'Reset failed. Please try again.' });
    } finally {
      setResetting(false);
    }
  };

  if (loading) return <div className="loader mt-4"></div>;

  const statCards = [
    { title: 'Total Users', value: stats?.totalUsers || 0, icon: <Users size={20} />, color: 'var(--accent-primary)' },
    { title: 'Active Meters', value: stats?.totalMeters || 0, icon: <Gauge size={20} />, color: 'var(--success)' },
    { title: 'Pending Readings', value: stats?.pendingReadingsCount || 0, icon: <AlertCircle size={20} />, color: 'var(--warning)' },
    { title: 'Total Revenue (RWF)', value: `${stats?.totalRevenue?.toLocaleString() || 0}`, icon: <TrendingUp size={20} />, color: 'var(--success)' },
    { title: 'Total Bills', value: stats?.totalBills || 0, icon: <FileText size={20} />, color: 'var(--accent-primary)' },
    { title: 'Total Readings', value: stats?.totalReadings || 0, icon: <FileCheck size={20} />, color: 'var(--accent-primary)' },
  ];

  // Pie chart: bill status breakdown
  const billStatusData = [
    { name: 'Paid', value: stats?.paidBills || 0 },
    { name: 'Unpaid', value: stats?.unpaidBills || 0 },
    { name: 'Overdue', value: stats?.overdueBills || 0 },
  ].filter(d => d.value > 0);

  // Bar chart: system overview
  const systemData = [
    { name: 'Users', value: stats?.totalUsers || 0, fill: '#6366f1' },
    { name: 'Meters', value: stats?.totalMeters || 0, fill: '#22c55e' },
    { name: 'Readings', value: stats?.totalReadings || 0, fill: '#38bdf8' },
    { name: 'Bills', value: stats?.totalBills || 0, fill: '#f59e0b' },
  ];

  // Area chart: revenue vs unpaid amount
  const financialData = [
    { name: 'Revenue', value: stats?.totalRevenue || 0 },
    { name: 'Unpaid', value: stats?.totalAmountUnpaid || 0 },
    { name: 'Overdue', value: stats?.totalAmountOverdue || 0 },
  ];

  return (
    <div>
      <h1 className="page-title">Dashboard Overview</h1>

      {notification && (
        <div style={{
          padding: '0.75rem 1.25rem', marginBottom: '1.5rem', borderRadius: 8,
          background: notification.type === 'success' ? 'rgba(34,197,94,0.15)' : 'rgba(239,68,68,0.15)',
          border: `1px solid ${notification.type === 'success' ? 'var(--success)' : '#ef4444'}`,
          color: notification.type === 'success' ? 'var(--success)' : '#ef4444',
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        }}>
          <span>{notification.message}</span>
          <button onClick={() => setNotification(null)}
            style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'inherit', fontSize: '1.1rem', lineHeight: 1 }}>
            ×
          </button>
        </div>
      )}

      {/* Stat cards */}
      <div className="stats-grid">
        {statCards.map((stat, idx) => (
          <div key={idx} className="stat-card glass-panel">
            <div className="stat-header">
              <span className="stat-title">{stat.title}</span>
              <div className="stat-icon" style={{ color: stat.color }}>{stat.icon}</div>
            </div>
            <div className="stat-value">{stat.value}</div>
          </div>
        ))}
      </div>

      {/* Charts row */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.5rem', marginTop: '1.5rem' }}>

        {/* Bill status pie */}
        <div className="glass-panel" style={{ padding: '1.5rem' }}>
          <h2 style={{ marginBottom: '1.25rem', fontSize: 16, fontWeight: 700, color: 'var(--text-primary)' }}>
            Bill Status Breakdown
          </h2>
          {billStatusData.length > 0 ? (
            <ResponsiveContainer width="100%" height={240}>
              <PieChart>
                <Pie
                  data={billStatusData}
                  cx="50%" cy="50%"
                  innerRadius={60} outerRadius={95}
                  paddingAngle={3} dataKey="value"
                >
                  {billStatusData.map((entry) => (
                    <Cell
                      key={entry.name}
                      fill={COLORS[entry.name.toLowerCase()] || '#6366f1'}
                    />
                  ))}
                </Pie>
                <Tooltip content={<CustomTooltip />} />
                <Legend
                  iconType="circle"
                  formatter={(v) => <span style={{ color: 'var(--text-secondary)', fontSize: 13 }}>{v}</span>}
                />
              </PieChart>
            </ResponsiveContainer>
          ) : (
            <div style={{ height: 240, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-secondary)' }}>
              No bill data available
            </div>
          )}
        </div>

        {/* System overview bar */}
        <div className="glass-panel" style={{ padding: '1.5rem' }}>
          <h2 style={{ marginBottom: '1.25rem', fontSize: 16, fontWeight: 700, color: 'var(--text-primary)' }}>
            System Overview
          </h2>
          <ResponsiveContainer width="100%" height={240}>
            <BarChart data={systemData} barSize={36}>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--border-color)" vertical={false} />
              <XAxis dataKey="name" tick={{ fill: 'var(--text-secondary)', fontSize: 12 }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: 'var(--text-secondary)', fontSize: 12 }} axisLine={false} tickLine={false} />
              <Tooltip content={<CustomTooltip />} cursor={{ fill: 'rgba(255,255,255,0.04)' }} />
              <Bar dataKey="value" radius={[6, 6, 0, 0]}>
                {systemData.map((entry, i) => (
                  <Cell key={i} fill={entry.fill} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Financial area chart */}
      <div className="glass-panel" style={{ padding: '1.5rem', marginTop: '1.5rem' }}>
        <h2 style={{ marginBottom: '1.25rem', fontSize: 16, fontWeight: 700, color: 'var(--text-primary)' }}>
          Financial Summary (RWF)
        </h2>
        <ResponsiveContainer width="100%" height={200}>
          <BarChart data={financialData} barSize={48}>
            <CartesianGrid strokeDasharray="3 3" stroke="var(--border-color)" vertical={false} />
            <XAxis dataKey="name" tick={{ fill: 'var(--text-secondary)', fontSize: 13 }} axisLine={false} tickLine={false} />
            <YAxis
              tick={{ fill: 'var(--text-secondary)', fontSize: 11 }}
              axisLine={false} tickLine={false}
              tickFormatter={(v) => v >= 1000 ? `${(v / 1000).toFixed(0)}k` : v}
            />
            <Tooltip content={<CustomTooltip />} cursor={{ fill: 'rgba(255,255,255,0.04)' }} />
            <Bar dataKey="value" name="Amount (RWF)" radius={[6, 6, 0, 0]}>
              <Cell fill="#22c55e" />
              <Cell fill="#f59e0b" />
              <Cell fill="#ef4444" />
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* Info + Danger zone */}
      <div className="glass-panel" style={{ padding: '2rem', marginTop: '1.5rem' }}>
        <div style={{ color: 'var(--text-secondary)', lineHeight: '1.6' }}>
          <p>Navigate to <strong>Readings</strong> to validate OCR scans that require manual review, <strong>Users</strong> to manage accounts, <strong>Meters</strong> for hardware, and <strong>Bills</strong> for invoices.</p>
        </div>

        <div style={{ marginTop: '1.5rem', paddingTop: '1.5rem', borderTop: '1px solid var(--border-color)' }}>
          <h3 style={{ marginBottom: '0.5rem', color: '#ef4444' }}>Danger Zone</h3>
          <p style={{ color: 'var(--text-secondary)', marginBottom: '1rem', fontSize: '0.9rem' }}>
            Permanently delete all readings, bills, meters, and non-admin users. This action cannot be undone.
          </p>
          <button
            onClick={() => setShowConfirm(true)}
            style={{
              display: 'flex', alignItems: 'center', gap: '0.5rem',
              padding: '0.6rem 1.2rem', borderRadius: 6,
              background: 'rgba(239,68,68,0.1)', border: '1px solid #ef4444',
              color: '#ef4444', cursor: 'pointer', fontWeight: 600,
            }}
          >
            <Trash2 size={16} /> System Reset
          </button>
        </div>
      </div>

      {showConfirm && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
          <div className="glass-panel" style={{ padding: '2rem', maxWidth: 420, width: '90%', borderRadius: 12 }}>
            <h3 style={{ marginBottom: '0.75rem', color: '#ef4444' }}>Confirm System Reset</h3>
            <p style={{ color: 'var(--text-secondary)', marginBottom: '1.5rem', lineHeight: '1.6' }}>
              This will permanently delete <strong>all readings, bills, meters, and non-admin users</strong>. Admin accounts will be preserved. This cannot be undone.
            </p>
            <div style={{ display: 'flex', gap: '1rem', justifyContent: 'flex-end' }}>
              <button onClick={() => setShowConfirm(false)} disabled={resetting}
                style={{ padding: '0.6rem 1.2rem', borderRadius: 6, background: 'transparent', border: '1px solid var(--border-color)', color: 'var(--text-primary)', cursor: 'pointer' }}>
                Cancel
              </button>
              <button onClick={handleResetConfirm} disabled={resetting}
                style={{ padding: '0.6rem 1.2rem', borderRadius: 6, background: '#ef4444', border: 'none', color: '#fff', cursor: resetting ? 'not-allowed' : 'pointer', fontWeight: 600, opacity: resetting ? 0.7 : 1, display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                {resetting ? 'Resetting...' : 'Confirm Reset'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Dashboard;
