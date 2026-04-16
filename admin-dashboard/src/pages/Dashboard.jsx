import React, { useEffect, useState, useCallback } from 'react';
import { Users, Gauge, FileCheck, FileText, BarChart3, TrendingUp, AlertCircle, Trash2 } from 'lucide-react';
import api from '../services/api';
import { resetSystem } from '../services/api';

const Dashboard = () => {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [showConfirm, setShowConfirm] = useState(false);
  const [resetting, setResetting] = useState(false);
  const [notification, setNotification] = useState(null); // { type: 'success'|'error', message }

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

  useEffect(() => {
    fetchStats();
  }, [fetchStats]);

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

  return (
    <div>
      <h1 className="page-title">Dashboard Overview</h1>

      {/* Notification banner */}
      {notification && (
        <div
          style={{
            padding: '0.75rem 1.25rem',
            marginBottom: '1.5rem',
            borderRadius: '8px',
            background: notification.type === 'success' ? 'rgba(34,197,94,0.15)' : 'rgba(239,68,68,0.15)',
            border: `1px solid ${notification.type === 'success' ? 'var(--success)' : '#ef4444'}`,
            color: notification.type === 'success' ? 'var(--success)' : '#ef4444',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
          }}
        >
          <span>{notification.message}</span>
          <button
            onClick={() => setNotification(null)}
            style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'inherit', fontSize: '1.1rem', lineHeight: 1 }}
          >
            ×
          </button>
        </div>
      )}

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

      <div className="glass-panel" style={{ padding: '2rem', marginTop: '2rem' }}>
        <h2 style={{ marginBottom: '1rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <BarChart3 /> Recent Activity Overview
        </h2>
        <div style={{ color: 'var(--text-secondary)', lineHeight: '1.6' }}>
          <p>Welcome back to the Admin Panel. Here you can monitor system activity, review pending meter readings, and manage user accounts.</p>
          <ul style={{ paddingLeft: '1.5rem', marginTop: '1rem', display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
            <li>Navigate to <strong>Readings</strong> to validate OCR scans that require manual review.</li>
            <li>Check <strong>Users</strong> to view registered accounts.</li>
            <li>Check <strong>Meters</strong> for hardware deployments.</li>
            <li>Check <strong>Bills</strong> for generated invoices and collections.</li>
          </ul>
        </div>

        {/* System Reset action */}
        <div style={{ marginTop: '2rem', paddingTop: '1.5rem', borderTop: '1px solid var(--border-color)' }}>
          <h3 style={{ marginBottom: '0.5rem', color: '#ef4444' }}>Danger Zone</h3>
          <p style={{ color: 'var(--text-secondary)', marginBottom: '1rem', fontSize: '0.9rem' }}>
            Permanently delete all readings, bills, meters, and non-admin users. This action cannot be undone.
          </p>
          <button
            onClick={() => setShowConfirm(true)}
            style={{
              display: 'flex', alignItems: 'center', gap: '0.5rem',
              padding: '0.6rem 1.2rem', borderRadius: '6px',
              background: 'rgba(239,68,68,0.1)', border: '1px solid #ef4444',
              color: '#ef4444', cursor: 'pointer', fontWeight: 600,
            }}
          >
            <Trash2 size={16} /> System Reset
          </button>
        </div>
      </div>

      {/* Confirmation dialog */}
      {showConfirm && (
        <div
          style={{
            position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)',
            display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000,
          }}
        >
          <div className="glass-panel" style={{ padding: '2rem', maxWidth: '420px', width: '90%', borderRadius: '12px' }}>
            <h3 style={{ marginBottom: '0.75rem', color: '#ef4444' }}>Confirm System Reset</h3>
            <p style={{ color: 'var(--text-secondary)', marginBottom: '1.5rem', lineHeight: '1.6' }}>
              This will permanently delete <strong>all readings, bills, meters, and non-admin users</strong>. Admin accounts will be preserved. This cannot be undone.
            </p>
            <div style={{ display: 'flex', gap: '1rem', justifyContent: 'flex-end' }}>
              <button
                onClick={() => setShowConfirm(false)}
                disabled={resetting}
                style={{
                  padding: '0.6rem 1.2rem', borderRadius: '6px',
                  background: 'transparent', border: '1px solid var(--border-color)',
                  color: 'var(--text-primary)', cursor: 'pointer',
                }}
              >
                Cancel
              </button>
              <button
                onClick={handleResetConfirm}
                disabled={resetting}
                style={{
                  padding: '0.6rem 1.2rem', borderRadius: '6px',
                  background: '#ef4444', border: 'none',
                  color: '#fff', cursor: resetting ? 'not-allowed' : 'pointer',
                  fontWeight: 600, opacity: resetting ? 0.7 : 1,
                  display: 'flex', alignItems: 'center', gap: '0.5rem',
                }}
              >
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
