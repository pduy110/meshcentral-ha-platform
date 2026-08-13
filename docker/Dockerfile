# MeshCentral base image digest is auto-managed by the upstream sync workflow.
# MeshCentral (cant tell which version this is, latest at the time of the commit)
# will try to infer the version from the image digest later on, but it is not guaranteed to be correct.

# Do not change the FROM line format unless you also update the sync script.
# The updater expects an exact digest-only reference on the next line. This broke many times!
FROM ghcr.io/ylianst/meshcentral@sha256:45873f56b1221cf4c33a65c6a9a8c2ae8b503bd4f605a19f8b1527fbb80a7b6c


# Add healthcheck script
COPY scripts/healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

HEALTHCHECK --interval=30s --timeout=10s --retries=3 CMD /healthcheck.sh
