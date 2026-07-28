/* Sidebar.jsx */
import React from 'react';
import {
  LayoutDashboard,
  Users,
  Pill,
  BrainCircuit,
  Cpu,
  Package,
  UserCircle,
  LogOut,
  ChevronLeft,
  ChevronRight,
} from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { BASE_URL } from '../services/apiService';
import logoSvg from '../assets/medical-smart-kit-logo (1).svg';

export default function Sidebar({ activeTab, setActiveTab, isCollapsed, toggleSidebar }) {
  const { user, logout } = useAuth();

  const navItems = [
    { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
    { id: 'patients', label: 'Patient Directory', icon: Users },
    { id: 'prescriptions', label: 'Prescriptions', icon: Pill },
    { id: 'medications', label: 'Medications Catalog', icon: Package },
    { id: 'ai_analytics', label: 'AI Analytics', icon: BrainCircuit },
    { id: 'devices', label: 'Smart Kit Devices', icon: Cpu },
    { id: 'profile', label: 'My Profile', icon: UserCircle },
  ];

  // Resolve actual name from all possible backend property fields
  const caregiverName = user?.full_name || user?.fullname || user?.name || 'Caregiver User';
  const caregiverRole = user?.role || 'Caregiver';
  const avatarInitial = caregiverName ? caregiverName.charAt(0).toUpperCase() : 'C';

  // Helper to format profile photo URL if available
  const getPhotoUrl = (photoPath) => {
    if (!photoPath) return null;
    if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) return photoPath;
    let cleanPath = photoPath;
    if (cleanPath.includes('/static/profiles/')) {
      const filename = cleanPath.split('/static/profiles/')[1];
      cleanPath = `/static/profiles/${filename}`;
    }
    const base = BASE_URL.endsWith('/') ? BASE_URL.slice(0, -1) : BASE_URL;
    const path = cleanPath.startsWith('/') ? cleanPath : `/${cleanPath}`;
    return `${base}${path}`;
  };

  const photoUrl = getPhotoUrl(user?.profile_photo);

  return (
    <aside className={`sidebar ${isCollapsed ? 'collapsed' : ''}`}>
      {/* Brand Header / Logo Button to toggle expand/collapse */}
      <div 
        className="sidebar-header"
        onClick={toggleSidebar}
        title={isCollapsed ? "Click to expand sidebar" : "Click logo to collapse sidebar"}
        style={{ cursor: 'pointer', userSelect: 'none' }}
      >
        <div className="sidebar-logo-icon">
          <img
            src={logoSvg}
            alt="MedSmart Logo"
            style={{ 
              width: '42px', 
              height: '42px', 
              objectFit: 'contain',
              transition: 'transform 0.2s ease',
            }}
          />
        </div>
        {!isCollapsed && (
          <div className="sidebar-header-text" style={{ flex: 1, minWidth: 0 }}>
            <div className="sidebar-title">MedSmart</div>
            <div className="sidebar-subtitle">CAREGIVER PORTAL</div>
          </div>
        )}
        <div className="sidebar-toggle-btn" style={{ marginLeft: isCollapsed ? '0' : 'auto', display: 'flex', alignItems: 'center', opacity: 0.8 }}>
          {isCollapsed ? <ChevronRight size={18} /> : <ChevronLeft size={18} />}
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
              title={isCollapsed ? item.label : ''}
            >
              <Icon size={20} className="sidebar-item-icon" />
              {!isCollapsed && <span>{item.label}</span>}
            </button>
          );
        })}
      </nav>

      {/* Footer / Caregiver Badge */}
      <div className="sidebar-footer">
        <div 
          className="user-profile-badge" 
          onClick={() => setActiveTab('profile')}
          style={{ cursor: 'pointer', transition: 'all 0.2s ease' }}
          title={isCollapsed ? caregiverName : "View My Profile"}
        >
          {photoUrl ? (
            <img
              src={photoUrl}
              alt="Caregiver"
              style={{
                width: '38px',
                height: '38px',
                borderRadius: '50%',
                objectFit: 'cover',
                border: '2px solid rgba(255, 255, 255, 0.4)',
                flexShrink: 0,
              }}
              onError={(e) => {
                e.target.style.display = 'none';
                if (e.target.nextSibling) e.target.nextSibling.style.display = 'flex';
              }}
            />
          ) : null}
          <div 
            className="user-avatar" 
            style={{ display: photoUrl ? 'none' : 'flex', flexShrink: 0 }}
          >
            {avatarInitial}
          </div>
          {!isCollapsed && (
            <div style={{ overflow: 'hidden', minWidth: 0, flex: 1 }}>
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
                {caregiverName}
              </div>
              <div
                style={{
                  fontSize: '0.72rem',
                  color: 'rgba(255, 255, 255, 0.7)',
                  textTransform: 'capitalize',
                }}
              >
                {caregiverRole}
              </div>
            </div>
          )}
        </div>

        <button
          className="sidebar-item"
          onClick={logout}
          style={{ color: '#FCA5A5' }}
          title={isCollapsed ? "Sign Out" : ""}
        >
          <LogOut size={18} className="sidebar-item-icon" />
          {!isCollapsed && <span>Sign Out</span>}
        </button>
      </div>
    </aside>
  );
}