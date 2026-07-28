/* Header.jsx */
import React from 'react';
import { ShieldCheck } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

export default function Header({ title }) {
  const { user } = useAuth();

  return (
    <header className="header">
      <div className="header-title-section">
        <h1>{title}</h1>
      </div>

      <div className="header-actions">
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '6px 12px', background: '#F3E8FF', borderRadius: '20px', color: '#3B1E54', fontSize: '0.8rem', fontWeight: '600' }}>
          <ShieldCheck size={16} color="#6A4C93" />
          <span>Connected to Medical Kit API</span>
        </div>
      </div>
    </header>
  );
}
