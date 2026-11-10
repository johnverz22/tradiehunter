import React, { useCallback, useEffect, useState } from 'react';
import { useForm } from 'react-hook-form';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import api from '../../services/api';
import { useAppName } from '../branding/hooks/useBrandConfig';
import { BrandWordmark } from '../branding/components/BrandWordmark';

// ─── Types ────────────────────────────────────────────────────────────────────

interface LoginFormValues {
  email: string;
  password: string;
}

// ─── Component ────────────────────────────────────────────────────────────────
export const AdminLogin: React.FC = () => {
  const { register, handleSubmit, formState: { errors } } = useForm<LoginFormValues>();
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [capsLock, setCapsLock] = useState(false);
  const navigate = useNavigate();
  const appName = useAppName();

  // The login screen is public, so the tab title can't rely on a session — but
  // the brand name comes from the same public config endpoint.
  useEffect(() => {
    document.title = `${appName} Admin Portal`;
  }, [appName]);

  // ── Shared post-auth handler ───────────────────────────────────────────────
  const handleAuthSuccess = useCallback(
    () => {
      navigate('/dashboard');
    },
    [navigate],
  );

  // ── Email/password submit ──────────────────────────────────────────────────
  const onSubmit = async (data: LoginFormValues) => {
    setIsLoading(true);
    setError(null);
    try {
      await api.post('/auth/admin-login', {
        email: data.email,
        password: data.password,
      });
      handleAuthSuccess();
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
    <div
      className="min-h-dvh flex items-center justify-center bg-paper px-4 py-8 sm:py-12"
      style={{
        paddingTop: 'max(var(--safe-top), 2rem)',
        paddingBottom: 'max(var(--safe-bottom), 2rem)',
      }}
    >
      <div className="max-w-md w-full p-6 sm:p-8 card-pop">
        <div className="text-center mb-6 sm:mb-8">
          <BrandWordmark className="block text-[28px] sm:text-[32px] font-bold text-brand-900" />
          <p className="text-ink-soft mt-2 text-sm">{appName} Admin Portal</p>
          <h1 className="text-[22px] sm:text-[24px] font-bold text-ink mt-6 mb-0">Sign in</h1>
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
              autoFocus
              autoComplete="email"
              aria-invalid={errors.email ? 'true' : 'false'}
              {...register('email', { required: 'Email is required' })}
              className="field"
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
            <div className="relative">
              <input
                id="password"
                type={showPassword ? 'text' : 'password'}
                autoComplete="current-password"
                aria-invalid={errors.password ? 'true' : 'false'}
                aria-describedby={capsLock ? 'caps-lock-hint' : undefined}
                {...register('password', { required: 'Password is required' })}
                onKeyUp={(e) => setCapsLock(e.getModifierState('CapsLock'))}
                onBlur={() => setCapsLock(false)}
                className="field pr-16"
                placeholder="••••••••"
              />
              <button
                type="button"
                aria-controls="password"
                aria-pressed={showPassword}
                onClick={() => setShowPassword((v) => !v)}
                className="absolute inset-y-0 right-0 px-3 text-xs font-semibold text-[var(--brand-500)] hover:underline"
              >
                {showPassword ? 'Hide' : 'Show'}
              </button>
            </div>
            {capsLock && (
              <span id="caps-lock-hint" className="text-[var(--amber-ink)] text-xs mt-1 block" role="status">
                Caps Lock is on.
              </span>
            )}
            {errors.password && (
              <span className="text-[var(--red)] text-xs mt-1 block" role="alert">{errors.password.message}</span>
            )}
          </div>

          <button
            type="submit"
            disabled={isLoading}
            className="btn btn-primary w-full justify-center"
          >
            {isLoading ? 'Signing in…' : 'Sign In'}
          </button>
        </form>
      </div>
    </div>
  );
};
