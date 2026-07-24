import React, { createContext, useContext, useState, useEffect } from 'react';
import { apiService } from '../services/apiService';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    try {
      const savedUser = localStorage.getItem('caregiver_admin_user');
      if (savedUser) {
        setUser(JSON.parse(savedUser));
      }
    } catch (e) {
      console.error('Failed to parse saved user credentials', e);
    } finally {
      setLoading(false);
    }
  }, []);

  const login = async (email, password) => {
    setError(null);
    setLoading(true);
    try {
      const response = await apiService.login(email, password);
      if (response && response.success && response.data) {
        const userData = response.data;
        // Verify user role if needed (caregiver or admin)
        setUser(userData);
        localStorage.setItem('caregiver_admin_user', JSON.stringify(userData));
        setLoading(false);
        return { success: true, user: userData };
      } else {
        const errMsg = response?.error || 'Invalid credentials or user not found.';
        setError(errMsg);
        setLoading(false);
        return { success: false, error: errMsg };
      }
    } catch (err) {
      const errMsg = err.message || 'An unexpected error occurred during login.';
      setError(errMsg);
      setLoading(false);
      return { success: false, error: errMsg };
    }
  };

  const logout = () => {
    setUser(null);
    localStorage.removeItem('caregiver_admin_user');
  };

  const caregiverId = user?.caregiver_id || user?.id || user?.user_id || 1;

  return (
    <AuthContext.Provider
      value={{
        user,
        isAuthenticated: !!user,
        caregiverId,
        loading,
        error,
        login,
        logout,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
