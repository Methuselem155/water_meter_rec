import React, { useEffect, useState } from 'react';
import api from '../services/api';

const Bills = () => {
  const [bills, setBills] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchBills = async () => {
      try {
        const response = await api.get('/admin/bills');
        setBills(response.data || []);
      } catch (err) {
        console.error('Failed to load bills', err);
      } finally {
        setLoading(false);
      }
    };
    fetchBills();
  }, []);

  const getStatusBadge = (status) => {
    switch(status) {
      case 'paid': return <span className="badge badge-success">Paid</span>;
      case 'final': return <span className="badge badge-info">Final (Unpaid)</span>;
      case 'draft': return <span className="badge badge-warning">Draft</span>;
      default: return <span className="badge badge-info">{status}</span>;
    }
  };

  return (
    <div>
      <h1 className="page-title">Invoices & Bills</h1>
      
      {loading ? (
        <div className="loader"></div>
      ) : (
        <div className="glass-panel table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Customer</th>
                <th>Consumption</th>
                <th>Total Amnt (Inc. VAT)</th>
                <th>Generated Date</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {bills.length === 0 ? (
                <tr>
                  <td colSpan="5" style={{ textAlign: 'center', color: 'var(--text-secondary)', padding: '2rem' }}>No bills found</td>
                </tr>
              ) : (
                bills.map(bill => (
                  <tr key={bill._id}>
                    <td>
                      <div style={{ fontWeight: 500 }}>{bill.userId?.fullName || 'N/A'}</div>
                      <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>
                        {bill.userId?.accountNumber}
                      </div>
                    </td>
                    <td>{bill.consumption ? `${bill.consumption} m³` : '—'}</td>
                    <td style={{ fontWeight: 500, color: 'var(--success)' }}>
                      {bill.totalAmountVatInclusive ? `RWF ${bill.totalAmountVatInclusive.toLocaleString()}` : '—'}
                    </td>
                    <td>{new Date(bill.generatedDate).toLocaleDateString()}</td>
                    <td>{getStatusBadge(bill.status)}</td>
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

export default Bills;
