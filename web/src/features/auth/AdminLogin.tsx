import React, { useCallback, useEffect, useState } from 'react';
import { useForm } from 'react-hook-form';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import { Lock, Mail } from 'lucide-react';
import api from '../../services/api';
import { useAppName } from '../branding/hooks/useBrandConfig';
import { BrandMark } from '../branding/components/BrandMark';
import { BrandWordmark } from '../branding/components/BrandWordmark';
import { Banner } from '../../components/Banner';
import { Button } from '../../components/Button';
import { Field } from '../../components/Field';

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
  // Kit sign-in layout (frame `login`): brand aside from 1024 px up, form card always.
  return (
    <div className="auth">
      <aside className="hero auth-aside">
        <span className="brand-lockup">
          <BrandMark />
          <BrandWordmark className="wordmark-lg" />
        </span>
        <div className="stack">
          <p className="t-display">Marketplace operations, in one place.</p>
          <p className="t-body c-onHeroSoft">
            Verify tradies, review bank payments and settle disputes.
          </p>
        </div>
        <p className="t-meta c-onHeroSoft">Staff access only.</p>
      </aside>

      <main className="auth-main">
        <div className="auth-card">
          {/* The aside is hidden below 1024 px; keep the brand on the card there. */}
          <span className="brand-lockup auth-card-brand">
            <BrandMark />
            <BrandWordmark className="wordmark-lg" />
          </span>
          <h1 className="t-h1">Sign in</h1>
          <p className="t-body c-soft">Use your staff account to continue.</p>

          {error && (
            <Banner variant="error" title="Sign-in failed">
              {error}
            </Banner>
          )}

          <form onSubmit={handleSubmit(onSubmit)} noValidate>
            <Field label="Email Address" error={errors.email?.message}>
              {(control) => (
                <span className="input-icon">
                  <Mail size={20} aria-hidden="true" />
                  <input
                    {...control}
                    type="email"
                    autoFocus
                    autoComplete="email"
                    {...register('email', { required: 'Email is required' })}
                    className="field"
                    placeholder="admin@example.com"
                  />
                </span>
              )}
            </Field>

            <Field label="Password" error={errors.password?.message}>
              {(control) => (
                <>
                  <span className="input-icon">
                    <Lock size={20} aria-hidden="true" />
                    <input
                      {...control}
                      aria-describedby={
                        [control['aria-describedby'], capsLock ? 'caps-lock-hint' : null]
                          .filter(Boolean)
                          .join(' ') || undefined
                      }
                      type={showPassword ? 'text' : 'password'}
                      autoComplete="current-password"
                      {...register('password', { required: 'Password is required' })}
                      onKeyUp={(e) => setCapsLock(e.getModifierState('CapsLock'))}
                      onBlur={() => setCapsLock(false)}
                      className="field has-trailing"
                      placeholder="••••••••"
                    />
                    <Button
                      kind="ghost"
                      size="sm"
                      className="input-trailing"
                      aria-controls={control.id}
                      aria-pressed={showPassword}
                      onClick={() => setShowPassword((v) => !v)}
                    >
                      {showPassword ? 'Hide' : 'Show'}
                    </Button>
                  </span>
                  {capsLock && (
                    <div id="caps-lock-hint" className="help" role="status">
                      Caps Lock is on.
                    </div>
                  )}
                </>
              )}
            </Field>

            <Button type="submit" kind="accent" size="lg" block loading={isLoading}>
              {isLoading ? 'Signing in…' : 'Sign in'}
            </Button>
          </form>
        </div>
      </main>
    </div>
  );
};
