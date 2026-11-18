/**
 * Field — label + control + help/error (design system: COMPONENTS.md "Field").
 *
 * Pass a render function so the control gets the ids that link label, help and
 * error text (`aria-describedby`) and `aria-invalid`:
 *
 *   <Field label="Email" error={errors.email?.message}>
 *     {(a11y) => <input className="field" type="email" {...a11y} {...register('email')} />}
 *   </Field>
 *
 * Required is the default; mark optional fields with `optional`.
 */
import React, { useId } from 'react';
import { AlertCircle } from 'lucide-react';

export interface FieldControlProps {
  id: string;
  'aria-describedby'?: string;
  'aria-invalid'?: true;
}

interface FieldProps {
  label: string;
  help?: string;
  error?: string;
  optional?: boolean;
  className?: string;
  children: (control: FieldControlProps) => React.ReactNode;
}

export const Field: React.FC<FieldProps> = ({
  label,
  help,
  error,
  optional,
  className = '',
  children,
}) => {
  const id = useId();
  const helpId = `${id}-help`;
  const errorId = `${id}-error`;
  const describedBy = [error ? errorId : null, help ? helpId : null].filter(Boolean).join(' ');

  return (
    <div className={`form-row ${className}`.trim()}>
      <label className="label" htmlFor={id}>
        {label}
        {optional ? <span className="opt">Optional</span> : null}
      </label>
      {children({
        id,
        'aria-describedby': describedBy || undefined,
        'aria-invalid': error ? true : undefined,
      })}
      {error ? (
        <div className="error" id={errorId}>
          <AlertCircle size={16} aria-hidden="true" className="shrink-0" />
          <span>{error}</span>
        </div>
      ) : null}
      {help ? (
        <div className="help" id={helpId}>
          {help}
        </div>
      ) : null}
    </div>
  );
};
