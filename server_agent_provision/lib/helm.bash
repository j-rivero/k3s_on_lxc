#
# Helm librariy to deal with helm installations
#

_read_helm_configurations_from_file() {
  while read -r package_name \
                helm_repo_url \
                version \
                service_to_check
  do
    if [[ ${package_name} == '#' ]] || [[ ${package_name} == '' ]]; then
      continue
    fi
    echo "$package_name $helm_repo_url $version $service_to_check"
  done < "${HELM_PACKAGES_CONFIG_PATH}"
}

_install_helm_packages() {
  VMID=${1}

  configuration=$(_read_helm_configurations_from_file)

  while read -r package_name \
                helm_repo_url \
                version \
                service_to_check
  do
    echo "[ SERVER ] Install ${package_name}"
    _pct_exec_file "${VMID}" "install_helm_package.bash" \
      "${package_name}" \
      "${helm_repo_url}" \
      "${version}"
    echo "[ TEST ] Check ${package_name} service"
    _pct_exec "${VMID}" "/usr/local/bin/kubectl get services | grep -q ${service_to_check}"
    echo "[ --- ]"
  done <<< ${configuration}
}

