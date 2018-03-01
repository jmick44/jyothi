# Create required users and group for MIM Agent
class agent_mim::pre_install (
  String $mim_env    = pick($::puppet_vra_properties.dig('Albertson.Environment'), 'development'),
  $mim_installdir    = '/appl/mim/metastorm',
  $configfile        = $agent_mim::params::configfile,
  $checkconnectivity = $agent_mim::params::checkconnectivity,
  $verifyqueue       = $agent_mim::params::verifyqueue,
) inherits agent_mim::params {

 # before MIM & Java install use pre check 5.2.2 to check FW connectivity
 #Check FW rules Condition here, timeout 3 nc -v -w 1 mimdev10 10020
 # exec{ 'testfw':
 #  command => "timeout 3 nc -v -w 1 mimdev10 10020 > /tmp/testfw.txt 2>&1",
 #   path      => '/usr/bin:/usr/sbin:/bin:/sbin',
 # } 

 file { '/appl/mim/puppet':
    ensure => directory,
    owner  => 'mq0007',
    group  => 'mim',
    mode   => '0775',
  } 

  # Check Queue Connectivity
  exec { 'checkconnectivity':
    command => "${$checkconnectivity}",
    path    => "/usr/bin:/usr/sbin:/bin",
    user    => 'mq0007',
    group   => 'mim',
    timeout =>  900,
    unless  => 'ls /appl/mim/puppet/connected.chk',
    require => File['/appl/mim/puppet'],
 } 

  #Check MQ Client Condition here - 5.2.2

  file { '/appl/mim/java18':
    ensure => directory,
    owner  => 'mq0007',
    group  => 'mim',
    mode   => '0775',
    require => Exec['checkconnectivity'],
  } 

  #investigate archive module
  #extract server-jre-8u51-linux-x64.tar to /appl/mim/java18
  exec { 'extract':
    cwd         => '/appl/mim/java18',
    creates     => '/appl/mim/java18/jdk1.8.0_51',
    command     => 'tar -xvf /paasmount/safeway/integration/mim_agent/java/server-jre-8u51-linux-x64.tar',
    path        => "usr/bin:/usr/sbin:/bin:",
    user        => 'mq0007',
    group       => 'mim',
    logoutput   => true,
    onlyif      => 'ls /appl/mim/puppet/connected.chk',
    require     => File['/appl/mim/java18'],
  } 

  #setup configuration install file
  file { '/appl/mim/puppet/install.cfg':
    ensure  => present,
    content => epp("$configfile"),
    owner   => 'mq0007',
    group   => 'mim',
    require => Exec['extract'],
  } 

  exec { 'install_xminstall.ksh':
    cwd         => "/paasmount/safeway/integration/mim_agent/860/base",
    command     => "/paasmount/safeway/integration/mim_agent/860/base/xminstall.ksh < /appl/mim/puppet/install.cfg > /appl/mim/puppet/mim_install.log",
    path        => "/usr/bin:/usr/sbin:/bin:",
    unless      => 'test -d /appl/mim/metastorm',
    user        => "mq0007",
    group       => 'mim',
    timeout     => 900,
    onlyif      => 'test -d /appl/mim/java18/jdk1.8.0_51',
    require     => File['/appl/mim/puppet/install.cfg'],
  }

  exec { 'verify install run':
    command   => "cd /appl/mim/puppet; grep \\\"VM terminated with rc\\\" /appl/mim/puppet/mim_install.log",
    path      => "/usr/bin:/usr/sbin:/bin",
    unless    => "ls -ltr $mim_installdir",
    logoutput => true,
    require   => Exec['install_xminstall.ksh'],
  }

  #notify{ "install fix pack": }

  exec { 'install fix pack':
    cwd           => '/appl/mim/metastorm/mim',
    command       => "tar -xvf /paasmount/safeway/integration/mim_agent/860/FP/864/MIM-860004-linux-x86_64.tar",
    path          => "/usr/bin:/usr/sbin:/bin",
    unless        => 'ls -ld /appl/mim/metastorm/mim/860/eccc/tomcat',
    user          => 'mq0007',
    group         => 'mim',
    environment   => ["HOME=/home/mq0007"],
    logoutput	    => true,
    require       => Exec['verify install run'],
  }

  #5.5.1/2/3/4/5

  #TODO: Add in idempotency
  #TODO: Look into using a file resource type 
  # 5.5.2	File permissions
  exec { 'Filepermissions':
    command => 'cd /appl; chown mq0007:mim mim; cd /appl/mim; chown -R mq0007:mim metastorm java18; cd /appl/mim/metastorm/mim/860/bin; chmod 775 *; chown root xmofts xmodirmn xmoxmsrv; chmod 6550 xmofts xmodirmn xmoxmsrv; cd /appl/mim/metastorm/mim/860/config',
    path    => "/usr/bin:/usr/sbin:/bin",
    user    => 'root',
    group   => 'root',
    require => Exec['install fix pack']
    #unless  => 'ls',
  }

  #TODO: Look into using a file resource type
  # 5.5.3	Admin Directory
  exec { 'Admindirectory':
    command => 'mkdir -p /appl/mim/admin/bin; cd /paasmount/safeway/integration/mim_agent/admin/bin; cp MODE.cfg rc.mim ftal.ksh /appl/mim/admin/bin; chmod  750 /appl/mim/admin/bin/rc.mim; chmod 755  /appl/mim/admin/bin/ftal.ksh',
    path    => "/usr/bin:/usr/sbin:/bin",
    unless  => 'ls /appl/mim/admin/bin | grep rc.mim 2>/dev/null',
    user    => 'mq0007',
    group   => 'mim',
    require  => Exec['Filepermissions'],
  }

  #Revist to see if we can use file resource types
  #5.5.4	Profile Setup
  exec{'Profileupdate':
    command => 'cd /home/mq0007; cp .bash_profile .bash_profile.bkup;
              cp /paasmount/safeway/integration/mim_agent/.bash_profile .bash_profile; . ./.bash_profile',
    path    => "/usr/bin:/usr/sbin:/bin",
    unless  => 'ls /home/mq0007/.bash_profile.bkup',
    user    => 'mq0007',
    group   => 'mim',
    require => Exec['Admindirectory'],
  }

  #Use file resource type to create symlinks
  # 5.5.5	Links
  exec{'Createsymlinks':
    command => 'cd /usr/lib; ln -s /appl/mim/metastorm/mim/860/lib/* .; ln -s /opt/mqm/lib/* .;
              cd /usr/lib64; ln -s /appl/mim/metastorm/mim/860/lib/* .; ln -s /opt/mqm/lib64/* .',
    path    => "/usr/bin:/usr/sbin:/bin",
    unless  => 'ls -la /usr/lib | grep metastorm',
    user    => 'root',
    group   => 'root',
    returns => [0,1],
    require  => Exec['Profileupdate'],
  }

  # 5.5.1 verify queue are setup on X server queue manager
  exec {'verifyqueue':
    command => "${$verifyqueue}",
    path    => "/usr/bin:/usr/sbin:/bin",
    unless  => 'ls /appl/mim/puppet/queuefound.chk',
    user    => 'mq0007',
    group   => 'mim',
    timeout =>  900,
    require  => Exec['Createsymlinks'],
  } 

  #Can the service resource type be used here?
  #configuration of queues in enterprise server for verification if can be pass through MIM file transfer
  #notify{'start mim services':}
  exec {'Start MIM service':
    cwd     => "/appl/mim/admin/bin",
    command => '/appl/mim/admin/bin/rc.mim start all',
    path    => "/usr/bin:/usr/sbin:/bin",
    user    => 'mq0007',
    unless  => 'ps -ef|grep -v grep|grep xmo',
    require => Exec['verifyqueue'],
  }

  #Can the service resource type be used here?
  #notify{'ftfping verification':}
  exec {'ftfping':
    cwd      => "/paasmount/safeway/integration/mim_agent/",
    command  => "/paasmount/safeway/integration/mim_agent/ftfping_check.sh",
    user     => 'mq0007',
    path     => "/usr/bin:/usr/sbin:/bin",
    require  => Exec['Start MIM service'],
  }
}
