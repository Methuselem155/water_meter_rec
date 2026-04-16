import React, { useEffect, useState } from 'react';
import { Eye, Check, X, Trash2 } from 'lucide-react';
import api from '../services/api';

const Readings = () => {
  const [readings, setReadings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedImage, setSelectedImage] = useState(null);
  const [validatingId, setValidatingId] = useState(null);
  const [deletingId, setDeletingId] = useState(null);

  useEffect(() => {
    fetchReadings();
  }, []);

  const fetchReadings = async () => {
    try {
      const response = await api.get('/admin/readings');
      setReadings(response.data || []);
    } catch (err) {
      console.error('Failed to load readings', err);
    } finally {
      setLoading(false);
    }
  };

  const handleValidation = async (id, status) => {
    try {
      setValidatingId(id);
      await api.put(`/admin/readings/${id}/status`, { validationStatus: status });
      // Update local state
      setReadings(prev => prev.map(r => r._id === id ? { ...r, validationStatus: status } : r));
    } catch (err) {
      console.error('Failed to update status', err);
      alert('Failed to update reading status');
    } finally {
      setValidatingId(null);
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this reading? Any associated bill will also be removed.')) return;
    try {
      setDeletingId(id);
      await api.delete(`/admin/readings/${id}`);
      setReadings(prev => prev.filter(r => r._id !== id));
    } catch (err) {
      console.error('Failed to delete reading', err);
      alert('Failed to delete reading');
    } finally {
      setDeletingId(null);
    }
  };

  const getStatusBadge = (status) => {
    switch(status) {
      case 'validated': return <span className="badge badge-success">Validated</span>;
      case 'pending': return <span className="badge badge-warning">Pending</span>;
      case 'failed': return <span className="badge badge-danger">Failed</span>;
      case 'fraud_suspected': return <span className="badge badge-danger">Fraud Suspected</span>;
      default: return <span className="badge badge-info">{status}</span>;
    }
  };

  return (
    <div>
      <h1 className="page-title">Meter Readings</h1>
      
      {loading ? (
        <div className="loader"></div>
      ) : (
        <div className="glass-panel table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Meter Serial</th>
                <th>Value</th>
                <th>OCR Method</th>
                <th>Confidence</th>
                <th>Status</th>
                <th>Submission Time</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {readings.length === 0 ? (
                <tr>
                  <td colSpan="7" style={{ textAlign: 'center', color: 'var(--text-secondary)', padding: '2rem' }}>No readings found</td>
                </tr>
              ) : (
                readings.map(reading => (
                  <tr key={reading._id}>
                    <td style={{ fontWeight: 500 }}>
                      {reading.meterId?.serialNumber}
                      <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>
                        {reading.meterId?.userId?.fullName}
                      </div>
                    </td>
                    <td style={{ fontSize: '1.25rem', fontWeight: 'bold' }}>
                      {reading.readingValue !== null ? reading.readingValue : '—'}
                    </td>
                    <td>{reading.ocrMethod || 'N/A'}</td>
                    <td>{reading.confidence ? `${reading.confidence.toFixed(1)}%` : '—'}</td>
                    <td>{getStatusBadge(reading.validationStatus)}</td>
                    <td>{new Date(reading.submissionTime).toLocaleString()}</td>
                    <td>
                      <div className="flex items-center gap-2">
                        {reading.imagePath && (
                          <button
                            className="btn"
                            style={{ padding: '0.5rem', background: 'var(--bg-tertiary)', color: 'var(--accent-primary)' }}
                            onClick={() => setSelectedImage(`http://localhost:3000${reading.imagePath}`)}
                            title="View Image"
                          >
                            <Eye size={18} />
                          </button>
                        )}
                        {reading.validationStatus === 'pending' && (
                          <>
                            <button
                              className="btn"
                              style={{ padding: '0.5rem', background: 'rgba(16, 185, 129, 0.1)', color: 'var(--success)' }}
                              onClick={() => handleValidation(reading._id, 'validated')}
                              disabled={validatingId === reading._id}
                              title="Approve"
                            >
                              <Check size={18} />
                            </button>
                            <button
                              className="btn"
                              style={{ padding: '0.5rem', background: 'rgba(239, 68, 68, 0.1)', color: 'var(--danger)' }}
                              onClick={() => handleValidation(reading._id, 'failed')}
                              disabled={validatingId === reading._id}
                              title="Reject"
                            >
                              <X size={18} />
                            </button>
                          </>
                        )}
                        <button
                          className="btn"
                          style={{ padding: '0.5rem', background: 'rgba(239, 68, 68, 0.1)', color: 'var(--danger)' }}
                          onClick={() => handleDelete(reading._id)}
                          disabled={deletingId === reading._id}
                          title="Delete Reading"
                        >
                          <Trash2 size={18} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}

      {selectedImage && (
        <div className="modal-overlay" onClick={() => setSelectedImage(null)}>
          <div className="modal-content glass-panel" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h2 className="modal-title">Reading Image</h2>
              <button className="modal-close" onClick={() => setSelectedImage(null)}>
                <X size={24} />
              </button>
            </div>
            <img 
              src={selectedImage} 
              alt="Meter Reading" 
              style={{ width: '100%', borderRadius: 'var(--radius-sm)' }} 
              onError={(e) => { e.target.src = 'https://via.placeholder.com/400x300?text=Image+Not+Found' }}
            />
          </div>
        </div>
      )}
    </div>
  );
};

export default Readings;
