# Scripts

Helper scripts for working with STACKIT services.

> **Warning:** These scripts can perform destructive or wide-reaching operations against your STACKIT account (e.g. deleting volumes, overwriting kubeconfigs, writing secrets). Review each script and understand what it does before running it.

## Overview

| Script | Purpose | Required tools |
|--------|---------|----------------|
| [`create-kubeconfig-multiple-projects.sh`](#create-kubeconfig-multiple-projectssh) | Generate kubeconfig entries for every SKE cluster across one or more STACKIT projects. | `stackit`, `yq` |
| [`delete-unused-volumes.sh`](#delete-unused-volumessh) | Delete all STACKIT volumes whose status is `AVAILABLE` (i.e. not attached). | `stackit`, `yq` |
| [`ske-show-versions.sh`](#ske-show-versionssh) | Print overview of SKE cluster Kubernetes versions and nodepool image versions, marking deprecated versions. | `stackit` (>= 0.59.0), `jq`, `awk` |
| [`smctl.sh`](#smctlsh) | Unified CLI wrapper around HashiCorp Vault for the STACKIT Secret Manager (KV v2). | `vault`, `jq` |

---

## `create-kubeconfig-multiple-projects.sh`

Logs in to STACKIT, iterates over a hard-coded list of project IDs, lists all SKE clusters in each project and writes a 60-day kubeconfig for every cluster into a single kubeconfig file.

Edit the `projects=( ... )` array near the bottom of the script before running.

### Flags

- `-f, --filepath <path>` — destination kubeconfig path (default: `$HOME/.kube/config`).
- `-h, --help` — show usage.

### Examples

```bash
# Write to default ~/.kube/config (will prompt before overwriting)
./create-kubeconfig-multiple-projects.sh

# Write to a custom location
./create-kubeconfig-multiple-projects.sh -f ~/.kube/stackit-config
```

---

## `delete-unused-volumes.sh`

Lists all STACKIT volumes in the currently configured project and deletes those with status `AVAILABLE`.

Set `DRY_RUN=1` at the top of the script to preview the deletions without executing them.

### Examples

```bash
# Make sure the right project is selected
stackit config set --project-id <project-id>

# Preview what would be deleted (edit DRY_RUN=1 in the script first)
./delete-unused-volumes.sh

# Actually delete unused volumes
./delete-unused-volumes.sh
```

---

## `ske-show-versions.sh`

Prints a tabular overview of SKE clusters across the project IDs configured in the `projectid` variable. For each nodepool it shows the Kubernetes version and the Flatcar machine image version, annotated with `supported` or the `expirationDate` for deprecated versions. Rows containing any deprecated version are highlighted in red.

The script enforces a minimum STACKIT CLI version (`0.59.0`).

Edit the `projectid="..."` variable (space-separated list) before running.

### Example

```bash
./ske-show-versions.sh
```

Sample output:

```
CLUSTER NAME         SKE VERSION                    NODEPOOL             FLATCAR VERSION                MACHINE TYPE    PROJECT ID
------------         -----------                    --------             ---------------                ------------    ----------
prod-cluster         1.30.4 (supported)             default              4081.2.0 (supported)           c1.4            90bc91eb-...
legacy-cluster       1.27.9 (exp. 2026-05-01)       default              3815.2.5 (exp. 2026-03-15)     c1.2            be20ca97-...

Summary:
Total clusters: 2
```

---

## `smctl.sh`

Wrapper around the `vault` CLI that targets the STACKIT Secret Manager endpoint (`https://prod.sm.eu01.stackit.cloud`) and authenticates with userpass.

### Required environment variables

| Variable | Description |
|----------|-------------|
| `SM_USERNAME` | STACKIT Secret Manager username |
| `SM_PASSWORD` | STACKIT Secret Manager password |
| `SM_ID`       | KV secrets engine mount path (your secret manager instance ID) |

### Commands

| Command | Description |
|---------|-------------|
| `get <vault_path> <key>` | Print the value of a single key. |
| `get <vault_path> all` | Print all keys as `key: value`. |
| `get <vault_path> all-export` | Print all keys as `export key=value` (suitable for `eval`/`source`). |
| `put <vault_path> <key> [value]` | Write/update a key. Reads from stdin if no value is given. Existing keys at the path are preserved. |
| `list` | List all secret paths under the mount. |
| `list <vault_path>` | List all keys at a specific path. |
| `help` | Show usage. |

### Examples

```bash
export SM_USERNAME='my-user'
export SM_PASSWORD='my-pass'
export SM_ID='sm-xxxxxxxx'

# List all paths
./smctl.sh list

# List keys at a path
./smctl.sh list postgresql

# Read a single value
./smctl.sh get postgresql db_password

# Dump everything at a path
./smctl.sh get postgresql all

# Load all secrets at a path into the current shell
eval "$(./smctl.sh get postgresql all-export)"

# Write a value directly
./smctl.sh put postgresql db_password 'super-secret'

# Write a value from a file (e.g. a full .env)
./smctl.sh put terraform secret-env < .env
```
