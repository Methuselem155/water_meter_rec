import React, { useState, useRef, useEffect } from 'react';
import { Outlet } from 'react-router-dom';
import { User, LogOut, Shield, ChevronDown } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import Sidebar from './Sidebar';

const Layout = () => {
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const dropdownRef = useRef(null);
  const navigate = useNavigate();

  const logout = () => {
    localStorage.removeItem('adminToken');
    navigate('/login');
  };

  useEffect(() => {
    const handleClickOutside = (e) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target)) {
        setDropdownOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  return (
    <div className="dashboard-layout">
      <Sidebar />
      <main className="main-content">
        <header className="topbar">
          <div style={{ fontWeight: 500, color: 'var(--text-secondary)' }}>Welcome to the Control Panel</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
            <div ref={dropdownRef} style={{ position: 'relative' }}>
              <button
                onClick={() => setDropdownOpen((o) => !o)}
                style={{
                  display: 'flex', alignItems: 'center', gap: '0.5rem',
                  background: 'transparent', border: 'none', cursor: 'pointer', padding: 0,
                }}
              >
                <div style={{
                  width: 36, height: 36, borderRadius: '50%',
                  background: 'var(--accent-primary)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  color: 'white', fontWeight: 'bold', fontSize: 14,
                }}>
                  AD
                </div>
                <ChevronDown
                  size={14}
                  color="var(--text-secondary)"
                  style={{ transform: dropdownOpen ? 'rotate(180deg)' : 'rotate(0)', transition: 'transform 0.2s' }}
                />
              </button>

              {dropdownOpen && (
                <div style={{
                  position: 'absolute', top: 'calc(100% + 10px)', right: 0,
                  width: 230, borderRadius: 12,
                  background: 'var(--bg-secondary)',
                  border: '1px solid var(--border-color)',
                  boxShadow: '0 8px 32px rgba(0,0,0,0.4)',
                  overflow: 'hidden', zIndex: 200,
                }}>
                  {/* Profile info */}
                  <div style={{
                    padding: '1rem 1.25rem',
                    borderBottom: '1px solid var(--border-color)',
                    display: 'flex', alignItems: 'center', gap: '0.75rem',
                  }}>
                    <div style={{
                      width: 42, height: 42, borderRadius: '50%',
                      background: 'linear-gradient(135deg, var(--accent-primary), #6d28d9)',
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      flexShrink: 0,
                    }}>
                      <User size={20} color="white" />
                    </div>
                    <div>
                      <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: 14 }}>Administrator</div>
                      <div style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 2 }}>admin@watermeter.rw</div>
                    </div>
                  </div>

                  {/* Role badge */}
                  <div style={{
                    padding: '0.75rem 1.25rem',
                    borderBottom: '1px solid var(--border-color)',
                    display: 'flex', alignItems: 'center', gap: '0.6rem',
                  }}>
                    <Shield size={15} color="var(--accent-primary)" />
                    <span style={{ fontSize: 13, color: 'var(--text-secondary)' }}>Role: </span>
                    <span style={{
                      fontSize: 12, fontWeight: 600,
                      background: 'rgba(99,102,241,0.15)',
                      color: 'var(--accent-primary)',
                      padding: '2px 8px', borderRadius: 20,
                    }}>Super Admin</span>
                  </div>

                  {/* Sign out */}
                  <button
                    onClick={() => { setDropdownOpen(false); logout(); }}
                    style={{
                      width: '100%', padding: '0.75rem 1.25rem',
                      background: 'transparent', border: 'none', cursor: 'pointer',
                      display: 'flex', alignItems: 'center', gap: '0.6rem',
                      color: '#ef4444', fontSize: 13, fontWeight: 600,
                      textAlign: 'left',
                    }}
                    onMouseEnter={(e) => e.currentTarget.style.background = 'rgba(239,68,68,0.08)'}
                    onMouseLeave={(e) => e.currentTarget.style.background = 'transparent'}
                  >
                    <LogOut size={15} />
                    Sign Out
                  </button>
                </div>
              )}
            </div>
          </div>
        </header>
        <div className="page-content">
          <Outlet />
        </div>
      </main>
    </div>
  );
};

export default Layout;
