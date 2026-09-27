import axios, { AxiosError } from 'axios';
import type { AxiosRequestConfig } from 'axios';

// NOTE: VITE_API_URL must include the /api suffix,
// e.g. http://localhost:5000/api (see docker-compose.yml and .env.example).
const API_BASE_URL = (
  import.meta.env.VITE_API_URL ?? 'http://localhost:5000/api'
).replace(/\/+$/, '');

const api = axios.create({
  baseURL: API_BASE_URL,
});

interface QueuedRequest {
  resolve: (token: string | null) => void;
  reject: (error: unknown) => void;
}

interface RetryableRequestConfig extends AxiosRequestConfig {
  _retry?: boolean;
}

let isRefreshing = false;
let failedQueue: QueuedRequest[] = [];

const processQueue = (error: unknown, token: string | null = null) => {
  failedQueue.forEach((prom) => {
    if (error) {
      prom.reject(error);
    } else {
      prom.resolve(token);
    }
  });

  failedQueue = [];
};

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('jwt_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

api.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const originalRequest = error.config as RetryableRequestConfig | undefined;

    if (error.response?.status === 401 && originalRequest && !originalRequest._retry) {
      if (isRefreshing) {
        return new Promise<string | null>((resolve, reject) => {
          failedQueue.push({ resolve, reject });
        })
          .then((token) => {
            originalRequest.headers = {
              ...originalRequest.headers,
              Authorization: `Bearer ${token}`,
            };
            return api(originalRequest);
          })
          .catch((err: unknown) => {
            return Promise.reject(err instanceof Error ? err : new Error(String(err)));
          });
      }

      originalRequest._retry = true;
      isRefreshing = true;

      try {
        const refreshToken = localStorage.getItem('refresh_token');
        if (!refreshToken) throw new Error('No refresh token');

        const { data } = await axios.post<{ token: string; refreshToken: string }>(
          `${API_BASE_URL}/auth/refresh`,
          { refreshToken },
        );

        localStorage.setItem('jwt_token', data.token);
        localStorage.setItem('refresh_token', data.refreshToken);

        api.defaults.headers.common['Authorization'] = `Bearer ${data.token}`;
        originalRequest.headers = {
          ...originalRequest.headers,
          Authorization: `Bearer ${data.token}`,
        };

        processQueue(null, data.token);
        return api(originalRequest);
      } catch (refreshError: unknown) {
        processQueue(refreshError, null);
        localStorage.removeItem('jwt_token');
        localStorage.removeItem('refresh_token');
        window.location.href = '/login';
        return Promise.reject(
          refreshError instanceof Error ? refreshError : new Error(String(refreshError)),
        );
      } finally {
        isRefreshing = false;
      }
    }
    return Promise.reject(error);
  },
);

export default api;
