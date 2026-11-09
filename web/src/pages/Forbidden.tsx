import React from 'react';
import { Link } from 'react-router-dom';
import { ShieldOff } from 'lucide-react';

const Forbidden: React.FC = () => (
  <div className="min-h-screen flex items-center justify-center bg-[var(--paper)]">
    <div className="text-center max-w-sm px-6">
      <ShieldOff
        size={56}
        className="mx-auto mb-6 text-[var(--red)]"
        aria-hidden="true"
      />
      <h1 className="text-2xl font-bold text-[var(--ink)] mb-2">Access Denied</h1>
      <p className="text-[var(--ink-soft)] mb-6">
        You don't have permission to view this page. Admin access is required.
      </p>
      <Link
        to="/login"
        className="btn btn-primary"
      >
        Back to Login
      </Link>
    </div>
  </div>
);

export default Forbidden;
