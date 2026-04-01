import React, { useEffect, useState } from 'react';
import { Users, Gauge, FileCheck, FileText, CheckCircle, BarChart3, TrendingUp, AlertCircle } from 'lucide-react';
import api from '../services/api';

const Dashboard = () => {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const response = await api.get('/admin/stats');
        setStats(response.data);
      } catch (err) {
        console.error('Failed to load stats', err);
      } finally {
        setLoading(false);
      }
    };
    fetchStats();
  }, []);

  if (loading) return <div className="loader mt-4"></div>;

  const statCards = [
    { title: 'Total Users', value: stats?.totalUsers || 0, icon: <Users size={20} />, color: 'var(--accent-primary)' },
    { title: 'Active Meters', value: stats?.totalMeters || 0, icon: <Gauge size={20} />, color: 'var(--success)' },
    { title: 'Pending Readings', value: stats?.pendingReadingsCount || 0, icon: <AlertCircle size={20} />, color: 'var(--warning)' },
    { title: 'Total Revenue (RWF)', value: `\${stats?.totalRevenue?.toLocaleString() || 0}`, icon: <TrendingUp size={20} />, color: 'var(--success)' },
    { title: 'Total Bills', value: stats?.totalBills || 0, icon: <FileText size={20} />, color: 'var(--accent-primary)' },
    { title: 'Total Readings', value: stats?.totalReadings || 0, icon: <FileCheck size={20} />, color: 'var(--accent-primary)' },
  ];

  return (
    <div>
      <h1 className="page-title">Dashboard Overview</h1>
      
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
      </div>
    </div>
  );
};

export default Dashboard;
