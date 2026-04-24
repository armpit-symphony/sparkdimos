#!/usr/bin/env bash
# LIMA Module Install (generic)
# Converts any Dockerfile into a LIMA module container
#
# Usage in Dockerfile:
#   RUN --mount=from=ghcr.io/dimensionalos/ros-python:dev,source=/app,target=/tmp/d \
#       bash /tmp/d/docker/python/module-install.sh /tmp/d
#   ENTRYPOINT ["/lima/entrypoint.sh"]

set -euo pipefail

SRC="${1:-/tmp/d}"

# ---- Copy source into image (skip if already at /lima/source) ----
if [ "${SRC}" != "/lima/source" ]; then
    mkdir -p /lima/source
    cp -r "${SRC}/lima" "${SRC}/pyproject.toml" /lima/source/
    [ -f "${SRC}/README.md" ] && cp "${SRC}/README.md" /lima/source/ || true
fi

# ---- Find Python + Pip (conda env > venv > uv > system) ----
PYTHON=""
PIP=""

# 1. Check for Conda environment
if [ -z "$PYTHON" ] && command -v conda >/dev/null 2>&1; then
    LIMA_CONDA_ENV="${LIMA_CONDA_ENV:-app}"
    if conda env list 2>/dev/null | awk '{print $1}' | grep -qx "${LIMA_CONDA_ENV}"; then
        PYTHON="conda run --no-capture-output -n ${LIMA_CONDA_ENV} python"
        PIP="conda run -n ${LIMA_CONDA_ENV} pip"
        echo "Using Conda env: ${LIMA_CONDA_ENV}"
    fi
fi

# 2. Check for venv (including uv's .venv)
if [ -z "$PYTHON" ]; then
    for v in /opt/venv /app/venv /venv /app/.venv /.venv; do
        if [ -x "${v}/bin/python" ] && [ -x "${v}/bin/pip" ]; then
            PYTHON="${v}/bin/python"
            PIP="${v}/bin/pip"
            echo "Using venv: ${v}"
            break
        fi
    done
fi

# 3. Check for uv (uses system python but manages deps)
if [ -z "$PYTHON" ] && command -v uv >/dev/null 2>&1; then
    PYTHON="python"
    PIP="uv pip"
    echo "Using uv"
fi

# 4. Fallback to system Python
if [ -z "$PYTHON" ]; then
    PYTHON="python"
    PIP="pip"
    echo "Using system Python"
fi

# ---- Install LIMA (deps from pyproject.toml[docker]) ----
${PIP} install --no-cache-dir -e "/lima/source[docker]"

# ---- Create entrypoint ----
cat > /lima/entrypoint.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
export PYTHONPATH="/lima/source:/lima/third_party:\${PYTHONPATH:-}"
exec ${PYTHON} -m lima.core.docker_runner run "\$@"
EOF

chmod +x /lima/entrypoint.sh
echo "LIMA module installed. Use: ENTRYPOINT [\"/lima/entrypoint.sh\"]"
