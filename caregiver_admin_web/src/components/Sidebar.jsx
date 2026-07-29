/* Sidebar.jsx */
import React, { useState, useEffect } from 'react';
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
import { apiService, BASE_URL, getPhotoUrl, handleImageError } from '../services/apiService';
import logoSvg from '../assets/medical-smart-kit-logo (1).svg';

export default function Sidebar({ activeTab, setActiveTab, isCollapsed, toggleSidebar }) {
  const { user, caregiverId, logout } = useAuth();
  const [profilePhoto, setProfilePhoto] = useState(user?.profile_photo || null);

  useEffect(() => {
    if (user?.profile_photo) {
      setProfilePhoto(user.profile_photo);
    }
  }, [user]);

  useEffect(() => {
    const fetchProfile = async () => {
      if (caregiverId) {
        try {
          const res = await apiService.getCaregiverProfile(caregiverId);
          if (res && res.success && res.data && res.data.profile_photo) {
            setProfilePhoto(res.data.profile_photo);
          }
        } catch (e) {
          console.error(e);
        }
      }
    };
    fetchProfile();
  }, [caregiverId]);

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

  const rawPhotoPath = profilePhoto || user?.profile_photo;
  const photoUrl = getPhotoUrl(rawPhotoPath);

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
              onError={(e) => handleImageError(e, rawPhotoPath)}
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