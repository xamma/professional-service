# STACKIT IAM-SCIM Integration with Authentik

This repository provides an automated setup for **Authentik** on STACKIT SKE, pre-configured as an Identity Provider (IdP) for STACKIT with both **OIDC** and **SCIM** support.

## Integration Details

### OAuth2 / OIDC

Authentik acts as the OIDC issuer. The provider is configured with the following:

- **Client ID**: `stackit-client`
- **Scopes**: `openid`, `email`, `profile`
- **Custom Claims**: Maps `given_name`, `family_name`, and `preferred_username` from Authentik user attributes.

### SCIM Provisioning

Automated user and group synchronization to STACKIT:

- **Endpoint**: `https://accounts.stackit.cloud/scim/v2/`
- **Authentication**: Uses a long-lived token (required for Authentik Community Edition).
- **Mapping**: Synchronizes both Users and Groups (e.g., `stackit-admins`).

---

## Testing the SCIM Integration

### Scenario 1: User Sync

1. **Create a User**: In the Authentik UI (_Directory -> Users_), create a new test user.
2. **Assign to Application**: Ensure the user is assigned to the `STACKIT` application.
3. **Verify**: Log in to the STACKIT Portal. If the user doesn't appear immediately, go to _Applications -> STACKIT -> Backchannel Providers_ and click **Sync Now**.

### Scenario 2: Group & Role Mapping (RBAC)

1. **Create/Assign Group**: Add your user to the `stackit-admins` group in Authentik.
2. **Map to STACKIT Role**: In the STACKIT Org settings, map this group to the `Owner` or `Admin` role.
3. **Verify Access**:
   - Log in to the STACKIT Portal. The user should have the assigned organization-level permissions.
   - **Remove Group**: Remove the user from the group in Authentik. After sync, the user's permissions in the STACKIT Org will be revoked.

---

## Visual Verification

### 1. Dashboard/Application Overview

![Dashboard](docs/authentik-dashboard-overview.png)
![Application](docs/authentik-application-overview.png)

### 2. User & Group Management

![Groups](docs/authentik-user-management.png)
![Provider](docs/authentik-group-management.png)

### 4. Scim Sync

![Scim](docs/authentik-scim-sync.png)

### 5. Group on STACKIT Side

![Stackit-group-sync](docs/search-for-group-stackit-admins.png)
