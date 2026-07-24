import React from 'react';
import { 
  LayoutDashboard, 
  Users, 
  Pill, 
  BrainCircuit, 
  Cpu, 
  LogOut, 
  Cross 
} from 'lucide-react';
import { useAuth } from '../context/AuthContext';

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
          <Cross size={24} color="#ffffff" />
        </div>
        <div>
          <div className="sidebar-title">MedKit Caregiver</div>
          <div className="sidebar-subtitle">ADMIN & CAREGIVER PORTAL</div>
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
            <div style={{ fontSize: '0.85rem', fontWeight: '700', color: 'white', whiteSpace: 'nowrap', textOverflow: 'ellipsis', overflow: 'hidden' }}>
              {user?.fullname || 'Caregiver User'}
            </div>
            <div style={{ fontSize: '0.72rem', color: 'rgba(255, 255, 255, 0.7)', textTransform: 'capitalize' }}>
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
