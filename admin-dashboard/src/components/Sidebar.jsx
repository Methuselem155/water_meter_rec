import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { Home, Users, Settings as Gauge, FileText, FileCheck, LogOut, Droplets } from 'lucide-react';

const Sidebar = () => {
  const navigate = useNavigate();

  const handleLogout = () => {
    localStorage.removeItem('adminToken');
    navigate('/login');
  };

  const navItems = [
    { name: 'Dashboard', path: '/', icon: <Home size={20} /> },
    { name: 'Users', path: '/users', icon: <Users size={20} /> },
    { name: 'Meters', path: '/meters', icon: <Gauge size={20} /> },
    { name: 'Readings', path: '/readings', icon: <FileCheck size={20} /> },
    { name: 'Bills', path: '/bills', icon: <FileText size={20} /> },
  ];

  return (
    <aside className="sidebar">
      <div className="sidebar-header">
        <Droplets size={24} style={{ marginRight: '10px', color: 'var(--accent-primary)' }} />
        <span>MeterAdmin</span>
      </div>
      
      <nav className="sidebar-nav">
        {navItems.map((item) => (
          <NavLink 
            key={item.path}
            to={item.path} 
            className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
            end={item.path === '/'}
          >
            {item.icon}
            {item.name}
          </NavLink>
        ))}
      </nav>

      <div className="sidebar-footer">
        <button 
          onClick={handleLogout}
          className="nav-item" 
          style={{ width: '100%', border: 'none', background: 'transparent', cursor: 'pointer', padding: '0.75rem 0' }}
        >
          <LogOut size={20} />
          Sign Out
        </button>
      </div>
    </aside>
  );
};

export default Sidebar;
