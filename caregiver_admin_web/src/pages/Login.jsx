// Login.jsx
import React, { useState } from 'react';
import {
  Mail, Lock, LogIn, AlertCircle, Sparkles, Eye, EyeOff, X,
  User, Phone, Calendar, MapPin, CheckCircle2, UserPlus
} from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { apiService } from '../services/apiService';
import logoPng from '../assets/medical-smart-kit-logo.png';

export default function Login() {
  const { login } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');
  const [showPassword, setShowPassword] = useState(false);

  // Forgot Password modal state
  const [showForgotModal, setShowForgotModal] = useState(false);
  const [resetEmail, setResetEmail] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [resetLoading, setResetLoading] = useState(false);
  const [resetMessage, setResetMessage] = useState({ type: '', text: '' });

  // Caregiver Registration modal state
  const [showRegisterModal, setShowRegisterModal] = useState(false);
  const [regName, setRegName] = useState('');
  const [regEmail, setRegEmail] = useState('');
  const [regPassword, setRegPassword] = useState('');
  const [regConfirmPassword, setRegConfirmPassword] = useState('');
  const [showRegPassword, setShowRegPassword] = useState(false);
  const [showRegConfirmPassword, setShowRegConfirmPassword] = useState(false);
  const [regPhone, setRegPhone] = useState('');
  const [regGender, setRegGender] = useState('Male');
  const [regDob, setRegDob] = useState('');
  const [regAddress, setRegAddress] = useState('');
  const [regLoading, setRegLoading] = useState(false);
  const [regError, setRegError] = useState('');
  const [regSuccess, setRegSuccess] = useState('');

  const get18YearsAgoDate = () => {
    const today = new Date();
    const maxYear = today.getFullYear() - 18;
    const month = String(today.getMonth() + 1).padStart(2, '0');
    const day = String(today.getDate()).padStart(2, '0');
    return `${maxYear}-${month}-${day}`;
  };

  const calculateAge = (dobString) => {
    if (!dobString) return 0;
    const birthDate = new Date(dobString);
    const today = new Date();
    let age = today.getFullYear() - birthDate.getFullYear();
    const m = today.getMonth() - birthDate.getMonth();
    if (m < 0 || (m === 0 && today.getDate() < birthDate.getDate())) {
      age--;
    }
    return age;
  };

  const handleRegisterSubmit = async (e) => {
    e.preventDefault();
    setRegError('');
    setRegSuccess('');

    if (!regName || !regEmail || !regPassword || !regConfirmPassword || !regPhone || !regDob || !regAddress) {
      setRegError('Please fill in all required fields.');
      return;
    }

    if (regPassword.length < 6) {
      setRegError('Password must be at least 6 characters long.');
      return;
    }

    if (regPassword !== regConfirmPassword) {
      setRegError('Passwords do not match.');
      return;
    }

    const age = calculateAge(regDob);
    if (age < 18) {
      setRegError('Caregiver must be at least 18 years old to create an account.');
      return;
    }

    setRegLoading(true);
    try {
      const res = await apiService.register({
        role: 'caregiver',
        email: regEmail,
        password: regPassword,
        fullname: regName,
        gender: regGender,
        phone_no: regPhone,
        date_of_birth: regDob,
        address: regAddress,
      });

      if (res.success) {
        setRegSuccess('Caregiver account created successfully! You can now log in.');
        setEmail(regEmail);
        setTimeout(() => {
          setShowRegisterModal(false);
          setRegSuccess('');
          setRegName('');
          setRegEmail('');
          setRegPassword('');
          setRegConfirmPassword('');
          setRegPhone('');
          setRegGender('Male');
          setRegDob('');
          setRegAddress('');
        }, 2000);
      } else {
        setRegError(res.error || res.message || 'Failed to create caregiver account.');
      }
    } catch (err) {
      setRegError('Network error. Please try again.');
    } finally {
      setRegLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!email || !password) {
      setErrorMessage('Please enter both email address and password.');
      return;
    }

    setLoading(true);
    setErrorMessage('');

    const result = await login(email, password);
    if (!result.success) {
      setErrorMessage(result.error || 'Login failed. Please check your credentials.');
    }
    setLoading(false);
  };

  const handleResetPassword = async (e) => {
    e.preventDefault();
    if (!resetEmail || !newPassword || !confirmPassword) {
      setResetMessage({ type: 'error', text: 'All fields are required.' });
      return;
    }
    if (newPassword !== confirmPassword) {
      setResetMessage({ type: 'error', text: 'Passwords do not match.' });
      return;
    }
    if (newPassword.length < 6) {
      setResetMessage({ type: 'error', text: 'Password must be at least 6 characters.' });
      return;
    }

    setResetLoading(true);
    setResetMessage({ type: '', text: '' });

    try {
      const result = await apiService.resetPassword(resetEmail, newPassword);
      if (result.success) {
        setResetMessage({ type: 'success', text: 'Password reset successfully! You can now log in.' });
        // Optionally close modal after a delay
        setTimeout(() => {
          setShowForgotModal(false);
          setResetEmail('');
          setNewPassword('');
          setConfirmPassword('');
          setResetMessage({ type: '', text: '' });
        }, 2000);
      } else {
        setResetMessage({ type: 'error', text: result.error || 'Failed to reset password.' });
      }
    } catch (err) {
      setResetMessage({ type: 'error', text: 'Network error. Please try again.' });
    }
    setResetLoading(false);
  };

  return (
    <div className="login-container">
      {/* Background Decorations (unchanged) */}
      <div style={{ position: 'absolute', top: '-10%', left: '-10%', width: '400px', height: '400px', borderRadius: '50%', background: 'rgba(255,255,255,0.06)', filter: 'blur(40px)', pointerEvents: 'none' }} />
      <div style={{ position: 'absolute', bottom: '-10%', right: '-10%', width: '400px', height: '400px', borderRadius: '50%', background: 'rgba(255,255,255,0.08)', filter: 'blur(40px)', pointerEvents: 'none' }} />

      <div className="login-card">
        {/* Logo & Header */}
        <div className="login-logo">
          <div className="login-logo-icon">
            <img
              src={logoPng}
              alt="Medical Smart Kit Logo"
              style={{
                width: '100px',
                height: '100px',
                borderRadius: '14px',
                border: '2px solid #cccccc',
                objectFit: 'contain',
                backgroundColor: '#ffffff',
                padding: '4px'
              }}
            />
          </div>
          <h2 style={{ fontSize: '1.6rem', color: '#2D3142', marginBottom: '6px' }}>
            Caregiver Portal
          </h2>
          <p style={{ fontSize: '0.88rem', color: '#6B7280' }}>
            Sign in to monitor patients, prescriptions & IoT kit hardware
          </p>
        </div>

        {/* Error Alert */}
        {errorMessage && (
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '10px',
            padding: '12px 16px',
            background: '#FEE2E2',
            border: '1px solid #FCA5A5',
            borderRadius: '12px',
            color: '#B91C1C',
            fontSize: '0.85rem',
            marginBottom: '20px'
          }}>
            <AlertCircle size={18} style={{ flexShrink: 0 }} />
            <span>{errorMessage}</span>
          </div>
        )}

        {/* Form */}
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label>Caregiver Email</label>
            <div className="form-input-wrapper">
              <Mail className="form-input-icon" size={18} />
              <input
                type="email"
                placeholder="caregiver@example.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
              />
            </div>
          </div>

          <div className="form-group">
            <label>Password</label>
            <div className="form-input-wrapper" style={{ position: 'relative' }}>
              <Lock className="form-input-icon" size={18} />
              <input
                type={showPassword ? 'text' : 'password'}
                placeholder="••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                style={{ paddingRight: '40px' }}
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                style={{
                  position: 'absolute',
                  right: '10px',
                  top: '50%',
                  transform: 'translateY(-50%)',
                  background: 'none',
                  border: 'none',
                  cursor: 'pointer',
                  color: '#6B7280',
                  padding: '4px',
                }}
              >
                {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>
          </div>

          <button
            type="submit"
            className="btn btn-primary"
            disabled={loading}
            style={{ width: '100%', padding: '14px', marginTop: '10px', fontSize: '1rem' }}
          >
            {loading ? (
              <span>Authenticating...</span>
            ) : (
              <>
                <LogIn size={20} />
                <span>Sign In to Web Portal</span>
              </>
            )}
          </button>
        </form>

        {/* Forgot Password Link */}
        <div style={{ marginTop: '16px', textAlign: 'center', display: 'flex', justifyContent: 'center', gap: '16px' }}>
          <button
            type="button"
            onClick={() => setShowForgotModal(true)}
            style={{
              background: 'none',
              border: 'none',
              color: '#6A4C93',
              fontSize: '0.85rem',
              cursor: 'pointer',
              textDecoration: 'underline',
            }}
          >
            Forgot Password?
          </button>
        </div>

        {/* Create Caregiver Account Link */}
        <div style={{ marginTop: '16px', paddingTop: '14px', borderTop: '1px solid #E2E8F0', textAlign: 'center' }}>
          <span style={{ fontSize: '0.85rem', color: '#64748B' }}>New Caregiver? </span>
          <button
            type="button"
            onClick={() => {
              setRegError('');
              setRegSuccess('');
              setShowRegisterModal(true);
            }}
            style={{
              background: 'none',
              border: 'none',
              color: '#6A4C93',
              fontWeight: '700',
              fontSize: '0.85rem',
              cursor: 'pointer',
              textDecoration: 'underline',
            }}
          >
            Create Caregiver Account
          </button>
        </div>

        {/* (Removed the Demo Credentials section) */}
      </div>

      {/* Forgot Password Modal */}
      {showForgotModal && (
        <div
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'rgba(0,0,0,0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
          }}
          onClick={() => {
            // Close modal if clicking outside
            if (resetMessage.type !== 'success') {
              setShowForgotModal(false);
              setResetMessage({ type: '', text: '' });
            }
          }}
        >
          <div
            className="login-card"
            style={{
              maxWidth: '420px',
              width: '90%',
              position: 'relative',
              margin: '20px',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <button
              type="button"
              onClick={() => {
                setShowForgotModal(false);
                setResetMessage({ type: '', text: '' });
              }}
              style={{
                position: 'absolute',
                top: '12px',
                right: '12px',
                background: 'none',
                border: 'none',
                cursor: 'pointer',
                color: '#6B7280',
              }}
            >
              <X size={20} />
            </button>

            <h3 style={{ marginBottom: '8px', color: '#2D3142' }}>Reset Password</h3>
            <p style={{ fontSize: '0.85rem', color: '#6B7280', marginBottom: '20px' }}>
              Enter your email and a new password.
            </p>

            {resetMessage.text && (
              <div
                style={{
                  padding: '10px 14px',
                  borderRadius: '8px',
                  marginBottom: '16px',
                  background: resetMessage.type === 'success' ? '#D1FAE5' : '#FEE2E2',
                  color: resetMessage.type === 'success' ? '#065F46' : '#B91C1C',
                  fontSize: '0.85rem',
                }}
              >
                {resetMessage.text}
              </div>
            )}

            <form onSubmit={handleResetPassword}>
              <div className="form-group">
                <label>Email</label>
                <div className="form-input-wrapper">
                  <Mail className="form-input-icon" size={18} />
                  <input
                    type="email"
                    placeholder="caregiver@example.com"
                    value={resetEmail}
                    onChange={(e) => setResetEmail(e.target.value)}
                    required
                  />
                </div>
              </div>

              <div className="form-group">
                <label>New Password</label>
                <div className="form-input-wrapper">
                  <Lock className="form-input-icon" size={18} />
                  <input
                    type="password"
                    placeholder="••••••••"
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    required
                    minLength={6}
                  />
                </div>
              </div>

              <div className="form-group">
                <label>Confirm Password</label>
                <div className="form-input-wrapper">
                  <Lock className="form-input-icon" size={18} />
                  <input
                    type="password"
                    placeholder="••••••••"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    required
                  />
                </div>
              </div>

              <button
                type="submit"
                className="btn btn-primary"
                disabled={resetLoading}
                style={{ width: '100%', padding: '12px', marginTop: '8px' }}
              >
                {resetLoading ? 'Resetting...' : 'Reset Password'}
              </button>
            </form>
          </div>
        </div>
      )}

      {/* Create Caregiver Account Modal */}
      {showRegisterModal && (
        <div
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'rgba(0,0,0,0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
            padding: '16px',
          }}
          onClick={() => {
            if (!regLoading && !regSuccess) setShowRegisterModal(false);
          }}
        >
          <div
            className="login-card"
            style={{
              maxWidth: '520px',
              width: '100%',
              maxHeight: '90vh',
              overflowY: 'auto',
              position: 'relative',
              margin: 'auto',
              padding: '28px',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <button
              type="button"
              onClick={() => setShowRegisterModal(false)}
              style={{
                position: 'absolute',
                top: '16px',
                right: '16px',
                background: 'none',
                border: 'none',
                cursor: 'pointer',
                color: '#6B7280',
              }}
            >
              <X size={20} />
            </button>

            <h3 style={{ marginBottom: '4px', color: '#2D3142', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <UserPlus size={22} color="#6A4C93" />
              Create Caregiver Account
            </h3>
            <p style={{ fontSize: '0.85rem', color: '#6B7280', marginBottom: '20px' }}>
              Register as a caregiver to manage patient hardware dispensers & medication schedules. Must be at least 18 years old.
            </p>

            {regError && (
              <div style={{ padding: '10px 14px', borderRadius: '8px', marginBottom: '16px', background: '#FEE2E2', color: '#B91C1C', fontSize: '0.85rem', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <AlertCircle size={16} />
                <span>{regError}</span>
              </div>
            )}

            {regSuccess && (
              <div style={{ padding: '10px 14px', borderRadius: '8px', marginBottom: '16px', background: '#D1FAE5', color: '#065F46', fontSize: '0.85rem', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <CheckCircle2 size={16} />
                <span>{regSuccess}</span>
              </div>
            )}

            <form onSubmit={handleRegisterSubmit}>
              <div className="form-group">
                <label>Full Name *</label>
                <div className="form-input-wrapper">
                  <User className="form-input-icon" size={18} />
                  <input
                    type="text"
                    placeholder="e.g. Sarah Jenkins"
                    value={regName}
                    onChange={(e) => setRegName(e.target.value)}
                    required
                  />
                </div>
              </div>

              <div className="form-group">
                <label>Email Address *</label>
                <div className="form-input-wrapper">
                  <Mail className="form-input-icon" size={18} />
                  <input
                    type="email"
                    placeholder="caregiver@example.com"
                    value={regEmail}
                    onChange={(e) => setRegEmail(e.target.value)}
                    required
                  />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div className="form-group">
                  <label>Password *</label>
                  <div className="form-input-wrapper" style={{ position: 'relative' }}>
                    <Lock className="form-input-icon" size={18} />
                    <input
                      type={showRegPassword ? 'text' : 'password'}
                      placeholder="Min 6 chars"
                      value={regPassword}
                      onChange={(e) => setRegPassword(e.target.value)}
                      required
                      minLength={6}
                      style={{ paddingRight: '40px' }}
                    />
                    <button
                      type="button"
                      onClick={() => setShowRegPassword(!showRegPassword)}
                      style={{
                        position: 'absolute',
                        right: '10px',
                        top: '50%',
                        transform: 'translateY(-50%)',
                        background: 'none',
                        border: 'none',
                        cursor: 'pointer',
                        color: '#6B7280',
                        padding: '4px',
                      }}
                    >
                      {showRegPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                    </button>
                  </div>
                </div>

                <div className="form-group">
                  <label>Confirm Password *</label>
                  <div className="form-input-wrapper" style={{ position: 'relative' }}>
                    <Lock className="form-input-icon" size={18} />
                    <input
                      type={showRegConfirmPassword ? 'text' : 'password'}
                      placeholder="Re-enter password"
                      value={regConfirmPassword}
                      onChange={(e) => setRegConfirmPassword(e.target.value)}
                      required
                      style={{ paddingRight: '40px' }}
                    />
                    <button
                      type="button"
                      onClick={() => setShowRegConfirmPassword(!showRegConfirmPassword)}
                      style={{
                        position: 'absolute',
                        right: '10px',
                        top: '50%',
                        transform: 'translateY(-50%)',
                        background: 'none',
                        border: 'none',
                        cursor: 'pointer',
                        color: '#6B7280',
                        padding: '4px',
                      }}
                    >
                      {showRegConfirmPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                    </button>
                  </div>
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div className="form-group">
                  <label>Phone Number *</label>
                  <div className="form-input-wrapper">
                    <Phone className="form-input-icon" size={18} />
                    <input
                      type="tel"
                      placeholder="e.g. +60 12-345 6789"
                      value={regPhone}
                      onChange={(e) => setRegPhone(e.target.value)}
                      required
                    />
                  </div>
                </div>

                <div className="form-group">
                  <label>Gender *</label>
                  <select
                    value={regGender}
                    onChange={(e) => setRegGender(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '10px',
                      borderRadius: '10px',
                      border: '1px solid #CBD5E1',
                      fontSize: '0.9rem',
                      background: '#F8FAFC'
                    }}
                  >
                    <option value="Male">Male</option>
                    <option value="Female">Female</option>
                  </select>
                </div>
              </div>

              <div className="form-group">
                <label style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span>Date of Birth *</span>
                  <span style={{ fontSize: '0.72rem', color: '#6A4C93', fontWeight: '700' }}>Must be 18+ years old</span>
                </label>
                <div className="form-input-wrapper">
                  <Calendar className="form-input-icon" size={18} />
                  <input
                    type="date"
                    max={get18YearsAgoDate()}
                    value={regDob}
                    onChange={(e) => setRegDob(e.target.value)}
                    required
                  />
                </div>
                <span style={{ fontSize: '0.72rem', color: '#64748B', marginTop: '3px', display: 'block' }}>
                  Restricted to 18 years and above (birth year {new Date().getFullYear() - 18} or earlier).
                </span>
              </div>

              <div className="form-group">
                <label>Address *</label>
                <div className="form-input-wrapper">
                  <MapPin className="form-input-icon" size={18} />
                  <input
                    type="text"
                    placeholder="Enter street / city address"
                    value={regAddress}
                    onChange={(e) => setRegAddress(e.target.value)}
                    required
                  />
                </div>
              </div>

              <button
                type="submit"
                className="btn btn-primary"
                disabled={regLoading}
                style={{ width: '100%', padding: '12px', marginTop: '12px', fontSize: '0.95rem' }}
              >
                {regLoading ? 'Registering Account...' : 'Register Caregiver Account'}
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}