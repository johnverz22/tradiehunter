import React, { useCallback, useState } from 'react';
import { useForm } from 'react-hook-form';
import { useNavigate } from 'react-router-dom';
import { jwtDecode } from 'jwt-decode';
import axios from 'axios';
import api from '../../services/api';

// ─── Types ────────────────────────────────────────────────────────────────────

interface JwtPayload {
  role: string;
  sub: string;
  email: string;
}

interface LoginFormValues {
  email: string;
  password: string;
}

interface LoginResponse {
  token: string;
  refreshToken: string;
}

// ─── Component ────────────────────────────────────────────────────────────────
export const AdminLogin: React.FC = () => {
  const { register, handleSubmit, formState: { errors } } = useForm<LoginFormValues>();
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const navigate = useNavigate();

  // ── Shared post-auth handler ───────────────────────────────────────────────
  const handleAuthSuccess = useCallback(
    (token: string, refreshToken: string) => {
      const decoded = jwtDecode<JwtPayload>(token);
      if (decoded.role !== 'Admin') {
        setError('Access denied. Admin role required.');
        return;
      }
      localStorage.setItem('jwt_token', token);
      localStorage.setItem('refresh_token', refreshToken);
      navigate('/dashboard');
    },
    [navigate],
  );

  // ── Email/password submit ──────────────────────────────────────────────────
  const onSubmit = async (data: LoginFormValues) => {
    setIsLoading(true);
    setError(null);
    try {
      const response = await api.post<LoginResponse>('/auth/login', {
        email: data.email,
        password: data.password,
      });
      handleAuthSuccess(response.data.token, response.data.refreshToken);
    } catch (err: unknown) {
      if (axios.isAxiosError<{ message?: string }>(err)) {
        if (err.response) {
          setError(err.response.data?.message ?? 'Failed to login');
        } else if (err.request) {
          // No response — backend unreachable or CORS preflight failed.
          setError(
            `Cannot reach the API at ${err.config?.baseURL ?? 'the configured URL'}. ` +
            'Check the backend is running and CORS allows this origin.',
          );
        } else {
          setError('Failed to login');
        }
      } else {
        setError('Failed to login');
      }
    } finally {
      setIsLoading(false);
    }
  };

  // ── Render ─────────────────────────────────────────────────────────────────
  return (
    <div className="min-h-screen flex items-center justify-center bg-paper px-4 py-12">
      <div className="max-w-md w-full p-8 bg-paper border border-paper-line rounded-lg shadow-lg">
        <div className="text-center mb-8">
          <p
            className="font-bold text-2xl text-brand-700"
            style={{ fontFamily: 'var(--font-display)' }}
          >
            Fixo Admin
          </p>
          <p className="text-ink-soft mt-2 text-sm">Sign in to manage the marketplace</p>
        </div>

        {error && (
          <div
            className="bg-red-100 dark:bg-red-900/30 text-[var(--red)] dark:text-red-400 p-3 rounded mb-4 text-center text-sm border border-red-200 dark:border-red-800"
            role="alert"
          >
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-5" noValidate>
          <div>
            <label htmlFor="email" className="block text-sm font-medium text-ink mb-1.5">
              Email Address
            </label>
            <input
              id="email"
              type="email"
              autoComplete="email"
              aria-invalid={errors.email ? 'true' : 'false'}
              {...register('email', { required: 'Email is required' })}
              className="mt-1 block w-full border border-paper-line rounded bg-paper text-ink shadow-sm px-3 py-2 text-sm placeholder:text-ink-soft/60 focus:border-brand-500 focus:ring-2 focus:ring-brand-500/30 focus:outline-none"
              placeholder="admin@example.com"
            />
            {errors.email && (
              <span className="text-[var(--red)] text-xs mt-1 block" role="alert">{errors.email.message}</span>
            )}
          </div>

          <div>
            <label htmlFor="password" className="block text-sm font-medium text-ink mb-1.5">
              Password
            </label>
            <input
              id="password"
              type="password"
              autoComplete="current-password"
              aria-invalid={errors.password ? 'true' : 'false'}
              {...register('password', { required: 'Password is required' })}
              className="mt-1 block w-full border border-paper-line rounded bg-paper text-ink shadow-sm px-3 py-2 text-sm placeholder:text-ink-soft/60 focus:border-brand-500 focus:ring-2 focus:ring-brand-500/30 focus:outline-none"
              placeholder="••••••••"
            />
            {errors.password && (
              <span className="text-[var(--red)] text-xs mt-1 block" role="alert">{errors.password.message}</span>
            )}
          </div>

          <button
            type="submit"
            disabled={isLoading}
            className="w-full flex justify-center py-2.5 px-4 border border-transparent rounded text-sm font-semibold text-white bg-brand-700 hover:bg-brand-900 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-500 focus-visible:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            {isLoading ? 'Signing in…' : 'Sign In'}
          </button>
        </form>
      </div>
    </div>
  );
};
