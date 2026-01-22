# WhisperSwift Development Container
#
# IMPORTANT LIMITATIONS:
# This container is for auxiliary development tasks only:
# - Code linting (SwiftLint)
# - Code formatting (SwiftFormat)
# - Documentation generation
# - CI/CD tasks
# - Git operations
#
# Full macOS development (building, running, debugging the app) requires
# a native macOS environment with Xcode installed.

FROM swift:5.10-jammy

LABEL maintainer="WhisperSwift Team"
LABEL description="Development container for WhisperSwift auxiliary tasks"

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build essentials
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    # Development tools
    curl \
    wget \
    git \
    vim \
    nano \
    # Utilities
    jq \
    tree \
    htop \
    unzip \
    zip \
    # Python for scripting
    python3 \
    python3-pip \
    # Locales
    locales \
    && rm -rf /var/lib/apt/lists/*

# Set up locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Install SwiftLint
# Note: We build from source since pre-built binaries are macOS-only
ARG SWIFTLINT_VERSION=0.54.0
RUN git clone --branch ${SWIFTLINT_VERSION} --depth 1 https://github.com/realm/SwiftLint.git /tmp/swiftlint \
    && cd /tmp/swiftlint \
    && swift build -c release \
    && cp .build/release/swiftlint /usr/local/bin/ \
    && rm -rf /tmp/swiftlint

# Install SwiftFormat
ARG SWIFTFORMAT_VERSION=0.53.0
RUN git clone --branch ${SWIFTFORMAT_VERSION} --depth 1 https://github.com/nicklockwood/SwiftFormat.git /tmp/swiftformat \
    && cd /tmp/swiftformat \
    && swift build -c release \
    && cp .build/release/swiftformat /usr/local/bin/ \
    && rm -rf /tmp/swiftformat

# Install pre-commit
RUN pip3 install --no-cache-dir pre-commit

# Install markdownlint-cli for documentation linting
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g markdownlint-cli \
    && rm -rf /var/lib/apt/lists/*

# Create workspace directory
WORKDIR /workspace

# Verify installations
RUN swift --version && \
    swiftlint version && \
    swiftformat --version && \
    pre-commit --version && \
    markdownlint --version

# Default command
CMD ["bash"]
