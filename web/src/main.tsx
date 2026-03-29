import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { createHashRouter, RouterProvider } from 'react-router-dom'
import './index.css'
import App from './App.tsx'
import PrivacyPolicy from './pages/PrivacyPolicy.tsx'
import EULA from './pages/EULA.tsx'

const router = createHashRouter([
  { path: '/', element: <App /> },
  { path: '/privacy', element: <PrivacyPolicy /> },
  { path: '/eula', element: <EULA /> },
])

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <RouterProvider router={router} />
  </StrictMode>,
)
