FROM rocker/r-ver:4.6.1

# ── Environment ──────────────────────────────────────────────────────────────
ENV S6_VERSION="v2.1.0.2"
ENV streamfind_USER=streamfind
ENV SSH_PASSWORD=streamfind
ENV CS_PASSWORD=streamfind
ENV streamfind_HOST_ROOTS=/host
ENV streamfind_DEBUG_MODE=false
ENV STREAMFIND_HOME=/home/streamfind/.streamfind
ENV STREAMFIND_USE_BUNDLED_TOOLS=1
ENV STREAMFIND_OPENBABEL_MODE=bundled
ENV STREAMFIND_DUCKDB_MODE=bundled

# ── System dependencies ──────────────────────────────────────────────────────
# streamfind needs C++17, OpenMP, and zlib for its vendored OpenBabel
# compilation (handled natively by R's Makevars).  Remaining deps cover the R
# package's transitive build-time requirements from CRAN packages (magick,
# xml2, curl, openssl, rJava/Java, graphics libraries) and the three container
# services (code-server, SSH, pandoc for Quarto reports).
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential           `# g++ / make / OpenMP for Rcpp + OpenBabel` \
    zlib1g-dev                `# -lz for streamfind Makevars` \
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
RUN useradd -m -s /bin/bash $streamfind_USER && \
    echo "$streamfind_USER:$SSH_PASSWORD" | chpasswd

# ── code-server (browser VS Code IDE) ────────────────────────────────────────
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Pre-install VS Code extensions for R, Markdown, and YAML support.
# Run as the container user (streamfind) so extensions appear in the browser.
RUN su - streamfind -c "code-server --install-extension REditorSupport.r" \
    && su - streamfind -c "code-server --install-extension yzhang.markdown-all-in-one" \
    && su - streamfind -c "code-server --install-extension redhat.vscode-yaml"

# ── SSH server setup ─────────────────────────────────────────────────────────
RUN mkdir -p /run/sshd && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# ── Build streamfind R package ──────────────────────────────────────────────
WORKDIR /build
COPY . .

# DuckDB: link against the CRAN duckdb package's full shared library instead of
# the vendored libduckdb_static.a (which lacks extension-loading symbols).
# The vendored headers are still used for compilation via PKG_CPPFLAGS.
# Also patch vendored OpenBabel for Linux compatibility (conio.h is Windows-only;
# COMPILE_ANSI_ONLY is needed on some toolchains that lack POSIX-specific APIs).
RUN sed -i 's|core/external/duckdb/lib/linux-x64/libduckdb_static.a|/usr/local/lib/R/site-library/duckdb/libs/duckdb.so|' \
        src/Makevars && \
    sed -i '/#define HAVE_CONIO_H 1/d' \
        src/core/external/openbabel/openbabel-3-2-0/include/openbabel/babelconfig.h && \
    sed -i 's|^include core/external/openbabel/Makevars.openbabel|OB_CXX_DEFINES = -DCOMPILE_ANSI_ONLY\nOB_C_DEFINES = -DCOMPILE_ANSI_ONLY\n\ninclude core/external/openbabel/Makevars.openbabel|' \
        src/Makevars

# Install R package dependencies (CRAN binaries via RSPM — fast)
RUN R -e 'install.packages("remotes")' && \
    R -e 'install.packages("pak")' && \
    R -e 'remotes::install_deps(".", dependencies = TRUE, upgrade = "never")'

# R language server — provides code completion, diagnostics, and hover help in
# the VS Code / code-server R extension.
RUN R -e 'install.packages("languageserver", repos = "https://p3m.dev/cran/latest")'

# Install streamfind from source.  The vendored OpenBabel/InChI sources are
# compiled natively by R's Makevars (via Makevars.openbabel — no Python build
# script needed).  The resulting .a archives are linked into streamfind.so
# along with DuckDB.
RUN R CMD INSTALL . --preclean --no-test-load

# ── streamfindData (example data) from GitHub ────────────────────────────────
RUN R -e "pak::pkg_install('ricardo-cunha/streamfind.data', upgrade = FALSE)"

# ── Bundle external tools (MetFrag) ─────────────────────────────────────────
RUN mkdir -p /home/$streamfind_USER/.streamfind/tools/metfrag && \
    curl -fL -o /home/$streamfind_USER/.streamfind/tools/metfrag/MetFragCL.jar \
    https://github.com/ipb-halle/MetFragRelaunched/releases/download/v2.6.11/MetFragCommandLine-2.6.11.jar && \
    chown -R $streamfind_USER:$streamfind_USER /home/$streamfind_USER/.streamfind

# ── s6 service + cont-init files ─────────────────────────────────────────────
RUN set -ex \
    && mkdir -p /etc/services.d/shiny /etc/services.d/code-server /etc/services.d/ssh /etc/cont-init.d \
    && echo '#!/usr/bin/with-contenv bash' > /etc/services.d/shiny/run \
    && echo 'exec su - streamfind -c "R -e '\''Sys.setenv(STREAMFIND_OPENBABEL_DATA=\"/usr/local/lib/R/site-library/streamfind/extdata/openbabel/data\"); library(streamfind); run_app(options = list(port = 3838, host = \"0.0.0.0\"))'\''"' >> /etc/services.d/shiny/run \
    && echo '#!/usr/bin/with-contenv bash' > /etc/services.d/code-server/run \
    && echo 'SF_WORKSPACE="${streamfind_WORKSPACE:-/host}"' >> /etc/services.d/code-server/run \
    && echo 'first_mount="$(find "$SF_WORKSPACE" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -n 1)"' >> /etc/services.d/code-server/run \
    && echo 'if [ -z "$first_mount" ]; then first_mount="/home/$streamfind_USER"; fi' >> /etc/services.d/code-server/run \
    && echo 'exec su - streamfind -c "code-server \"$first_mount\" --bind-addr 0.0.0.0:8080 --auth password"' >> /etc/services.d/code-server/run \
    && echo '#!/usr/bin/with-contenv bash' > /etc/services.d/ssh/run \
    && echo 'exec /usr/sbin/sshd -D' >> /etc/services.d/ssh/run \
    && echo '#!/usr/bin/with-contenv bash' > /etc/cont-init.d/01_setup_streamfind \
    && echo 'SF_USER="${streamfind_USER:-streamfind}"' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'SF_HOME="/home/$SF_USER/.streamfind"' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'mkdir -p "$SF_HOME/tools"' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'chown -R "$SF_USER" "$SF_HOME"' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'mkdir -p /host' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'chown "$SF_USER":"$SF_USER" /host' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then' >> /etc/cont-init.d/01_setup_streamfind \
    && echo '    ssh-keygen -A' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'fi' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'if [ -n "$SSH_PASSWORD" ]; then' >> /etc/cont-init.d/01_setup_streamfind \
    && echo '    echo "$SF_USER:$SSH_PASSWORD" | chpasswd' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'fi' >> /etc/cont-init.d/01_setup_streamfind \
    && echo '# Write code-server config with the desired password' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'CS_PASS="${CS_PASSWORD:-streamfind}"' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'mkdir -p "/home/$SF_USER/.config/code-server"' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'cat > "/home/$SF_USER/.config/code-server/config.yaml" << EOF' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'bind-addr: 0.0.0.0:8080' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'auth: password' >> /etc/cont-init.d/01_setup_streamfind \
    && echo "password: \$CS_PASS" >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'cert: false' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'EOF' >> /etc/cont-init.d/01_setup_streamfind \
    && echo 'chown -R "$SF_USER:$SF_USER" "/home/$SF_USER/.config"' >> /etc/cont-init.d/01_setup_streamfind \
    && chmod +x /etc/services.d/shiny/run /etc/services.d/code-server/run /etc/services.d/ssh/run /etc/cont-init.d/01_setup_streamfind

# ── Cleanup build artifacts ──────────────────────────────────────────────────
RUN rm -rf /build ~/.cache /tmp/*

EXPOSE 3838
EXPOSE 8080
EXPOSE 22

CMD ["/init"]
