FROM rocker/r-ver:4.6.1

# ── Environment ──────────────────────────────────────────────────────────────
ENV S6_VERSION="v2.1.0.2"
ENV STREAMFIND_USER=streamfind
ENV SSH_PASSWORD=streamfind
ENV CS_PASSWORD=streamfind
ENV STREAMFIND_HOST_ROOTS=/host
ENV STREAMFIND_DEBUG_MODE=false

# ── System dependencies ──────────────────────────────────────────────────────
# StreamFind needs C++17, OpenMP, zlib, and Python for its vendored
# OpenBabel/InChI build script.  Remaining deps cover the R package's
# transitive build-time requirements from CRAN packages (magick, xml2,
# curl, openssl, rJava/Java, graphics libraries) and the three container
# services (code-server, SSH, pandoc for Quarto reports).
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential           `# g++ / make / OpenMP for Rcpp + OpenBabel` \
    zlib1g-dev                `# -lz for StreamFind Makevars` \
    python3                   `# vendored OpenBabel build script` \
    libcurl4-openssl-dev      `# curl R package (transitive via httr)` \
    libssl-dev                `# openssl R package (transitive via httr)` \
    libxml2-dev               `# xml2 R package (transitive via kableExtra)` \
    libmagick++-dev           `# magick R package` \
    libpng-dev                `# graphics` \
    libcairo2-dev             `# graphics` \
    libharfbuzz-dev           `# text shaping` \
    libfribidi-dev            `# bidirectional text` \
    libfreetype6-dev          `# font rendering` \
    openjdk-21-jdk            `# Java for rJava / rcdk / MetFrag` \
    openssh-server            `# SSH remote access` \
    pandoc                    `# rmarkdown / Quarto reports` \
    libuv1                    `# fs R package (shinyFiles dependency)` \
    curl                      `# code-server + MetFrag downloads` \
    ca-certificates           `# TLS certs for package downloads` \
    && rm -rf /var/lib/apt/lists/*

# ── s6-overlay (process supervisor) ─────────────────────────────────────────
RUN /rocker_scripts/install_s6init.sh

# ── Container user ───────────────────────────────────────────────────────────
RUN useradd -m -s /bin/bash $STREAMFIND_USER && \
    echo "$STREAMFIND_USER:$SSH_PASSWORD" | chpasswd

# ── code-server (browser VS Code IDE) ────────────────────────────────────────
RUN curl -fsSL https://code-server.dev/install.sh | sh

# ── SSH server setup ─────────────────────────────────────────────────────────
RUN mkdir -p /run/sshd && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# ── Build StreamFind R package ──────────────────────────────────────────────
WORKDIR /build
COPY . .

# DuckDB: link against the CRAN duckdb package's full shared library instead of
# the vendored libduckdb_static.a (which lacks extension-loading symbols).
# The vendored headers are still used for compilation via PKG_CPPFLAGS.
# Also patch vendored OpenBabel for Linux compatibility (conio.h is Windows-only).
RUN sed -i 's|-Lcore/external/duckdb/linux/ -lduckdb|/usr/local/lib/R/site-library/duckdb/libs/duckdb.so|' \
        src/Makevars && \
    sed -i '/#define HAVE_CONIO_H 1/d' \
        src/core/external/openbabel/openbabel-3-2-0/include/openbabel/babelconfig.h && \
    sed -i 's|--cxxflag=-w|--cxxflag=-w --cxxflag=-DCOMPILE_ANSI_ONLY --cflag=-DCOMPILE_ANSI_ONLY|' \
        src/Makevars

# Install R package dependencies (CRAN binaries via RSPM — fast)
RUN R -e 'install.packages("remotes")' && \
    R -e 'install.packages("pak")' && \
    R -e 'remotes::install_deps(".", dependencies = TRUE, upgrade = "never")'

# Install StreamFind from source.
# The Makevars FORCE rule triggers build_openbabel.py automatically (vendored
# under tools/ — a standard R-directory — so it survives the tarball).  The
# script compiles the vendored OpenBabel/InChI sources and produces .a
# archives, which are then linked into StreamFind.so along with DuckDB.
RUN R CMD INSTALL . --preclean --no-test-load

# ── StreamFindData (example data) from GitHub ────────────────────────────────
RUN R -e "pak::pkg_install('ricardo-cunha/StreamFindData', upgrade = FALSE)"

# ── Bundle external tools (MetFrag) ─────────────────────────────────────────
RUN mkdir -p /home/$STREAMFIND_USER/.streamfind/external/metfrag && \
    curl -fL -o /home/$STREAMFIND_USER/.streamfind/external/metfrag/MetFragCL.jar \
    https://github.com/ipb-halle/MetFragRelaunched/releases/download/v2.6.11/MetFragCommandLine-2.6.11.jar && \
    chown -R $STREAMFIND_USER:$STREAMFIND_USER /home/$STREAMFIND_USER/.streamfind

# ── s6 service + cont-init files ─────────────────────────────────────────────
RUN set -ex \
    && mkdir -p /etc/services.d/shiny /etc/services.d/code-server /etc/services.d/ssh /etc/cont-init.d \
    && echo '#!/usr/bin/with-contenv bash' > /etc/services.d/shiny/run \
    && echo 'exec su - streamfind -c "R -e '\''Sys.setenv(BABEL_DATADIR=\"/usr/local/lib/R/site-library/StreamFind/openbabel-3-2-0/data\"); library(StreamFind); run_app(options = list(port = 3838, host = \"0.0.0.0\"))'\''"' >> /etc/services.d/shiny/run \
    && echo '#!/usr/bin/with-contenv bash' > /etc/services.d/code-server/run \
    && echo 'export PASSWORD="${CS_PASSWORD:-streamfind}"' >> /etc/services.d/code-server/run \
    && echo 'SF_WORKSPACE="${STREAMFIND_WORKSPACE:-/host}"' >> /etc/services.d/code-server/run \
    && echo 'first_mount="$(find "$SF_WORKSPACE" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -n 1)"' >> /etc/services.d/code-server/run \
    && echo 'if [ -z "$first_mount" ]; then first_mount="/home/$STREAMFIND_USER"; fi' >> /etc/services.d/code-server/run \
    && echo 'exec su - streamfind -c "code-server \"$first_mount\" --bind-addr 0.0.0.0:8080 --auth password"' >> /etc/services.d/code-server/run \
    && echo '#!/usr/bin/with-contenv bash' > /etc/services.d/ssh/run \
    && echo 'exec /usr/sbin/sshd -D' >> /etc/services.d/ssh/run \
    && echo '#!/usr/bin/with-contenv bash' > /etc/cont-init.d/01_setup_streamfind \
    && echo 'SF_USER="${STREAMFIND_USER:-streamfind}"' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'SF_HOME="/home/$SF_USER/.streamfind"' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'mkdir -p "$SF_HOME/external"' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'chown -R "$SF_USER" "$SF_HOME"' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'mkdir -p /host' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'chown "$SF_USER":"$SF_USER" /host' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then' >> /etc/cont-init.d/01_setup_streamfind \
    && echo '    ssh-keygen -A' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'fi' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'if [ -n "$SSH_PASSWORD" ]; then' >> /etc/cont-init.d/01_setup_streamfind \
    && echo '    echo "$SF_USER:$SSH_PASSWORD" | chpasswd' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'fi' >> /etc/cont-init.d/01_setup_streamfind \
    && chmod +x /etc/services.d/shiny/run /etc/services.d/code-server/run /etc/services.d/ssh/run /etc/cont-init.d/01_setup_streamfind

# ── Cleanup build artifacts ──────────────────────────────────────────────────
RUN rm -rf /build ~/.cache /tmp/*

EXPOSE 3838
EXPOSE 8080
EXPOSE 22

CMD ["/init"]
