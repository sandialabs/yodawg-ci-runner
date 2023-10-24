# stable/Dockerfile
#
# Build a Podman container image from the latest
# stable version of Podman on the Fedoras Updates System.
# https://bodhi.fedoraproject.org/updates/?search=podman
# This image can be used to create a secured container
# that runs safely with privileges within the container.
#
FROM registry.fedoraproject.org/fedora:36

# Add local certificates to image.
#
# Add some packages to the image that are generally useful for debugging.
#

# If there are CA certs that must be included, they should be present
# in the certs subdirectory. Placing "no-data.txt" in that
# subdirectory allows the copy command below to work whether certs are
# needed or not.

COPY certs/* /etc/pki/ca-trust/source/anchors/
RUN rm -f /etc/pki/ca-trust/source/no-data.txt

RUN update-ca-trust && \
    pkgmgr="yum" && \
    if command -v dnf &> /dev/null; then pkgmgr="dnf"; fi && \
    if command -v microdnf &> /dev/null; then pkgmgr="microdnf"; fi && \
    $pkgmgr install -y curl wget which procps hostname && \
    $pkgmgr clean all

#
# gitlab-runner stuff
#
RUN curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh > /tmp/script.sh ;\
   chmod +x /tmp/script.sh ; \
   os=centos dist=8 /tmp/script.sh 

RUN dnf -y update ;\
    yum -y install dumb-init git git-lfs gitlab-runner; \
	mkdir -p /etc/gitlab-runner/certs ; \
	chmod -R 700 /etc/gitlab-runner

COPY entrypoint /
RUN chmod +x /entrypoint

#
# podman stuff
# 

# Don't include container-selinux and remove
# directories used by yum that are just taking
# up space.
RUN dnf -y update; rpm --restore shadow-utils 2>/dev/null; \
yum -y install podman fuse-overlayfs --exclude container-selinux; \
rm -rf /var/cache /var/log/dnf* /var/log/yum.*

# the gitlab-runner install addes user gitlab-runner so we don't need to
RUN echo gitlab-runner:10000:5000 > /etc/subuid; \
	echo gitlab-runner:10000:5000 > /etc/subgid;

VOLUME /home/gitlab-runner/.local/share/containers

ADD https://raw.githubusercontent.com/containers/libpod/master/contrib/podmanimage/stable/containers.conf /etc/containers/containers.conf
ADD https://raw.githubusercontent.com/containers/libpod/master/contrib/podmanimage/stable/podman-containers.conf /home/gitlab-runner/.config/containers/containers.conf


# chmod containers.conf and adjust storage.conf to enable Fuse storage.
RUN chmod 644 /etc/containers/containers.conf
RUN mkdir -p /var/lib/shared/overlay-images /var/lib/shared/overlay-layers /var/lib/shared/vfs-images /var/lib/shared/vfs-layers; touch /var/lib/shared/overlay-images/images.lock; touch /var/lib/shared/overlay-layers/layers.lock; touch /var/lib/shared/vfs-images/images.lock; touch /var/lib/shared/vfs-layers/layers.lock

ENV _CONTAINERS_USERNS_CONFIGURED=""

#
# gitlab-runner stuff
#

STOPSIGNAL SIGQUIT
VOLUME ["/etc/gitlab-runner"]
ENTRYPOINT ["/usr/bin/dumb-init", "/entrypoint"]
CMD ["run", "--user=gitlab-runner", "--working-directory=/home/gitlab-runner"]
