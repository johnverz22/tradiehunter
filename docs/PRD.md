# Product Requirement Document — Blueprint Marketplace

## Problem statement
Homeowners in New Zealand face challenges finding reliable, high-quality tradies for home projects, renovations, and repairs due to a lack of transparent pricing, limited availability, and concerns about work quality. Tradies struggle with inconsistent work opportunities, payment delays, managing client expectations, and balancing multiple projects. This platform bridges that gap: transparent, efficient, trustworthy, with accountability mechanisms like reviews, secure payments, and reliable scheduling.

## Personas

### 1. Homeowner — Sarah Thompson
Age 38, Marketing Manager, Auckland.
- **Pain points**: struggles to find tradies with transparent pricing; faces delays on urgent repairs; worried about work quality and reliability.
- **Goals**: find qualified tradies quickly, clear pricing/payment terms upfront, high-quality work and accountability.

### 2. Tradie — James Wilson
Age 45, Licensed Electrician, Wellington.
- **Pain points**: difficulty finding consistent work; payment delays; managing multiple projects and client expectations.
- **Goals**: steady job opportunities, get paid on time, build a positive reputation.

### 3. Admin/Staff — Emily Carter
Age 32, Platform Administrator, Christchurch.
- **Pain points**: managing disputes and cancellations; ensuring regulatory compliance; monitoring platform performance.
- **Goals**: smooth, trustworthy platform; fast, fair issue resolution; high user engagement.

## Core feature set (full vision — see docs/MVP-SPEC.md for what ships first)
1. Transparent pricing and job matching
2. Integrated in-app chat
3. Secure payment gateway (upfront deposits, milestone payments)
4. Appointment scheduling with reminders
5. Feedback and rating system
6. Job board for posting project requirements
7. Recommender algorithm (location, availability, skills)
8. Cancellation and refund management
9. Admin dashboard

## Integration notes from initial brainstorming
- **Registration**: email/password, phone, Facebook, or Google, for homeowners, tradies, and admins.
- **Job request workflow**: "Happy Path" and "No Available Tradie" scenarios.
- **Search**: by address, service type, or favorites.
- **Payments**: BNZ API integration for payment detection and cash pool management (V1.1+, see MVP-SPEC).
- **Scenarios**: early cancellations, refunds, incomplete jobs.

## Summary
The app solves pain points for both homeowners and tradies through transparent pricing, integrated chat, secure payments, and a feedback system, with admin tooling to maintain trust. Goal: increase engagement and foster a thriving community of homeowners and tradies in New Zealand.
