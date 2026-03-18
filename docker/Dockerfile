# MeshCentral base image digest is auto-managed by the upstream sync workflow.
# MeshCentral (cant tell which version this is, latest at the time of the commit)
# will try to infer the version from the image digest later on, but it is not guaranteed to be correct.

# Do not change the FROM line format unless you also update the sync script.
# The updater expects an exact digest-only reference on the next line. This broke many times!
FROM ghcr.io/ylianst/meshcentral@sha256:b2ed98974f85a04d78698ae441931e98d3d536ef5561f5b4e93e2985c1173734


# Add healthcheck script
COPY scripts/healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

HEALTHCHECK --interval=30s --timeout=10s --retries=3 CMD /healthcheck.sh
