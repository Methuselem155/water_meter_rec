import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Droplets } from 'lucide-react';
import api from '../services/api';

const Login = () => {
  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleLogin = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      // Determine if identifier is phone or account number
      const payload = { password };
      if (/^\d{10,}$/.test(identifier) || identifier.startsWith('+')) {
        payload.phoneNumber = identifier;
      } else {
        payload.accountNumber = identifier;
      }

      const response = await api.post('/auth/login', payload);
      
      if (response.success && response.data && response.data.token) {
        // Here we should ideally check if role is admin via decoding the token or getting a /me response.
        // For simplicity, we assume login success means they might be an admin, but the API will block non-admins
        localStorage.setItem('adminToken', response.data.token);
        
        // Let's quickly check admin role by calling a test endpoint
        try {
           await api.get('/admin/stats');
           navigate('/');
        } catch (adminErr) {
           localStorage.removeItem('adminToken');
           setError('Access Denied: You are not an administrator.');
        }
      } else {
        setError(response.message || 'Login failed');
      }
    } catch (err) {
      setError(err?.message || 'Invalid credentials or server error. Make sure you have an admin account.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-container">
      <div className="auth-card glass-panel">
        <div style={{ display: 'flex', justifyContent: 'center', marginBottom: '1.5rem' }}>
           <div className="stat-icon" style={{ width: 60, height: 60, borderRadius: '50%' }}>
              <Droplets size={32} />
           </div>
        </div>
        <h1 className="auth-title">Admin Portal</h1>
        <p className="auth-subtitle">Water Meter Management System</p>

        {error && <div className="error-message">{error}</div>}

        <form onSubmit={handleLogin}>
          <div className="form-group">
            <label className="form-label">Phone or Account Number</label>
            <input 
              type="text" 
              className="form-input" 
              placeholder="e.g. 078xxxxxxx or ACC12345"
              value={identifier}
              onChange={(e) => setIdentifier(e.target.value)}
              required
            />
          </div>
          <div className="form-group">
            <label className="form-label">Password</label>
            <input 
              type="password" 
              className="form-input" 
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>
          <button type="submit" className="btn btn-primary btn-block" disabled={loading}>
            {loading ? 'Authenticating...' : 'Sign In'}
          </button>
        </form>
      </div>
    </div>
  );
};

export default Login;
