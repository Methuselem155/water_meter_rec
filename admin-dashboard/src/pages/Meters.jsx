import React, { useEffect, useState } from 'react';
import api from '../services/api';

const Meters = () => {
  const [meters, setMeters] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchMeters = async () => {
      try {
        const response = await api.get('/admin/meters');
        setMeters(response.data || []);
      } catch (err) {
        console.error('Failed to load meters', err);
      } finally {
        setLoading(false);
      }
    };
    fetchMeters();
  }, []);

  const getStatusBadge = (status) => {
    switch(status) {
      case 'active': return <span className="badge badge-success">Active</span>;
      case 'inactive': return <span className="badge badge-warning">Inactive</span>;
      case 'decommissioned': return <span className="badge badge-danger">Decommissioned</span>;
      default: return <span className="badge badge-info">{status}</span>;
    }
  };

  return (
    <div>
      <h1 className="page-title">Water Meters</h1>
      
      {loading ? (
        <div className="loader"></div>
      ) : (
        <div className="glass-panel table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Serial Number</th>
                <th>Owner (User)</th>
                <th>Status</th>
                <th>Installation Date</th>
              </tr>
            </thead>
            <tbody>
              {meters.length === 0 ? (
                <tr>
                  <td colSpan="4" style={{ textAlign: 'center', color: 'var(--text-secondary)', padding: '2rem' }}>No meters found</td>
                </tr>
              ) : (
                meters.map(meter => (
                  <tr key={meter._id}>
                    <td style={{ fontWeight: 500 }}>{meter.serialNumber}</td>
                    <td>
                      <div>{meter.userId?.fullName || 'N/A'}</div>
                      <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>
                        {meter.userId?.accountNumber}
                      </div>
                    </td>
                    <td>{getStatusBadge(meter.status)}</td>
                    <td>{meter.installationDate ? new Date(meter.installationDate).toLocaleDateString() : 'N/A'}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};

export default Meters;
