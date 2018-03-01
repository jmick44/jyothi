# Create required users and group for MIM Agent
class agent_mim::pre_install (
  String $mim_env = pick($::puppet_vra_properties.dig('Albertson.Environment'), 'development'),
)

{
 notify{"RHEL 7.2 Pre-requisite for MIM agent pre install":}
 $mim_installdir = '/appl/mim/metastorm'

	if $mim_env == 'development' {

    notify {"DEV install.cfg":}
		$configfile = 'agent_mim/install_dev.cfg.epp'
    $checkconnectivity = '/paasmount/safeway/integration/mim_agent/checkconnectivity_dev.sh'
    $verifyqueue = '/paasmount/safeway/integration/mim_agent/verifyqueue_dev.sh'
    }
	elsif $mim_env == 'qa' {
    notify {"QA install.cfg":}
		$configfile = 'agent_mim/install_qa.cfg.epp'
    $checkconnectivity = '/paasmount/safeway/integration/mim_agent/checkconnectivity_qa.sh'
    $verifyqueue = '/paasmount/safeway/integration/mim_agent/verifyqueue_qa.sh'
  	
   }
	elsif $mim_env == 'production' {
		notify {"PROD install.cfg":}
		$configfile = 'agent_mim/install_prd.cfg.epp'
    $checkconnectivity = '/paasmount/safeway/integration/mim_agent/checkconnectivity_prd.sh'
    $verifyqueue = '/paasmount/safeway/integration/mim_agent/verifyqueue_prd.sh'
	}

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
  } ->    


# Check Queue Connectivity
exec {'checkconnectivity':
    command => "${$checkconnectivity}",
    path    => "/usr/bin:/usr/sbin:/bin",
    user    => 'mq0007',
    group   => 'mim',
    timeout =>  900,
    unless  => 'ls /appl/mim/puppet/connected.chk',
 } 

  #Check MQ Client Condition here - 5.2.2

  file { '/appl/mim/java18':
    ensure => directory,
    owner  => 'mq0007',
    group  => 'mim',
    mode   => '0775',
  } 

  exec { 'extract':
    #extract server-jre-8u51-linux-x64.tar to /appl/mim/java18
    cwd         => '/appl/mim/java18',
    creates     => '/appl/mim/java18/jdk1.8.0_51',
    command     => 'tar -xvf /paasmount/safeway/integration/mim_agent/java/server-jre-8u51-linux-x64.tar',
    path        => "usr/bin:/usr/sbin:/bin:",
    user        => 'mq0007',
    group       => 'mim',
    logoutput   => true,
    require     => [Exec['checkconnectivity'], FIle['/appl/mim/java18'],],
    onlyif      => 'ls /appl/mim/puppet/connected.chk',

  } 

  #setup configuration install file
 
  file { '/appl/mim/puppet/install.cfg':
    ensure  => present,
    content => epp("$configfile"),
    owner   => 'mq0007',
    group   => 'mim',
    require => File['/appl/mim/puppet'],
  } 


  exec { 'install_xminstall.ksh':
    cwd         => "/paasmount/safeway/integration/mim_agent/860/base",
    command     => "/paasmount/safeway/integration/mim_agent/860/base/xminstall.ksh < /appl/mim/puppet/install.cfg > /appl/mim/puppet/mim_install.log",
    user        => "mq0007",
    group       => 'mim',
    timeout     =>  900,
    path     	  => "/usr/bin:/usr/sbin:/bin:",
    onlyif      => 'test -d /appl/mim/java18/jdk1.8.0_51',
    unless      => 'test -d /appl/mim/metastorm ',
    require     => [Exec['extract'], File['/appl/mim/puppet'], File['/appl/mim/puppet/install.cfg'],],
 }

exec { 'verify install run':
    command   => "cd /appl/mim/puppet; grep \\\"VM terminated with rc\\\" /appl/mim/puppet/mim_install.log",
    path      => "/usr/bin:/usr/sbin:/bin",
    logoutput => true,
    unless    => "ls -ltr $mim_installdir",
    require   => Exec['install_xminstall.ksh'],
}

notify{"install fix pack":}

exec { 'install fix pack':
    cwd           => '/appl/mim/metastorm/mim',
    command       => "tar -xvf /paasmount/safeway/integration/mim_agent/860/FP/864/MIM-860004-linux-x86_64.tar",
    path          => "/usr/bin:/usr/sbin:/bin",
    user          => 'mq0007',
    group         => 'mim',
    environment   => ["HOME=/home/mq0007"],
    logoutput	    => true,
    require       => Exec['verify install run'],
    unless        => 'ls -ld /appl/mim/metastorm/mim/860/eccc/tomcat',
  }

#5.5.1/2/3/4/5

# 5.5.2	File permissions
exec { 'Filepermissions':
  command => 'cd /appl; chown mq0007:mim mim; cd /appl/mim; chown -R mq0007:mim metastorm java18; cd /appl/mim/metastorm/mim/860/bin; chmod 775 *; chown root xmofts xmodirmn xmoxmsrv; chmod 6550 xmofts xmodirmn xmoxmsrv; cd /appl/mim/metastorm/mim/860/config',
  path    => "/usr/bin:/usr/sbin:/bin",
  user    => 'root',
  group   => 'root',
  require => Exec['install fix pack']
  #unless  => 'ls',

}

# 5.5.3	Admin Directory

exec{'Admindirectory':
  command => 'mkdir -p /appl/mim/admin/bin; cd /paasmount/safeway/integration/mim_agent/admin/bin; cp MODE.cfg rc.mim ftal.ksh /appl/mim/admin/bin; chmod  750 /appl/mim/admin/bin/rc.mim; chmod 755  /appl/mim/admin/bin/ftal.ksh',
  path    => "/usr/bin:/usr/sbin:/bin",
  user    => 'mq0007',
  group   => 'mim',
  unless  => 'ls /appl/mim/admin/bin | grep rc.mim 2>/dev/null',
  require  => Exec['Filepermissions'],
}

#5.5.4	Profile Setup

exec{'Profileupdate':
  command => 'cd /home/mq0007; cp .bash_profile .bash_profile.bkup;
              cp /paasmount/safeway/integration/mim_agent/.bash_profile .bash_profile; . ./.bash_profile',
  path    => "/usr/bin:/usr/sbin:/bin",
  user    => 'mq0007',
  group   => 'mim',
  unless  => 'ls /home/mq0007/.bash_profile.bkup',
  require  => Exec['Admindirectory'],
}

# 5.5.5	Links

exec{'Createsymlinks':
  command => 'cd /usr/lib; ln -s /appl/mim/metastorm/mim/860/lib/* .; ln -s /opt/mqm/lib/* .;
              cd /usr/lib64; ln -s /appl/mim/metastorm/mim/860/lib/* .; ln -s /opt/mqm/lib64/* .',
  path    => "/usr/bin:/usr/sbin:/bin",
  user    => 'root',
  group   => 'root',
  returns => [0,1],
  unless  => 'ls -la /usr/lib | grep metastorm',
  require  => Exec['Profileupdate'],
}

# 5.5.1 verify queue are setup on X server queue manager

 exec {'verifyqueue':
    command => "${$verifyqueue}",
    path    => "/usr/bin:/usr/sbin:/bin",
    user    => 'mq0007',
    group   => 'mim',
    timeout =>  900,
    require  => Exec['Createsymlinks'],
    unless  => 'ls /appl/mim/puppet/queuefound.chk',
 } 

#configuration of queues in enterprise server for verification if can be pass through MIM file transfer

notify{'start mim services':}
exec {'Start MIM service':
  cwd     => "/appl/mim/admin/bin",
  command => '/appl/mim/admin/bin/rc.mim start all',
  path    => "/usr/bin:/usr/sbin:/bin",
  user    => 'mq0007',
  unless  => 'ps -ef|grep -v grep|grep xmo',
  require => Exec['verifyqueue'],
}

notify{'ftfping verification':}
exec {'ftfping':
  cwd      => "/paasmount/safeway/integration/mim_agent/",
  command  => "/paasmount/safeway/integration/mim_agent/ftfping_check.sh",
  user     => 'mq0007',
  path     => "/usr/bin:/usr/sbin:/bin",
  require  => Exec['Start MIM service'],
}

}

