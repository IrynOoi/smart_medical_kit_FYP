import React, { useState } from 'react';
import { AuthProvider, useAuth } from './context/AuthContext';
import Login from './pages/Login';
import Sidebar from './components/Sidebar';
import Header from './components/Header';
import Dashboard from './pages/Dashboard';
import Patients from './pages/Patients';
import Prescriptions from './pages/Prescriptions';
import AIAnalytics from './pages/AIAnalytics';
import Devices from './pages/Devices';
import './App.css';

function MainApp() {
  const { isAuthenticated, loading } = useAuth();
  const [activeTab, setActiveTab] = useState('dashboard');
  const [isRefreshing, setIsRefreshing] = useState(false);

  if (loading) {
    return (
      <div style={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: '#F5F6FA',
        fontFamily: 'Plus Jakarta Sans, sans-serif'
      }}>
        <div style={{ textAlign: 'center' }}>
          <div style={{
            width: '40px',
            height: '40px',
            border: '4px solid #E2E8F0',
            borderTopColor: '#6A4C93',
            borderRadius: '50%',
            animation: 'spin 1s linear infinite',
            margin: '0 auto 16px auto'
          }} />
          <p style={{ color: '#64748B', fontWeight: '600' }}>Initializing Caregiver Portal...</p>
        </div>
        <style>{`
          @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
          }
        `}</style>
      </div>
    );
  }

  // Auth Guard: Force login if not authenticated
  if (!isAuthenticated) {
    return <Login />;
  }

  const tabTitles = {
    dashboard: 'Caregiver Dashboard Overview',
    patients: 'Patient Directory & Enrolment',
    prescriptions: 'Prescription Schedule & Inventory',
    ai_analytics: 'Hybrid AI Risk Analytics',
    devices: 'Smart Kit Hardware Devices',
  };

  const handleRefresh = () => {
    setIsRefreshing(true);
  };

  return (
    <div className="app-container">
      <Sidebar activeTab={activeTab} setActiveTab={setActiveTab} />
      <div className="main-layout">
        <Header 
          title={tabTitles[activeTab] || 'Caregiver Portal'} 
          onRefresh={handleRefresh}
          isRefreshing={isRefreshing}
        />
        <main className="content-area">
          {activeTab === 'dashboard' && (
            <Dashboard 
              isRefreshing={isRefreshing} 
              onRefreshComplete={() => setIsRefreshing(false)} 
            />
          )}
          {activeTab === 'patients' && (
            <Patients 
              isRefreshing={isRefreshing} 
              onRefreshComplete={() => setIsRefreshing(false)} 
            />
          )}
          {activeTab === 'prescriptions' && (
            <Prescriptions 
              isRefreshing={isRefreshing} 
              onRefreshComplete={() => setIsRefreshing(false)} 
            />
          )}
          {activeTab === 'ai_analytics' && (
            <AIAnalytics 
              isRefreshing={isRefreshing} 
              onRefreshComplete={() => setIsRefreshing(false)} 
            />
          )}
          {activeTab === 'devices' && (
            <Devices 
              isRefreshing={isRefreshing} 
              onRefreshComplete={() => setIsRefreshing(false)} 
            />
          )}
        </main>
      </div>
    </div>
  );
}

export default function App() {
  return (
    <AuthProvider>
      <MainApp />
    </AuthProvider>
  );
}
