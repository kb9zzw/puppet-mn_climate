node default { 

  # Database credentials
  $django_db_user = 'django'
  $django_db_password = 'changeme'

  # ArcGIS Database user (read-only)
  $arcgis_db_user = 'arcgis'
  $arcgis_db_password = 'changeme'

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
  class { 'postgresql::server': }
  class { 'postgresql::server::postgis': }

  # Add the postgis extensions
  exec { "/usr/bin/psql mn_climate -c 'CREATE EXTENSION postgis;'":
    user => 'postgres',
    unless => "/usr/bin/psql mn_climate -c '\\dx' | grep postgis",
    require => [ Class['Postgresql::Server::Postgis'], Postgresql::Server::Db['mn_climate'] ],
  }

  # Create mn_climate database
  postgresql::server::db { 'mn_climate' :
    user => $django_db_user,
    password => postgresql_password($django_db_user, $django_db_password),
  }

  # Add arcgis role (for read-only access)
  postgresql::server::role { $arcgis_db_user :
    password_hash => postgresql_password($arcgis_db_user, $arcgis_db_password),
  }

  # Add hba rule to allow application access to the arcgis role
  postgresql::server::pg_hba_rule { 'allow arcgis to access app database':
    description => "Open up postgresql for arcgis access",
    type => 'host',
    database => 'mn_climate',
    user => $arcgis_db_user,
    address => '0.0.0.0/24',
    auth_method => 'md5',
  }

  # Create static content folder for apache
  file { '/var/www/html/static' :
    ensure => directory,
    owner  => 'django',
    group => 'django',
    mode => '0755',
    require => User['django'],
  }

  # Add apache virtual host
  file { '/etc/apache2/sites-available/000-default.conf' :
    ensure => present,
    owner => 'root',
    group => 'root',
    mode => '0644',
    require => Package['apache2'],
    content => 'WSGIScriptAlias / /home/django/mn_climate/mn_climate/wsgi.py
WSGIPythonPath /home/django/mn_climate:/home/django/venv/lib/python2.7/site-packages

<VirtualHost *:80>
  ServerAdmin webmaster@localhost
  DocumentRoot /var/www/html

  ErrorLog ${APACHE_LOG_DIR}/error.log
  CustomLog ${APACHE_LOG_DIR}/access.log combined

  # Django WSGI connector
  <Directory /home/django/mn_climate/mn_climate>
    <Files wsgi.py>
      Require all granted
    </Files>
  </Directory>

  # Application static files
  Alias /static/ /var/www/html/static/
  <Directory /var/www/html/static>
    Require all granted
  </Directory>

</VirtualHost>',
  } 
}
