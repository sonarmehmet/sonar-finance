import React from 'react';
import ReactDOM from 'react-dom/client';
import { HashRouter } from 'react-router-dom';
import '@fontsource-variable/inter';
import './styles/global.css';
import { applyTokens } from './core/tokens';
import { AuthProvider } from './core/auth/AuthProvider';
import { ToastProvider } from './components/Toast';
import { App } from './app/App';
import { Starfield } from './components/Starfield';

applyTokens();

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <Starfield />
    <HashRouter>
      <AuthProvider>
        <ToastProvider><App /></ToastProvider>
      </AuthProvider>
    </HashRouter>
  </React.StrictMode>,
);
