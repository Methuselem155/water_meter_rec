import React, { useEffect, useState } from 'react';
import { UserPlus, Trash2, X } from 'lucide-react';
import api from '../services/api';

const CATEGORIES = ['PUBLIC TAP', 'RESIDENTIAL', 'NON RESIDENTIAL', 'INDUSTRIES'];

const emptyForm = {
  accountNumber: '', fullName: '', phoneNumber: '',
  email: '', password: '', meterSerialNumber: '', category: 'RESIDENTIAL',
};

const Users = () => {
  const [users, setUsers]       = useState([]);
  const [loading, setLoading]   = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [form, setForm]         = useState(emptyForm);
  const [saving, setSaving]     = useState(false);
  const [error, setError]       = useState('');
  const [deleteId, setDeleteId] = useState(null);

  const fetchUsers = async () => {
    setLoading(true);
    try {
      const res = await api.get('/admin/users');
      setUsers(res.data || []);
    } catch (err) {
      console.error('Failed to load users', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchUsers(); }, []);

  const handleCreate = async (e) => {
    e.preventDefault();
    setSaving(true);
    setError('');
    try {
      await api.post('/admin/users', form);
      setShowModal(false);
      setForm(emptyForm);
      fetchUsers();
    } catch (err) {
      setError(err?.message || 'Failed to create user');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id) => {
    try {
      await api.delete(`/admin/users/${id}`);
      setDeleteId(null);
      fetchUsers();
    } catch (err) {
      alert(err?.message || 'Failed to delete user');
    }
  };

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
        <h1 className="page-title" style={{ margin: 0 }}>Registered Users</h1>
        <button className="btn btn-primary" onClick={() => { setShowModal(true); setError(''); setForm(emptyForm); }}>
          <UserPlus size={16} style={{ marginRight: 6 }} />
          Add User
        </button>
      </div>

      {loading ? (
        <div className="loader"></div>
      ) : (
        <div className="glass-panel table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Account #</th>
                <th>Full Name</th>
                <th>Phone</th>
                <th>Category</th>
                <th>Meter Serial</th>
                <th>Joined</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {users.length === 0 ? (
                <tr>
                  <td colSpan="7" style={{ textAlign: 'center', color: 'var(--text-secondary)', padding: '2rem' }}>
                    No users found
                  </td>
                </tr>
              ) : (
                users.map(user => (
                  <tr key={user._id}>
                    <td style={{ fontWeight: 500 }}>{user.accountNumber}</td>
                    <td>{user.fullName}</td>
                    <td>{user.phoneNumber}</td>
                    <td><span className="badge badge-info">{user.category}</span></td>
                    <td>{user.meter?.serialNumber || '—'}</td>
                    <td>{new Date(user.createdAt).toLocaleDateString()}</td>
                    <td>
                      <button
                        onClick={() => setDeleteId(user._id)}
                        style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#ef4444' }}
                        title="Delete user"
                      >
                        <Trash2 size={16} />
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* Add User Modal */}
      {showModal && (
        <div style={styles.overlay}>
          <div className="glass-panel" style={styles.modal}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
              <h2 style={{ margin: 0, fontSize: '1.2rem' }}>Add New User</h2>
              <button onClick={() => setShowModal(false)} style={{ background: 'none', border: 'none', cursor: 'pointer' }}>
                <X size={20} />
              </button>
            </div>

            {error && <div className="error-message" style={{ marginBottom: '1rem' }}>{error}</div>}

            <form onSubmit={handleCreate}>
              {[
                { label: 'Account Number', key: 'accountNumber', type: 'text', required: true },
                { label: 'Full Name',      key: 'fullName',      type: 'text', required: true },
                { label: 'Phone Number',   key: 'phoneNumber',   type: 'text', required: true },
                { label: 'Email',          key: 'email',         type: 'email', required: false },
                { label: 'Password',       key: 'password',      type: 'password', required: true },
                { label: 'Meter Serial Number', key: 'meterSerialNumber', type: 'text', required: true },
              ].map(({ label, key, type, required }) => (
                <div className="form-group" key={key}>
                  <label className="form-label">{label}{required && ' *'}</label>
                  <input
                    type={type}
                    className="form-input"
                    value={form[key]}
                    onChange={e => setForm(f => ({ ...f, [key]: e.target.value }))}
                    required={required}
                  />
                </div>
              ))}

              <div className="form-group">
                <label className="form-label">Customer Category *</label>
                <select
                  className="form-input"
                  value={form.category}
                  onChange={e => setForm(f => ({ ...f, category: e.target.value }))}
                  required
                >
                  {CATEGORIES.map(c => <option key={c} value={c}>{c}</option>)}
                </select>
              </div>

              <div style={{ display: 'flex', gap: '1rem', marginTop: '1.5rem' }}>
                <button type="button" className="btn" onClick={() => setShowModal(false)} style={{ flex: 1 }}>
                  Cancel
                </button>
                <button type="submit" className="btn btn-primary" disabled={saving} style={{ flex: 1 }}>
                  {saving ? 'Creating...' : 'Create User'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete Confirm Modal */}
      {deleteId && (
        <div style={styles.overlay}>
          <div className="glass-panel" style={{ ...styles.modal, maxWidth: 400 }}>
            <h2 style={{ marginBottom: '1rem', fontSize: '1.1rem' }}>Confirm Delete</h2>
            <p style={{ color: 'var(--text-secondary)', marginBottom: '1.5rem' }}>
              This will permanently delete the user and all their readings and bills.
            </p>
            <div style={{ display: 'flex', gap: '1rem' }}>
              <button className="btn" onClick={() => setDeleteId(null)} style={{ flex: 1 }}>Cancel</button>
              <button
                className="btn"
                onClick={() => handleDelete(deleteId)}
                style={{ flex: 1, background: '#ef4444', color: '#fff' }}
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

const styles = {
  overlay: {
    position: 'fixed', inset: 0,
    background: 'rgba(0,0,0,0.6)',
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    zIndex: 1000,
  },
  modal: {
    width: '100%', maxWidth: 520,
    maxHeight: '90vh', overflowY: 'auto',
    padding: '2rem',
  },
};

export default Users;
