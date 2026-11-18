import React from 'react';
import { Link } from 'react-router-dom';
import { Lock } from 'lucide-react';
import { EmptyState } from '../components/EmptyState';
import { PageHeader } from '../components/PageHeader';

// Public route (`/403`, outside the admin shell): the frame's header + empty-state card,
// centred on its own page because there is no sidebar to sit beside.
const Forbidden: React.FC = () => (
  <main className="page page-centered">
    <PageHeader title="Access denied" />
    <section className="card">
      <div className="card-body">
        <EmptyState
          title="You don’t have access to this area"
          icon={<Lock size={26} />}
          action={
            <Link to="/login" className="btn btn-primary">
              Back to sign in
            </Link>
          }
        >
          You don't have permission to view this page. Admin access is required.
        </EmptyState>
      </div>
    </section>
  </main>
);

export default Forbidden;
