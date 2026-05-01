import React, { useEffect, useState } from 'react';
import { Save, Plus, Trash2, X } from 'lucide-react';
import api from '../services/api';

const Tariffs = () => {
  const [tariffs, setTariffs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState(null);
  const [form, setForm] = useState(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const fetchTariffs = async () => {
    setLoading(true);
    try {
      const res = await api.get('/admin/tariffs');
      setTariffs(res.data || []);
    } catch (err) {
      console.error('Failed to load tariffs', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchTariffs(); }, []);

  const startEdit = (tariff) => {
    setEditing(tariff._id);
    setError('');
    setSuccess('');
    setForm({
      type: tariff.type,
      rate: tariff.rate || '',
      vatRate: (tariff.vatRate * 100).toFixed(0),
      bands: tariff.type === 'progressive'
        ? tariff.bands.map(b => ({ upTo: b.upTo >= 999999 ? '' : b.upTo, rate: b.rate }))
        : [{ upTo: '', rate: '' }],
    });
  };

  const cancelEdit = () => {
    setEditing(null);
    setForm(null);
    setError('');
  };

  const addBand = () => {
    setForm(f => ({ ...f, bands: [...f.bands, { upTo: '', rate: '' }] }));
  };

  const removeBand = (idx) => {
    setForm(f => ({ ...f, bands: f.bands.filter((_, i) => i !== idx) }));
  };

  const updateBand = (idx, field, value) => {
    setForm(f => ({
      ...f,
      bands: f.bands.map((b, i) => i === idx ? { ...b, [field]: value } : b),
    }));
  };

  const handleSave = async (id) => {
    setSaving(true);
    setError('');
    setSuccess('');
    try {
      const payload = {
        type: form.type,
        vatRate: parseFloat(form.vatRate) / 100,
      };

      if (form.type === 'flat') {
        payload.rate = parseFloat(form.rate);
      } else {
        payload.bands = form.bands.map((b, i) => ({
          upTo: b.upTo === '' || i === form.bands.length - 1 ? 999999 : parseFloat(b.upTo),
          rate: parseFloat(b.rate),
        }));
      }

      await api.put(`/admin/tariffs/${id}`, payload);
      setEditing(null);
      setForm(null);
      setSuccess('Tariff updated successfully');
      setTimeout(() => setSuccess(''), 3000);
      fetchTariffs();
    } catch (err) {
      setError(err?.message || 'Failed to update tariff');
    } finally {
      setSaving(false);
    }
  };

  const formatRate = (rate) => `${rate.toLocaleString()} RWF/m³`;

  return (
    <div>
      <h1 className="page-title">WASAC Tariff Configuration</h1>
      <p style={{ color: 'var(--text-secondary)', marginBottom: '1.5rem' }}>
        Manage water tariff rates by customer category. Changes apply to all future bills.
      </p>

      {success && (
        <div style={{ ...msgStyle, background: 'rgba(16,185,129,0.1)', border: '1px solid var(--success)', color: 'var(--success)' }}>
          {success}
        </div>
      )}
      {error && !editing && (
        <div style={{ ...msgStyle, background: 'rgba(239,68,68,0.1)', border: '1px solid var(--danger)', color: 'var(--danger)' }}>
          {error}
        </div>
      )}

      {loading ? (
        <div className="loader"></div>
      ) : (
        <div style={{ display: 'grid', gap: '1.5rem' }}>
          {tariffs.map(tariff => (
            <div className="glass-panel" key={tariff._id} style={{ padding: '1.5rem' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
                <div>
                  <h2 style={{ fontSize: '1.1rem', margin: 0 }}>{tariff.category}</h2>
                  <span style={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
                    {tariff.type === 'flat' ? 'Flat rate' : 'Progressive (block) rate'} · VAT: {(tariff.vatRate * 100).toFixed(0)}%
                  </span>
                </div>
                {editing !== tariff._id && (
                  <button className="btn btn-primary" onClick={() => startEdit(tariff)} style={{ fontSize: '0.85rem', padding: '0.5rem 1rem' }}>
                    Edit
                  </button>
                )}
              </div>

              {editing === tariff._id ? (
                <div>
                  {error && <div className="error-message" style={{ marginBottom: '1rem' }}>{error}</div>}

                  <div className="form-group">
                    <label className="form-label">Tariff Type</label>
                    <select className="form-input" value={form.type} onChange={e => setForm(f => ({ ...f, type: e.target.value }))}>
                      <option value="flat">Flat Rate</option>
                      <option value="progressive">Progressive (Block)</option>
                    </select>
                  </div>

                  <div className="form-group">
                    <label className="form-label">VAT Rate (%)</label>
                    <input
                      type="number"
                      className="form-input"
                      value={form.vatRate}
                      onChange={e => setForm(f => ({ ...f, vatRate: e.target.value }))}
                      min="0" max="100" step="1"
                    />
                  </div>

                  {form.type === 'flat' ? (
                    <div className="form-group">
                      <label className="form-label">Rate (RWF per m³)</label>
                      <input
                        type="number"
                        className="form-input"
                        value={form.rate}
                        onChange={e => setForm(f => ({ ...f, rate: e.target.value }))}
                        min="0"
                      />
                    </div>
                  ) : (
                    <div>
                      <label className="form-label" style={{ marginBottom: '0.5rem', display: 'block' }}>Rate Bands</label>
                      {form.bands.map((band, idx) => (
                        <div key={idx} style={{ display: 'flex', gap: '0.75rem', alignItems: 'center', marginBottom: '0.5rem' }}>
                          <div style={{ flex: 1 }}>
                            {idx === form.bands.length - 1 ? (
                              <input className="form-input" value="Above previous" disabled style={{ opacity: 0.6 }} />
                            ) : (
                              <input
                                type="number"
                                className="form-input"
                                placeholder="Up to (m³)"
                                value={band.upTo}
                                onChange={e => updateBand(idx, 'upTo', e.target.value)}
                                min="0"
                              />
                            )}
                          </div>
                          <div style={{ flex: 1 }}>
                            <input
                              type="number"
                              className="form-input"
                              placeholder="Rate (RWF/m³)"
                              value={band.rate}
                              onChange={e => updateBand(idx, 'rate', e.target.value)}
                              min="0"
                            />
                          </div>
                          {form.bands.length > 1 && (
                            <button onClick={() => removeBand(idx)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--danger)' }}>
                              <Trash2 size={16} />
                            </button>
                          )}
                        </div>
                      ))}
                      <button className="btn" onClick={addBand} style={{ fontSize: '0.8rem', marginTop: '0.25rem' }}>
                        <Plus size={14} style={{ marginRight: 4 }} /> Add Band
                      </button>
                    </div>
                  )}

                  <div style={{ display: 'flex', gap: '1rem', marginTop: '1.5rem' }}>
                    <button className="btn" onClick={cancelEdit} style={{ flex: 1 }}>
                      <X size={14} style={{ marginRight: 4 }} /> Cancel
                    </button>
                    <button className="btn btn-primary" onClick={() => handleSave(tariff._id)} disabled={saving} style={{ flex: 1 }}>
                      <Save size={14} style={{ marginRight: 4 }} />
                      {saving ? 'Saving...' : 'Save Changes'}
                    </button>
                  </div>
                </div>
              ) : (
                <div>
                  {tariff.type === 'flat' ? (
                    <div style={rateBoxStyle}>
                      <span style={{ color: 'var(--text-secondary)' }}>Rate:</span>
                      <span style={{ fontWeight: 600, fontSize: '1.1rem' }}>{formatRate(tariff.rate)}</span>
                    </div>
                  ) : (
                    <div className="table-container">
                      <table className="data-table">
                        <thead>
                          <tr>
                            <th>Consumption Band</th>
                            <th>Rate (RWF/m³)</th>
                          </tr>
                        </thead>
                        <tbody>
                          {tariff.bands.map((band, idx) => {
                            const prev = idx === 0 ? 0 : tariff.bands[idx - 1].upTo;
                            const label = band.upTo >= 999999
                              ? `Above ${prev} m³`
                              : `${prev + 1}–${band.upTo} m³`;
                            return (
                              <tr key={idx}>
                                <td>{label}</td>
                                <td style={{ fontWeight: 500 }}>{band.rate.toLocaleString()}</td>
                              </tr>
                            );
                          })}
                        </tbody>
                      </table>
                    </div>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

const msgStyle = {
  padding: '0.75rem 1rem',
  borderRadius: 'var(--radius-sm)',
  marginBottom: '1rem',
  fontSize: '0.9rem',
};

const rateBoxStyle = {
  display: 'flex',
  gap: '0.75rem',
  alignItems: 'center',
  padding: '0.75rem 1rem',
  background: 'var(--bg-tertiary)',
  borderRadius: 'var(--radius-sm)',
};

export default Tariffs;
