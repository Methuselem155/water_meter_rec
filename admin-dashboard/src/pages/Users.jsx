import React, { useEffect, useState } from 'react';
import api from '../services/api';

const Users = () => {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchUsers = async () => {
      try {
        const response = await api.get('/admin/users');
        setUsers(response.data || []);
      } catch (err) {
        console.error('Failed to load users', err);
      } finally {
        setLoading(false);
      }
    };
    fetchUsers();
  }, []);

  return (
    <div>
      <h1 className="page-title">Registered Users</h1>
      
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
                <th>Joined Date</th>
              </tr>
            </thead>
            <tbody>
              {users.length === 0 ? (
                <tr>
                  <td colSpan="5" style={{ textAlign: 'center', color: 'var(--text-secondary)', padding: '2rem' }}>No users found</td>
                </tr>
              ) : (
                users.map(user => (
                  <tr key={user._id}>
                    <td style={{ fontWeight: 500 }}>{user.accountNumber}</td>
                    <td>{user.fullName}</td>
                    <td>{user.phoneNumber}</td>
                    <td>
                      <span className="badge badge-info">{user.category}</span>
                    </td>
                    <td>{new Date(user.createdAt).toLocaleDateString()}</td>
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

export default Users;
