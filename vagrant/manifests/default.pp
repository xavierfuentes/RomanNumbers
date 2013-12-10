group { 'puppet': ensure => present }
Exec { path => [ '/bin/', '/sbin/', '/usr/bin/', '/usr/sbin/' ] }
File { owner => 0, group => 0, mode => 0644 }

file { '/var/www':
  ensure => 'directory',
}

class {'apt':
  always_apt_update => true,
}

class { 'nodejs':
  version => 'stable',
}

package { 'less':
  provider => npm
}

Class['::apt::update'] -> Package <|
    title != 'python-software-properties'
and title != 'software-properties-common'
|>

    apt::key { '4F4EA0AAE5267A6C': }

apt::ppa { 'ppa:ondrej/php5-oldstable':
  require => Apt::Key['4F4EA0AAE5267A6C']
}

# class { 'puphpet::dotfiles': }

package { [
    'build-essential',
    # 'curl',
    'git-core',
    'acl',
    'php-pear'
  ]:
  ensure  => 'installed',
}

class { 'nginx': }

nginx::resource::vhost { $vm_host:
  ensure       => present,
  server_name  => [ $vm_host ],
  listen_port  => 80,
  index_files  => undef,
  www_root     => "/var/www/current/web",
  try_files    => '$uri @rewriteapp',
}

nginx::resource::location { "${vm_host}-rewrite":
  ensure              => 'present',
  vhost               => $vm_host,
  location            => '@rewriteapp',
  proxy               => undef,
  try_files           => undef,
  www_root            => undef,
  index_files         => undef,
  location_cfg_prepend=> 'rewrite ^(.*)$ /app.php/$1 last'
}

nginx::resource::location { "${vm_host}-php":
  ensure              => 'present',
  vhost               => $vm_host,
  location            => '~ ^/(app|app_dev|secret)\.php(/|$)',
  proxy               => undef,
  try_files           => undef,
  www_root            => undef,
  index_files         => undef,
  location_cfg_append => {
    'fastcgi_split_path_info'   => '^(.+\.php)(/.+)$',
    'include'                   => 'fastcgi_params',
    'fastcgi_param'             => 'SCRIPT_FILENAME $document_root$fastcgi_script_name',
    'fastcgi_param'             => 'HTTPS off',
    'fastcgi_pass'              => 'unix:/var/run/php5-fpm.sock',
    'fastcgi_buffer_size'       => '512k',
    'fastcgi_buffers'           => '16 512k',
    'fastcgi_busy_buffers_size' => '512k'
  },
  notify              => Class['nginx::service'],
}

class { 'php':
  package             => 'php5-fpm',
  service             => 'php5-fpm',
  service_autorestart => false,
  config_file         => '/etc/php5/fpm/php.ini',
  module_prefix       => ''
}

php::module {
  [
    'php5-mysql',
    'php5-cli',
    'php5-curl',
    'php5-intl',
    'php5-mcrypt',
    'php-apc',
  ]:
  service => 'php5-fpm',
}

service { 'php5-fpm':
  ensure     => running,
  enable     => true,
  hasrestart => true,
  hasstatus  => true,
  require    => Package['php5-fpm'],
}

puphpet::ini { 'php':
  value   => [
    'date.timezone = "Europe/Madrid"',
    # dev only
    'display_errors = on'
  ],
  ini     => '/etc/php5/conf.d/zzz_php.ini',
  notify  => Service['php5-fpm'],
  require => Class['php'],
}

puphpet::ini { 'apc':
  value   => [
    'apc.enabled = 1',
    'apc.shm_segments = 1',
    'apc.ttl = 7200',
    'apc.user_ttl = 7200',
    'apc.num_files_hint = 1024',
    'apc.mmap_file_mask = "/tmp/apc.XXXXXX"',
    'apc.enable_cli = 0',
    'apc.shm_size = "512M"'
  ],
  ini     => '/etc/php5/conf.d/zzz_apc.ini',
  notify  => Service['php5-fpm'],
  require => Class['php'],
}

class { 'composer':
  require => Package['php5-fpm', 'curl'],
}

class { 'mysql::server':
  config_hash   => { 'root_password' => 'root' }
}

mysql::db { $vm_mysql_db:
  grant    => [
    'ALL'
  ],
  user     => $vm_mysql_user,
  password => $vm_mysql_pass,
  host     => 'localhost',
  charset  => 'utf8',
  require  => Class['mysql::server'],
}

if $vm_env == 'dev' {
  class { 'php::devel':
    require => Class['php'],
  }

  class { 'xdebug':
    service => 'nginx',
  }

  puphpet::ini { 'xdebug':
    value   => [
      'xdebug.default_enable = 1',
      'xdebug.remote_connect_back = 1',
      'xdebug.remote_enable = 1',
      'xdebug.remote_handler = "dbgp"',
      'xdebug.max_nesting_level = 1000',
      'xdebug.remote_autostart = 1'
    ],
    ini     => '/etc/php5/conf.d/zzz_xdebug.ini',
    notify  => Service['php5-fpm'],
    require => Class['php'],
  }
}

# upgrade pear
exec {"pear upgrade":
  command => "/usr/bin/pear upgrade",
  require => Package['php-pear'],
  returns => [ 0, '', ' ']
}

# set channels to auto discover
exec { "pear auto_discover" :
  command => "/usr/bin/pear config-set auto_discover 1",
  require => [Package['php-pear']]
}

exec { "pear update-channels" :
  command => "/usr/bin/pear update-channels",
  require => [Package['php-pear']]
}

# install PHPUnit
exec {"pear install phpunit":
  command => "/usr/bin/pear install --alldeps pear.phpunit.de/PHPUnit",
  creates => '/usr/bin/phpunit',
  require => Exec['pear update-channels']
}

# install PHP Code Sniffer
exec {"pear install phpcs":
  command => "/usr/bin/pear install --alldeps PHP_CodeSniffer",
  creates => '/usr/bin/phpcs',
  require => Exec['pear update-channels']
}

# install PHP Mess Detector
exec {"pear install phpmd":
  command => "/usr/bin/pear install --alldeps pear.phpmd.org/PHP_PMD",
  creates => '/usr/bin/phpmd',
  require => Exec['pear update-channels']
}