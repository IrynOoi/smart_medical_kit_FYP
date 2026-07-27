/* Sidebar.jsx */
import React from 'react';
import {
  LayoutDashboard,
  Users,
  Pill,
  BrainCircuit,
  Cpu,
  LogOut,
} from 'lucide-react'; // Cross removed – not needed anymore
import { useAuth } from '../context/AuthContext';
import logoSvg from '../assets/medical-smart-kit-logo (1).svg';

export default function Sidebar({ activeTab, setActiveTab }) {
  const { user, logout } = useAuth();

  const navItems = [
    { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
    { id: 'patients', label: 'Patient Directory', icon: Users },
    { id: 'prescriptions', label: 'Prescriptions & Stock', icon: Pill },
    { id: 'ai_analytics', label: 'AI Analytics', icon: BrainCircuit },
    { id: 'devices', label: 'Smart Kit Devices', icon: Cpu },
  ];

  return (
    <aside className="sidebar">
      {/* Brand Header */}
      <div className="sidebar-header">
        <div className="sidebar-logo-icon">
          <img
            src={logoSvg}
            alt="MedSmart Logo"
            style={{ width: '48px', height: '48px', objectFit: 'contain' }}
          />
        </div>
        <div>
          <div className="sidebar-title">MedSmart</div>
          <div className="sidebar-subtitle">CAREGIVER PORTAL</div>
        </div>
      </div>

      {/* Navigation Items */}
      <nav className="sidebar-nav">
        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive = activeTab === item.id;
          return (
            <button
              key={item.id}
              className={`sidebar-item ${isActive ? 'active' : ''}`}
              onClick={() => setActiveTab(item.id)}
            >
              <Icon size={20} />
              <span>{item.label}</span>
            </button>
          );
        })}
      </nav>

      {/* Footer / Caregiver Badge */}
      <div className="sidebar-footer">
        <div className="user-profile-badge">
          <div className="user-avatar">
            {user?.fullname ? user.fullname.charAt(0).toUpperCase() : 'C'}
          </div>
          <div style={{ overflow: 'hidden' }}>
            <div
              style={{
                fontSize: '0.85rem',
                fontWeight: '700',
                color: 'white',
                whiteSpace: 'nowrap',
                textOverflow: 'ellipsis',
                overflow: 'hidden',
              }}
            >
              {user?.fullname || 'Caregiver User'}
            </div>
            <div
              style={{
                fontSize: '0.72rem',
                color: 'rgba(255, 255, 255, 0.7)',
                textTransform: 'capitalize',
              }}
            >
              {user?.role || 'Caregiver'}
            </div>
          </div>
        </div>

        <button
          className="sidebar-item"
          onClick={logout}
          style={{ color: '#FCA5A5' }}
        >
          <LogOut size={18} />
          <span>Sign Out</span>
        </button>
      </div>
    </aside>
  );
}