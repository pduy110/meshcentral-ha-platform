# MeshCentral version pin: latest (cant tell which version this is, but re pin on 2026-03-14, latest at the time)
FROM ghcr.io/ylianst/meshcentral:latest@sha256:b2ed98974f85a04d78698ae441931e98d3d536ef5561f5b4e93e2985c1173734

# Add healthcheck script
COPY scripts/healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

HEALTHCHECK --interval=30s --timeout=10s --retries=3 CMD /healthcheck.sh
