import axios from 'axios';

// The baseUrl is now proxied via vite.config.js
// so we can just use /api for backend calls
const api = axios.create({
    baseURL: '/api',
});

// Interceptor to attach token
api.interceptors.request.use((config) => {
    const token = localStorage.getItem('adminToken');
    if (token) {
        config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
}, (error) => Promise.reject(error));

// Interceptor to handle responses and global errors
api.interceptors.response.use(
    (response) => response.data,
    (error) => {
        if (error.response && error.response.status === 401) {
            // Token expired or invalid
            localStorage.removeItem('adminToken');
            // We can optionally redirect here or let the auth hook handle it
        }
        return Promise.reject(error.response?.data || error);
    }
);

export default api;
