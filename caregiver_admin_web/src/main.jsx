//main.jsx
// Import StrictMode tool from React for highlighting potential application problems
import { StrictMode } from 'react'
// Import createRoot API from react-dom/client for mounting React components to the DOM
import { createRoot } from 'react-dom/client'
// Import global CSS style definitions for the application
import './index.css'
// Import the root App component containing the main application logic
import App from './App.jsx'

/**
 * Locate the root DOM element by its ID and render the React application inside it.
 */
createRoot(document.getElementById('root')).render(
  /* Wrap the App component in StrictMode to activate additional development checks */
  <StrictMode>
    <App />
  </StrictMode>,
)