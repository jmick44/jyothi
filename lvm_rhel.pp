# Create required volume groups for MIM Agent

class agent_mim::lvm_rhel {
  
include ::lvm

#ID and Group Creation
  
    group {'mim':
      name    => 'mim',
      ensure  => present,
      gid     => '275',
      #members => 'mq0007',
    } ->
  
    user {'mq0007':
      name              => 'mq0007',
      comment           => 'mq0007 id',
      home              => '/home/mq0007',
      shell             => '/bin/bash',
      managehome        => true,
      password          => '$1$DJbEuwnU$si9mTvJqCEhS4BiQFFAsb/',
      expiry            => 'absent',
      password_max_age  => '99999',
      ensure            => present,
      uid               => '275',
      groups            => [mqm, mim],
    } ->

  if $facts['os']['family'] == 'RedHat' {
    case $facts['os']['release']['major'] {
      '6': {$fs = 'ext4'}
      '7': {$fs = 'xfs'}
    }

    notify{"Create MIM agent File system":}

    #/appl/mim FS
    logical_volume {'mim_lv':
      ensure       => present,
      volume_group => 'datavg',
      size         => '1.5G',
    }

   file {'/appl/mim':
      ensure    => directory,
      owner     => 'mq0007',
      group     => 'mim',
      mode      => '0755',
    }

    filesystem {'/dev/mapper/datavg-mim_lv':
      ensure  => present,
      fs_type => $fs,
      require => Logical_volume['mim_lv'],
    }
	
    mount {'/appl/mim':
      ensure  => mounted,
      device  => '/dev/mapper/datavg-mim_lv',
      fstype  => "$fs",
      options => 'noatime,nodiratime',
      require => [
        Filesystem['/dev/mapper/datavg-mim_lv'],
        File['/appl/mim'],
      ],
    }
    exec { 'changemimpermission':
	    command       => "chown mq0007:mim /appl/mim; chmod 755 /appl/mim",
	    group         => root,
	    user          => root,
	    path          => "/usr/bin:/usr/sbin:/bin",
    }

  }
}
