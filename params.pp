class agent_mim::params {

  if $mim_env == 'development' {
    $configfile = 'agent_mim/install_dev.cfg.epp'
    $checkconnectivity = '/paasmount/safeway/integration/mim_agent/checkconnectivity_dev.sh'
    $verifyqueue = '/paasmount/safeway/integration/mim_agent/verifyqueue_dev.sh'
  }
  elsif $mim_env == 'qa' {
    $configfile = 'agent_mim/install_qa.cfg.epp'
    $checkconnectivity = '/paasmount/safeway/integration/mim_agent/checkconnectivity_qa.sh'
    $verifyqueue = '/paasmount/safeway/integration/mim_agent/verifyqueue_qa.sh'	
  }
  elsif $mim_env == 'production' {
    $configfile = 'agent_mim/install_prd.cfg.epp'
    $checkconnectivity = '/paasmount/safeway/integration/mim_agent/checkconnectivity_prd.sh'
    $verifyqueue = '/paasmount/safeway/integration/mim_agent/verifyqueue_prd.sh'
  }
  else {
    fail("mim environment $mim_env is not supported")
  }
}
