#!/bin/bash -x
set -eu

# NOTE: Edit project_name and rpm_name.
copr_project_name=trafficserver-add_cache_lookup_status_header-plugin
rpm_name=trafficserver-add_cache_lookup_status_header-plugin
arch=x86_64

trafficserver_repo_base_url='https://copr-be.cloud.fedoraproject.org/results/hnakamur/apache-traffic-server-6/epel-$releasever-$basearch/'

copr_project_description="a plugin for Apache Traffic Server 6 to add the cache lookup status to the client response header"

copr_project_instructions="\`\`\`
version=\$(rpm -q --qf "%{VERSION}" \$(rpm -q --whatprovides redhat-release))
\`\`\`

\`\`\`
ver=\${version:0:1}
\`\`\`

\`\`\`
sudo curl -sL -o /etc/yum.repos.d/${COPR_USERNAME}-apache-traffic-server-6.repo https://copr.fedoraproject.org/coprs/${COPR_USERNAME}/apache-traffic-server-6/repo/epel-\${ver}/${COPR_USERNAME}-apache-traffic-server-6-epel-\${ver}.repo
\`\`\`

\`\`\`
sudo curl -sL -o /etc/yum.repos.d/${COPR_USERNAME}-${copr_project_name}.repo https://copr.fedoraproject.org/coprs/${COPR_USERNAME}/${copr_project_name}/repo/epel-\${ver}/${COPR_USERNAME}-${copr_project_name}-epel-\${ver}.repo
\`\`\`

\`\`\`
sudo yum -y install ${rpm_name}
\`\`\`"

spec_file=${rpm_name}.spec
mock_chroots="epel-6-${arch} epel-7-${arch}"

usage() {
  cat <<'EOF' 1>&2
Usage: build.sh subcommand

subcommand:
  srpm          build the srpm
  mock          build the rpm locally with mock
  copr          upload the srpm and build the rpm on copr
EOF
}

topdir=`rpm --eval '%{_topdir}'`

download_source_files() {
  source_urls=`rpmspec -P ${topdir}/SPECS/${spec_file} | awk '/^Source[0-9]*:\s*http/ {print $2}'`
  for source_url in $source_urls; do
    source_file=${source_url##*/}
    (cd ${topdir}/SOURCES && if [ ! -f ${source_file} ]; then curl -sLO ${source_url}; fi)
  done
}

build_srpm() {
  download_source_files
  rpmbuild -bs "${topdir}/SPECS/${spec_file}"
  version=`rpmspec -P ${topdir}/SPECS/${spec_file} | awk '$1=="Version:" { print $2 }'`
  release=`rpmspec -P ${topdir}/SPECS/${spec_file} | awk '$1=="Release:" { print $2 }'`
  rpm_version_release=${version}-${release}
  srpm_file=${rpm_name}-${rpm_version_release}.src.rpm
}

create_trafficserver_repo_file() {
  base_chroot=$1

  trafficserver_repo_file=trafficserver-$base_chroot.repo
  if [ ! -f $trafficserver_repo_file ]; then
    # NOTE: Although the repo below has the gpgkey in it, I don't use it
    # since I don't know how to add it to /etc/mock/*.cfg
    cat > ${trafficserver_repo_file} <<EOF
[hnakamur-trafficserver-6]
name=Copr repo for trafficserver owned by hnakamur
baseurl=${trafficserver_repo_base_url}
enabled=1
gpgcheck=0
EOF
  fi
}

create_mock_chroot_cfg() {
  base_chroot=$1
  mock_chroot=$2

  create_trafficserver_repo_file $base_chroot

  # Insert ${scl_repo_file} before closing """ of config_opts['yum.conf']
  # See: http://unix.stackexchange.com/a/193513/135274
  #
  # NOTE: Support of adding repository was added to mock,
  #       so you can use it in the future.
  # See: https://github.com/rpm-software-management/ci-dnf-stack/issues/30
  (cd ${topdir} \
    && echo | sed -e '$d;N;P;/\n"""$/i\
' -e '/\n"""$/r '${trafficserver_repo_file} -e '/\n"""$/a\
' -e D /etc/mock/${base_chroot}.cfg - | sudo sh -c "cat > /etc/mock/${mock_chroot}.cfg")
}

build_rpm_with_mock() {
  build_srpm
  for mock_chroot in $mock_chroots; do
    base_chroot=$mock_chroot
		mock_chroot=${base_chroot}-with-trafficserver
    create_mock_chroot_cfg $base_chroot $mock_chroot
    /usr/bin/mock -r ${mock_chroot} --rebuild ${topdir}/SRPMS/${srpm_file}

    mock_result_dir=/var/lib/mock/${base_chroot}/result
    if [ -n "`find ${mock_result_dir} -maxdepth 1 -name \"${rpm_name}-*${version}-*.${arch}.rpm\" -print -quit`" ]; then
      mkdir -p ${topdir}/RPMS/${arch}
      cp ${mock_result_dir}/${rpm_name}-*${version}-*.${arch}.rpm ${topdir}/RPMS/${arch}/
    fi
    if [ -n "`find ${mock_result_dir} -maxdepth 1 -name \"${rpm_name}-*${version}-*.noarch.rpm\" -print -quit`" ]; then
      mkdir -p ${topdir}/RPMS/noarch
      cp ${mock_result_dir}/${rpm_name}-*${version}-*.noarch.rpm ${topdir}/RPMS/noarch/
    fi
  done
}

build_rpm_on_copr() {
  build_srpm

  # Check the project is already created on copr.
  status=`curl -s -o /dev/null -w "%{http_code}" https://copr.fedoraproject.org/api/coprs/${COPR_USERNAME}/${copr_project_name}/detail/`
  if [ $status = "404" ]; then
    # Create the project on copr.
    # We call copr APIs with curl to work around the InsecurePlatformWarning problem
    # since system python in CentOS 7 is old.
    # I read the source code of https://pypi.python.org/pypi/copr/1.62.1
    # since the API document at https://copr.fedoraproject.org/api/ is old.
    chroot_opts=''
    for mock_chroot in $mock_chroots; do
      chroot_opts="$chroot_opts --data-urlencode ${mock_chroot}=y"
    done
    curl -s -X POST -u "${COPR_LOGIN}:${COPR_TOKEN}" \
      -H "Expect:" \
      --data-urlencode "name=${copr_project_name}" \
      $chroot_opts \
      --data-urlencode "repos=${trafficserver_repo_base_url}" \
      --data-urlencode "description=${copr_project_description}" \
      --data-urlencode "instructions=${copr_project_instructions}" \
      https://copr.fedoraproject.org/api/coprs/${COPR_USERNAME}/new/
  fi
  # Add a new build on copr with uploading a srpm file.
  chroot_opts=''
  for mock_chroot in $mock_chroots; do
    chroot_opts="$chroot_opts -F ${mock_chroot}=y"
  done
  curl -s -X POST -u "${COPR_LOGIN}:${COPR_TOKEN}" \
    -H "Expect:" \
    $chroot_opts \
    -F "pkgs=@${topdir}/SRPMS/${srpm_file};type=application/x-rpm" \
    https://copr.fedoraproject.org/api/coprs/${COPR_USERNAME}/${copr_project_name}/new_build_upload/
}

case "${1:-}" in
srpm)
  build_srpm
  ;;
mock)
  build_rpm_with_mock
  ;;
copr)
  build_rpm_on_copr
  ;;
*)
  usage
  ;;
esac
