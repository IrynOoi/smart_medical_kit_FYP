import React, { useState } from 'react';
import { Mail, Lock, LogIn, AlertCircle, HeartPulse, Sparkles } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

export default function Login() {
  const { login } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');

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

  const fillDemo = (demoEmail, demoPass) => {
    setEmail(demoEmail);
    setPassword(demoPass);
  };

  return (
    <div className="login-container">
      {/* Background Decorative Elements */}
      <div style={{ position: 'absolute', top: '-10%', left: '-10%', width: '400px', height: '400px', borderRadius: '50%', background: 'rgba(255,255,255,0.06)', filter: 'blur(40px)', pointerEvents: 'none' }} />
      <div style={{ position: 'absolute', bottom: '-10%', right: '-10%', width: '400px', height: '400px', borderRadius: '50%', background: 'rgba(255,255,255,0.08)', filter: 'blur(40px)', pointerEvents: 'none' }} />

      <div className="login-card">
        {/* Logo & Header */}
        <div className="login-logo">
          <div className="login-logo-icon">
            <HeartPulse size={36} />
          </div>
          <h2 style={{ fontSize: '1.6rem', color: '#2D3142', marginBottom: '6px' }}>
            Caregiver & Admin Portal
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
            <label>Caregiver / Admin Email</label>
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
            <div className="form-input-wrapper">
              <Lock className="form-input-icon" size={18} />
              <input
                type="password"
                placeholder="••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
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

        {/* Demo Credentials Helper */}
        <div style={{ marginTop: '24px', paddingTop: '20px', borderTop: '1px solid #E2E8F0', textAlign: 'center' }}>
          <div style={{ fontSize: '0.78rem', color: '#6B7280', marginBottom: '8px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }}>
            <Sparkles size={14} color="#6A4C93" />
            <span>Need sample caregiver credentials?</span>
          </div>
          <div style={{ display: 'flex', gap: '8px', justifyContent: 'center' }}>
            <button
              type="button"
              className="btn btn-secondary"
              style={{ fontSize: '0.78rem', padding: '6px 12px' }}
              onClick={() => fillDemo('caregiver@example.com', 'password123')}
            >
              Fill Sample Credentials
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
