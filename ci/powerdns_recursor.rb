# (C) Datadog, Inc. 2010-2016
# All rights reserved
# Licensed under Simplified BSD License (see LICENSE)

require './ci/common'

def powerdns_recursor_version
  ENV['FLAVOR_VERSION'] || '3.7.3'
end

def powerdns_recursor_rootdir
  "#{ENV['INTEGRATIONS_DIR']}/powerdns_recursor_#{powerdns_recursor_version}"
end

def boost_version
  '1_55_0'
end

namespace :ci do
  namespace :powerdns_recursor do |flavor|
    task before_install: ['ci:common:before_install']

    task install: ['ci:common:install'] do
      unless Dir.exist? File.expand_path(File.join(powerdns_recursor_rootdir), 'pdns_recursor')
        # Downloads
        # https://downloads.powerdns.com/releases/pdns-recursor-{powerdns_recursor_version}.tar.bz2
        # http://downloads.sourceforge.net/project/boost/boost/1.55.0/boost_1_55_0.tar.bz2
        url = if powerdns_recursor_version == '3.7.3'
                'https://s3.amazonaws.com/dd-agent-tarball-mirror'
              else
                'https://downloads.powerdns.com/releases'
              end
        sh %(curl -s -L\
             -o $VOLATILE_DIR/powerdns_recursor-#{powerdns_recursor_version}.tar.bz2\
              #{url}/pdns-recursor-#{powerdns_recursor_version}.tar.bz2)
        sh %(mkdir -p #{powerdns_recursor_rootdir})
        sh %(tar xf $VOLATILE_DIR/powerdns_recursor-#{powerdns_recursor_version}.tar.bz2\
             -C #{powerdns_recursor_rootdir} --strip-components=1)
        sh %(curl -s -L\
           -o $VOLATILE_DIR/boost_#{boost_version}.tar.bz2\
            https://s3.amazonaws.com/dd-agent-tarball-mirror/boost_#{boost_version}.tar.bz2)
        sh %(tar xf $VOLATILE_DIR/boost_#{boost_version}.tar.bz2\
             -C #{powerdns_recursor_rootdir} --strip-components=1)
        ENV['CPATH'] = powerdns_recursor_rootdir
        sh %(cd #{powerdns_recursor_rootdir} && ./configure)
        sh %(cd #{powerdns_recursor_rootdir} && make || echo "make didn't succeed")
      end
    end

    task before_script: ['ci:common:before_script'] do
      option = if powerdns_recursor_version == '3.7.3'
                 ''
               else
                 '--config-name=V4 --daemon=on --write-pid=yes'
               end

      sh %(#{powerdns_recursor_rootdir}/pdns_recursor\
           --config-dir=tests/checks/fixtures/powerdns-recursor/ #{option}\
           --socket-dir=#{powerdns_recursor_rootdir})
      Wait.for 5353, 5
    end

    task script: ['ci:common:script'] do
      this_provides = [
        'powerdns_recursor'
      ]
      Rake::Task['ci:common:run_tests'].invoke(this_provides)
    end

    task cleanup: ['ci:common:cleanup'] do
      pid = if powerdns_recursor_version == '3.7.3'
              'pdns_recursor.pid'
            else
              'pdns_recursor-V4.pid'
            end
      sh %(kill `cat #{powerdns_recursor_rootdir}/#{pid}` || echo 'Already dead')
    end

    task before_cache: ['ci:common:before_cache']

    task :execute do
      Rake::Task['ci:common:execute'].invoke(flavor)
    end
  end
end
