node default { 

  # System packages
  package { [
    'git',
    'curl',
    'apache2',
    'libapache2-mod-wsgi',
    'python-dev',
    'python-virtualenv',
    'python-pip',
    'libxml2-dev',
    'libxslt1-dev',
    'libpq-dev',
    'libgdal-dev',
    'libgdal1-dev',
    'libgdal1h',
    'nodejs',
    'npm',
    'gcc',
  ] :
    ensure => present,
  }

  # Node.js packages
  package { [
    'bower',
    'uglify-js',
    'cssmin',
  ] :
    ensure   => present,
    provider => 'npm',
    require => [ Package['npm'], File['/usr/bin/node'] ],
  }

  file { '/usr/bin/nodejs' :
    ensure => present,
    require => Package['nodejs'],
  }

  file { '/usr/bin/node' :
    ensure  => link,
    target  => '/usr/bin/nodejs',
    require => File['/usr/bin/nodejs'],
  }

  # Create a django application user
  user { 'django': 
    ensure => present,
    comment => 'Django application user',
    managehome => true,
    home => '/home/django',
    shell => '/bin/bash',
  } 

  file { '/home/django':
    ensure => directory,
    mode => '0755',
    require => User['django'],
  }

  # Python pip modules
  python::pip { 
    'Django':
       ensure => '1.7.1',
       owner => 'django',
      require => Python::Virtualenv['/home/django/venv'],
       virtualenv => '/home/django/venv';
    'argparse':
      ensure => '1.2.1',
      owner => 'django',
      require => Python::Virtualenv['/home/django/venv'],
      virtualenv => '/home/django/venv';
    'django-flatblocks':
      ensure => '0.8.0',
      owner => 'django',
      require => Python::Virtualenv['/home/django/venv'],
      virtualenv => '/home/django/venv';
    'django-geojson':
      ensure => '2.6.0',
      owner => 'django',
      require => Python::Virtualenv['/home/django/venv'],
      virtualenv => '/home/django/venv';
    'django-jquery':
      ensure => '1.9.1',
      owner => 'django',
      require => Python::Virtualenv['/home/django/venv'],
      virtualenv => '/home/django/venv';
    'django-leaflet':
      ensure => '0.15.0',
      owner => 'django',
      require => Python::Virtualenv['/home/django/venv'],
      virtualenv => '/home/django/venv';
    'django-pdb':
      ensure => '0.4.0',
      owner => 'django',
      require => Python::Virtualenv['/home/django/venv'],
      virtualenv => '/home/django/venv';
    'django-pipeline':
      ensure => '1.4.2',
      owner => 'django',
      require => Python::Virtualenv['/home/django/venv'],
      virtualenv => '/home/django/venv';
    'django-shapes':
      ensure => '0.2.0',
      owner => 'django',
      require => Python::Virtualenv['/home/django/venv'],
      virtualenv => '/home/django/venv';
    'futures':
      ensure => '2.2.0',
      owner => 'django',
      require => Python::Virtualenv['/home/django/venv'],
      virtualenv => '/home/django/venv';
    'lxml':
      ensure => '3.4.1',
      owner => 'django',
      require => Python::Virtualenv['/home/django/venv'],
      virtualenv => '/home/django/venv';
    'psycopg2':
      ensure => '2.5.4',
      owner => 'django',
      require => Python::Virtualenv['/home/django/venv'],
      virtualenv => '/home/django/venv';
    'six':
      ensure => '1.8.0',
      owner => 'django',
      require => Python::Virtualenv['/home/django/venv'],
      virtualenv => '/home/django/venv';
    'wsgiref':
      ensure => '0.1.2',
      owner => 'django',
      require => Python::Virtualenv['/home/django/venv'],
      virtualenv => '/home/django/venv';
    'GDAL':
      ensure => '1.10.0',
      owner => 'django',
      install_args => '--global-option=build_ext --global-option="-I/usr/include/gdal"',
      require => Python::Virtualenv['/home/django/venv'],
      virtualenv => '/home/django/venv';
  }

  python::virtualenv { '/home/django/venv':
    owner => 'django',
    require => User['django'],
  }

  # Create the django database and user
  class { 'postgresql::server': 
    postgres_password => 'changeme',
  }

  class { 'postgresql::server::postgis': }

  # Add the postgis extensions
  exec { "/usr/bin/psql mn_climate -c 'CREATE EXTENSION postgis;'":
    user => 'postgres',
    unless => "/usr/bin/psql mn_climate -c '\\dx' | grep postgis",
    require => [ Class['Postgresql::Server::Postgis'], Postgresql::Server::Db['mn_climate'] ],
  }

  postgresql::server::db { 'mn_climate' :
    user => 'django',
    password => postgresql_password('django', 'changeme'),
  }
}