# MeshCentral base image digest is auto-managed by the upstream sync workflow.
# MeshCentral (cant tell which version this is, latest at the time of the commit)
# will try to infer the version from the image digest later on, but it is not guaranteed to be correct.

# DO NOT WRITE ANYTHING to the FROM line, even a comment will break the parsing escaped_base_imagelogic in the script.
FROM ghcr.io/ylianst/meshcentral:1.1.56@sha256:f2ab9604ab75079600387d47eedbc8350dd9349fc54571d69df516d3d4b18389


# Add healthcheck script
COPY scripts/healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

HEALTHCHECK --interval=30s --timeout=10s --retries=3 CMD /healthcheck.sh
