# -----------------------------------------------------------------------------
# STACKIT ALB Certificate Auto-Updater
# Description: Containerized environment to automate Let's Encrypt DNS-01
#              challenges and update STACKIT Application Load Balancers.
#
# DISCLAIMER:  This implementation is provided as a baseline/Proof of Concept.
#              Depending on your organization's specific requirements, security
#              policies, and special use cases, you may need to adapt and
#              extend the underlying scripts (e.g., adding custom alerting,
#              advanced error handling, or specific secret management integrations).
# -----------------------------------------------------------------------------

FROM mcr.microsoft.com/powershell:7.4-debian-12

# Standard OCI Metadata Labels
LABEL org.opencontainers.image.title="STACKIT ALB Cert Updater"
LABEL org.opencontainers.image.description="Automates ACME certificate renewal for STACKIT Application Load Balancers"
LABEL org.opencontainers.image.authors="Schwarz Digits Cloud GmbH & Co. KG"

# Disable interactive prompts during apt package installation
ENV DEBIAN_FRONTEND=noninteractive


# ==========================================
# PHASE 1: SYSTEM BASE & SECURITY
# ==========================================
# Install core utilities and update existing packages to fix CVEs
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        curl \
        gnupg \
        python3 \
        python3-venv && \
    rm -rf /var/lib/apt/lists/*


# ==========================================
# PHASE 2: STACKIT CLI
# ==========================================
# Add official STACKIT repository and install the CLI
RUN curl -sL https://packages.stackit.cloud/keys/key.gpg | gpg --dearmor -o /usr/share/keyrings/stackit.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/stackit.gpg] https://packages.stackit.cloud/apt/cli stackit main" > /etc/apt/sources.list.d/stackit.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends stackit && \
    rm -rf /var/lib/apt/lists/*


# ==========================================
# PHASE 3: CERTBOT & ACME DNS PLUGIN
# ==========================================
# Set up a PEP-668 compliant Virtual Environment
ENV VIRTUAL_ENV=/opt/certbot-venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
RUN python3 -m venv $VIRTUAL_ENV

# Upgrade the venv's pip and install Certbot with the STACKIT plugin
RUN pip3 install --no-cache-dir --upgrade pip setuptools && \
    pip3 install --no-cache-dir certbot certbot-dns-stackit


# ==========================================
# PHASE 4: APPLICATION WORKSPACE
# ==========================================
WORKDIR /app

# Copy the application scripts into the container
COPY app/ /app/

# Define the default execution command
ENTRYPOINT ["pwsh", "-File", "/app/Main_CertRenew_CLI.ps1"]
