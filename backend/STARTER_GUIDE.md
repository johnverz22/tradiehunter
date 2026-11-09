# Backend Starter Guide

## Setup User Secrets
The JWT Secret and Google Client ID have been externalized. For local development, use `dotnet user-secrets` to configure them:

```bash
cd backend
dotnet user-secrets init
dotnet user-secrets set "Jwt:Secret" "<your-64-byte-secret>"
dotnet user-secrets set "Authentication:Google:ClientId" "<your-google-client-id>"
```
