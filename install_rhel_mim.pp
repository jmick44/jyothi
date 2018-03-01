# Install RHEL MIM Agent
#
class agent_mim::install_rhel_mim{

  require agent_mim::lvm_rhel
  require agent_mim::pre_install
 # require agent_mim::post_install


}
