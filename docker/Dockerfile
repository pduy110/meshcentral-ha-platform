# MeshCentral base image digest is auto-managed by the upstream sync workflow.
# MeshCentral (cant tell which version this is, latest at the time of the commit)
# will try to infer the version from the image digest later on, but it is not guaranteed to be correct.

# Do not change the FROM line format unless you also update the sync script.
# The updater expects an exact digest-only reference on the next line. This broke many times!
FROM ghcr.io/ylianst/meshcentral@sha256:f2ab9604ab75079600387d47eedbc8350dd9349fc54571d69df516d3d4b18389


# Add healthcheck script
COPY scripts/healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

HEALTHCHECK --interval=30s --timeout=10s --retries=3 CMD /healthcheck.sh
