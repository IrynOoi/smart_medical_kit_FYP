// AuthContext.jsx
import React, { createContext, useContext, useState, useEffect } from 'react';
import { apiService } from '../services/apiService';

// Create the authentication context object
const AuthContext = createContext(null);

/**
 * AuthProvider component manages global authentication states, session persistence via sessionStorage,
 * strict role validation (rejecting patient logins on the web portal), and profile synchronization.
 */
export const AuthProvider = ({ children }) => {
  // Authentication state hooks
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  /**
   * Initialize authentication status on component mount.
   */
  useEffect(() => {
    const initAuth = async () => {
      try {
        // Clear any old legacy localStorage persistence so the web app does not auto-sign-in across browser sessions
        localStorage.removeItem('caregiver_admin_user');

        // Use sessionStorage so the login session only lasts for the active browser session
        const savedUser = sessionStorage.getItem('caregiver_admin_user');
        if (savedUser) {
          const parsed = JSON.parse(savedUser);
          const userRole = (parsed.role || '').toLowerCase();

          // Enforce role restriction on session reload
          if (userRole === 'patient' || (userRole !== 'caregiver' && userRole !== 'admin')) {
            sessionStorage.removeItem('caregiver_admin_user');
            setUser(null);
          } else {
            setUser(parsed);

            // Fetch caregiver profile details to get full_name and latest profile photo
            const cid = parsed.caregiver_id || parsed.id || parsed.user_id;
            if (cid) {
              const res = await apiService.getCaregiverProfile(cid);
              if (res && res.success && res.data) {
                const merged = { ...parsed, ...res.data };
                setUser(merged);
                sessionStorage.setItem('caregiver_admin_user', JSON.stringify(merged));
              }
            }
          }
        }
      } catch (e) {
        console.error('Failed to parse saved user credentials', e);
      } finally {
        setLoading(false);
      }
    };
    initAuth();
  }, []);

  /**
   * Updates current user state and synchronizes changes to sessionStorage.
   */
  const updateUser = (newUserData) => {
    setUser((prev) => {
      const updated = { ...(prev || {}), ...newUserData };
      sessionStorage.setItem('caregiver_admin_user', JSON.stringify(updated));
      return updated;
    });
  };

  /**
   * Authenticates a caregiver with email and password credentials, enforcing strict role checks.
   */
  const login = async (email, password) => {
    setError(null);
    try {
      const response = await apiService.login(email, password);
      if (response && response.success && (response.data || response.user)) {
        const userData = response.data || response.user;
        const userRole = (userData.role || '').toLowerCase();

        // Strict role validation: Reject patient login on Web Portal
        if (userRole === 'patient') {
          const errMsg = 'Access Denied: Patient accounts are not permitted to log into the Web Portal. Please use the mobile application.';
          setError(errMsg);
          return { success: false, error: errMsg };
        }

        // Enforce that only caregivers or admins are allowed
        if (userRole !== 'caregiver' && userRole !== 'admin') {
          const errMsg = 'Access Denied: Only registered caregivers are authorized to log into this portal.';
          setError(errMsg);
          return { success: false, error: errMsg };
        }

        setUser(userData);
        sessionStorage.setItem('caregiver_admin_user', JSON.stringify(userData));

        // Fetch complete caregiver details if available
        const cid = userData.caregiver_id || userData.id || userData.user_id;
        if (cid) {
          try {
            const profileRes = await apiService.getCaregiverProfile(cid);
            if (profileRes && profileRes.success && profileRes.data) {
              const merged = { ...userData, ...profileRes.data };
              setUser(merged);
              sessionStorage.setItem('caregiver_admin_user', JSON.stringify(merged));
            }
          } catch (e) {
            console.error('Error fetching initial caregiver profile:', e);
          }
        }

        return { success: true, user: userData };
      } else {
        const errMsg = response?.message || response?.error || 'Invalid credentials or user not found.';
        setError(errMsg);
        return { success: false, error: errMsg };
      }
    } catch (err) {
      const errMsg = err.message || 'An unexpected error occurred during login.';
      setError(errMsg);
      return { success: false, error: errMsg };
    }
  };

  /**
   * Logs out the current user and clears all session storage and local persistence.
   */
  const logout = () => {
    setUser(null);
    sessionStorage.removeItem('caregiver_admin_user');
    localStorage.removeItem('caregiver_admin_user');
  };

  // Derive the active caregiver ID with fallback
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
        updateUser,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

/**
 * Custom hook to consume the authentication context safely within components.
 */
export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};