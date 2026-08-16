/* Header.jsx */
import React, { useState, useEffect, useRef } from 'react';
import { Bell, AlertTriangle, Pill, CheckCircle2, Info, X, CheckCheck, ShieldAlert, Calendar } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { apiService } from '../services/apiService';

export default function Header({ title }) {
  const { caregiverId } = useAuth();
  const [notifications, setNotifications] = useState([]);
  const [showDropdown, setShowDropdown] = useState(false);
  const [loadingNotifs, setLoadingNotifs] = useState(false);
  const [filterView, setFilterView] = useState('unread'); // 'unread' (like Flutter app default) or 'all'
  const dropdownRef = useRef(null);

  const fetchNotifications = async () => {
    if (!caregiverId) return;
    try {
      const list = await apiService.getCaregiverNotifications(caregiverId);
      if (Array.isArray(list)) {
        // Deduplicate notifications by (title, message)
        const seen = new Set();
        const dedupedList = list.filter((n) => {
          const key = `${(n.title || '').trim().toLowerCase()}_${(n.message || '').trim().toLowerCase()}`;
          if (seen.has(key)) return false;
          seen.add(key);
          return true;
        });
        setNotifications(dedupedList);
      }
    } catch (err) {
      console.error('Error fetching notifications:', err);
    }
  };

  useEffect(() => {
    fetchNotifications();
    const interval = setInterval(fetchNotifications, 15000); // Refresh notifications every 15s
    return () => clearInterval(interval);
  }, [caregiverId]);

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (e) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target)) {
        setShowDropdown(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const unreadNotifications = notifications.filter((n) => !n.is_read);
  const unreadCount = unreadNotifications.length;

  const displayedNotifications = filterView === 'unread'
    ? unreadNotifications
    : notifications;

  const handleMarkAsRead = async (notifId, e) => {
    if (e) e.stopPropagation();
    if (!notifId) return;

    // Send API update
    await apiService.markNotificationRead(notifId);

    // Update local state (marks as read and filters out from unread view)
    setNotifications((prev) =>
      prev.map((n) => ((n.id || n.notification_id) === notifId ? { ...n, is_read: 1 } : n))
    );
  };

  const handleMarkAllRead = async () => {
    if (!caregiverId) return;
    setLoadingNotifs(true);
    await apiService.markAllCaregiverNotificationsRead(caregiverId);
    setNotifications((prev) => prev.map((n) => ({ ...n, is_read: 1 })));
    setLoadingNotifs(false);
  };

  const formatCreatedDateTime = (timeStr) => {
    if (!timeStr) return 'Just now';
    try {
      const d = new Date(timeStr);
      if (isNaN(d.getTime())) return String(timeStr);
      const day = String(d.getDate()).padStart(2, '0');
      const month = String(d.getMonth() + 1).padStart(2, '0');
      const year = d.getFullYear();
      let hours = d.getHours();
      const minutes = String(d.getMinutes()).padStart(2, '0');
      const ampm = hours >= 12 ? 'PM' : 'AM';
      hours = hours % 12;
      hours = hours ? hours : 12;
      return `${day}/${month}/${year} at ${hours}:${minutes} ${ampm}`;
    } catch {
      return String(timeStr);
    }
  };

  return (
    <header className="header">
      <div className="header-title-section">
        <h1>{title}</h1>
      </div>

      <div className="header-actions" ref={dropdownRef} style={{ position: 'relative' }}>
        {/* Notification Bell Button */}
        <button
          className="icon-btn"
          onClick={() => {
            setShowDropdown(!showDropdown);
            if (!showDropdown) fetchNotifications();
          }}
          title="Notifications"
          style={{
            position: 'relative',
            background: showDropdown ? '#F3E8FF' : '#F8FAFC',
            border: '1px solid #CBD5E1',
            borderRadius: '14px',
            padding: '10px 12px',
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            transition: 'all 0.2s ease',
            boxShadow: '0 2px 6px rgba(0,0,0,0.04)',
          }}
        >
          <Bell size={22} color={unreadCount > 0 ? '#6A4C93' : '#64748B'} />
          {unreadCount > 0 && (
            <span
              style={{
                position: 'absolute',
                top: '-4px',
                right: '-4px',
                background: '#EF4444',
                color: 'white',
                fontSize: '0.72rem',
                fontWeight: '800',
                width: '18px',
                height: '18px',
                borderRadius: '50%',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                boxShadow: '0 2px 5px rgba(239, 68, 68, 0.5)',
              }}
            >
              {unreadCount > 9 ? '9+' : unreadCount}
            </span>
          )}
        </button>

        {/* Notifications Dropdown Panel (Styled after Flutter In-App Notification Screen) */}
        {showDropdown && (
          <div
            style={{
              position: 'absolute',
              top: '52px',
              right: 0,
              width: '420px',
              maxWidth: '92vw',
              background: 'white',
              borderRadius: '20px',
              boxShadow: '0 15px 35px -5px rgba(106, 76, 147, 0.2), 0 10px 15px -5px rgba(0,0,0,0.08)',
              border: '1px solid #E2E8F0',
              zIndex: 1000,
              overflow: 'hidden',
            }}
          >
            {/* Dropdown Header */}
            <div
              style={{
                padding: '16px 20px',
                borderBottom: '1px solid #F1F5F9',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                background: 'linear-gradient(135deg, #FAF5FF 0%, #F3E8FF 100%)',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <div style={{ background: '#6A4C93', borderRadius: '10px', padding: '6px', display: 'flex' }}>
                  <Bell size={18} color="white" />
                </div>
                <div>
                  <h4 style={{ margin: 0, fontSize: '1rem', fontWeight: '800', color: '#2D3142' }}>
                    Notifications
                  </h4>
                  <span style={{ fontSize: '0.75rem', color: '#6A4C93', fontWeight: '600' }}>
                    Alerts & Reminders
                  </span>
                </div>
                {unreadCount > 0 && (
                  <span
                    style={{
                      background: '#6A4C93',
                      color: 'white',
                      padding: '2px 8px',
                      borderRadius: '12px',
                      fontSize: '0.72rem',
                      fontWeight: '800',
                    }}
                  >
                    {unreadCount} new
                  </span>
                )}
              </div>

              {unreadCount > 0 && (
                <button
                  onClick={handleMarkAllRead}
                  disabled={loadingNotifs}
                  style={{
                    background: 'none',
                    border: 'none',
                    color: '#6A4C93',
                    fontSize: '0.8rem',
                    fontWeight: '700',
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '4px',
                  }}
                >
                  <CheckCheck size={16} />
                  <span>Read All</span>
                </button>
              )}
            </div>

            {/* Filter Tabs: Unread (Default, matches App) vs All History */}
            <div
              style={{
                display: 'flex',
                background: '#F8FAFC',
                borderBottom: '1px solid #E2E8F0',
                padding: '4px 16px',
                gap: '8px',
              }}
            >
              <button
                onClick={() => setFilterView('unread')}
                style={{
                  flex: 1,
                  padding: '6px 12px',
                  border: 'none',
                  borderRadius: '8px',
                  fontSize: '0.78rem',
                  fontWeight: '700',
                  cursor: 'pointer',
                  background: filterView === 'unread' ? 'white' : 'transparent',
                  color: filterView === 'unread' ? '#6A4C93' : '#64748B',
                  boxShadow: filterView === 'unread' ? '0 1px 3px rgba(0,0,0,0.1)' : 'none',
                  transition: 'all 0.2s ease',
                }}
              >
                Unread Notifications ({unreadCount})
              </button>
              <button
                onClick={() => setFilterView('all')}
                style={{
                  flex: 1,
                  padding: '6px 12px',
                  border: 'none',
                  borderRadius: '8px',
                  fontSize: '0.78rem',
                  fontWeight: '700',
                  cursor: 'pointer',
                  background: filterView === 'all' ? 'white' : 'transparent',
                  color: filterView === 'all' ? '#6A4C93' : '#64748B',
                  boxShadow: filterView === 'all' ? '0 1px 3px rgba(0,0,0,0.1)' : 'none',
                  transition: 'all 0.2s ease',
                }}
              >
                All History ({notifications.length})
              </button>
            </div>

            {/* Notifications Card List */}
            <div style={{ maxHeight: '420px', overflowY: 'auto', padding: '12px', background: '#F8FAFC' }}>
              {displayedNotifications.length === 0 ? (
                <div style={{ padding: '40px 20px', textAlign: 'center', color: '#94A3B8' }}>
                  <Bell size={36} style={{ margin: '0 auto 10px auto', display: 'block', opacity: 0.4 }} />
                  <p style={{ margin: 0, fontSize: '0.9rem', fontWeight: '600', color: '#64748B' }}>
                    {filterView === 'unread' ? 'No unread notifications' : 'No notifications recorded.'}
                  </p>
                  <span style={{ fontSize: '0.78rem', color: '#94A3B8', marginTop: '4px', display: 'block' }}>
                    All caregiver alerts are up to date!
                  </span>
                </div>
              ) : (
                displayedNotifications.map((n) => {
                  const notifId = n.id || n.notification_id;
                  const isUnread = !n.is_read;
                  const notifType = (n.type || '').toUpperCase();
                  const isOutOfStock = notifType === 'OUT_OF_STOCK' || (n.title || '').toLowerCase().includes('out of stock');
                  const isLowStock = notifType === 'LOW_STOCK' || (n.title || '').toLowerCase().includes('low stock');
                  const isStockAlert = isOutOfStock || isLowStock;

                  const iconColor = isOutOfStock ? '#EF4444' : isLowStock ? '#F59E0B' : '#6A4C93';
                  const iconBg = isOutOfStock ? '#FEE2E2' : isLowStock ? '#FEF3C7' : '#F3E8FF';

                  return (
                    <div
                      key={notifId || Math.random()}
                      style={{
                        background: 'white',
                        borderRadius: '16px',
                        padding: '16px',
                        marginBottom: '12px',
                        boxShadow: '0 4px 12px rgba(0,0,0,0.04)',
                        border: isUnread ? '1.5px solid #E9D5FF' : '1px solid #E2E8F0',
                        position: 'relative',
                      }}
                    >
                      {/* Card Top Row: Icon + Title + Created Time + Unread Dot */}
                      <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '12px' }}>
                        <div
                          style={{
                            width: '42px',
                            height: '42px',
                            borderRadius: '12px',
                            background: iconBg,
                            color: iconColor,
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            flexShrink: 0,
                          }}
                        >
                          <AlertTriangle size={22} />
                        </div>

                        <div style={{ flex: 1 }}>
                          <div style={{ fontSize: '1rem', fontWeight: '800', color: '#2D3142', lineHeight: '1.2' }}>
                            {n.title || 'Medicine'}
                          </div>
                          <div style={{ fontSize: '0.74rem', color: iconColor, fontWeight: '700', marginTop: '2px' }}>
                            Created: {formatCreatedDateTime(n.created_at || n.timestamp)}
                          </div>
                        </div>

                        {isUnread && (
                          <div
                            style={{
                              width: '10px',
                              height: '10px',
                              borderRadius: '50%',
                              background: '#EF4444',
                              boxShadow: '0 0 6px rgba(239, 68, 68, 0.6)',
                              flexShrink: 0,
                            }}
                          />
                        )}
                      </div>

                      {/* Message Box */}
                      <div
                        style={{
                          background: '#F8FAFC',
                          borderRadius: '10px',
                          padding: '10px 12px',
                          border: '1px solid #E2E8F0',
                          marginBottom: '12px',
                        }}
                      >
                        <span style={{ fontSize: '0.72rem', fontWeight: '800', color: '#64748B', display: 'block', marginBottom: '2px' }}>
                          Message:
                        </span>
                        <p style={{ margin: 0, fontSize: '0.82rem', color: '#2D3142', lineHeight: '1.4', fontWeight: '500' }}>
                          {n.message}
                        </p>
                      </div>

                      {/* Warning Advice Box for Stock Alerts (Matches Mobile App UI) */}
                      {isStockAlert && (
                        <div
                          style={{
                            background: isOutOfStock ? '#FEF2F2' : '#FFFBEB',
                            border: `1px solid ${isOutOfStock ? '#FCA5A5' : '#FDE68A'}`,
                            borderRadius: '10px',
                            padding: '8px 12px',
                            display: 'flex',
                            alignItems: 'center',
                            gap: '8px',
                            marginBottom: '12px',
                          }}
                        >
                          <ShieldAlert size={16} color={isOutOfStock ? '#DC2626' : '#D97706'} />
                          <span style={{ fontSize: '0.76rem', fontWeight: '700', color: isOutOfStock ? '#991B1B' : '#92400E' }}>
                            {isOutOfStock
                              ? 'Immediate restock needed. No tablet is available for this medicine.'
                              : 'Refill soon. Medicine stock is running low near the minimum pill to refill.'}
                          </span>
                        </div>
                      )}

                      {/* Bottom Action Area: Mark as Read Button (Matching Mobile App Button) */}
                      <div style={{ display: 'flex', justifyContent: 'flex-end', alignItems: 'center', paddingTop: '4px' }}>
                        {isUnread ? (
                          <button
                            type="button"
                            onClick={(e) => handleMarkAsRead(notifId, e)}
                            style={{
                              background: '#6A4C93',
                              color: 'white',
                              border: 'none',
                              borderRadius: '20px',
                              padding: '6px 16px',
                              fontSize: '0.78rem',
                              fontWeight: '700',
                              cursor: 'pointer',
                              display: 'flex',
                              alignItems: 'center',
                              gap: '6px',
                              boxShadow: '0 3px 8px rgba(106, 76, 147, 0.3)',
                              transition: 'all 0.2s ease',
                            }}
                          >
                            <CheckCircle2 size={14} />
                            <span>Mark as Read</span>
                          </button>
                        ) : (
                          <span style={{ fontSize: '0.75rem', color: '#94A3B8', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '4px' }}>
                            <CheckCircle2 size={14} color="#10B981" />
                            Read
                          </span>
                        )}
                      </div>
                    </div>
                  );
                })
              )}
            </div>
          </div>
        )}
      </div>
    </header>
  );
}
