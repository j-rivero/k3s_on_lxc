#
# Helm librariy to deal with helm installations
#

HELM_PACKAGES_CONFIG_PATH="${SCRIPT_DIR}/helm"

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
  done < "${HELM_PACKAGES_CONFIG_PATH}/server_packages"
}

_install_helm_packages() {
  VMID=${1}

  configuration=$(_read_helm_configurations_from_file)

  while read -r package_name \
                helm_repo_url \
                version \
                service_to_check
  do
    # assume same rule than other bash files
    namespace=${package_name/-/}

    echo "[ SERVER ] Install ${package_name}"
    hook_exec_file "${VMID}" "install_helm_package.bash" \
      "${package_name}" \
      "${helm_repo_url}" \
      "${version}"
    echo "[ TEST ] Check ${package_name} service"
    hook_exec "${VMID}" "/usr/local/bin/kubectl get services -n ${namespace} | grep -q ${service_to_check}"
    echo "[ --- ]"

    configmap_filename="${package_name}-configmap.yml"
    configmap_path="${HELM_PACKAGES_CONFIG_PATH}/${configmap_filename}"
    remote_configmap_path="/tmp/${configmap_filename}"

    if [[ -f ${configmap_path} ]]; then
      hook_cp "${VMID}" "${configmap_path}" "${remote_configmap_path}"
      hook_exec "${VMID}" "/usr/local/bin/kubectl apply -n ${namespace} -f ${remote_configmap_path}"
    fi
  done <<< ${configuration}
}
