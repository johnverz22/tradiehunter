import axios, { AxiosError } from 'axios';

// NOTE: VITE_API_URL must include the /api suffix,
// e.g. http://localhost:5000/api (see docker-compose.yml and .env.example).
const API_BASE_URL = (
  import.meta.env.VITE_API_URL ?? 'http://localhost:5000/api'
).replace(/\/+$/, '');

const api = axios.create({
  baseURL: API_BASE_URL,
  withCredentials: true, // Send cookies with every request
});

api.interceptors.response.use(
  (response) => response,
  (error: AxiosError) => {
    // If the server returns 401 Unauthorized, the cookie is missing or invalid.
    // We redirect to login to force a new session.
    if (error.response?.status === 401) {
      // Avoid redirect loops if we're already on the login page or checking session
      if (
        !window.location.pathname.startsWith('/login') &&
        !error.config?.url?.includes('/auth/admin-me') &&
        !error.config?.url?.includes('/auth/admin-login')
      ) {
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  }
);

export default api;
