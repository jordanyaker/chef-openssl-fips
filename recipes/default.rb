## Cookbook Name:: openssl_fips
## Recipe:: default

src_dirpath  = "#{Chef::Config['file_cache_path'] || '/tmp'}/openssl-fips-#{node['openssl_fips']['fips']['version']}"
src_filepath  = "#{src_dirpath}.tar.gz"
remote_file node['openssl_fips']['fips']['url'] do
  source   node['openssl_fips']['fips']['url']
  checksum node['openssl_fips']['fips']['checksum']
  path     src_filepath
  backup   false
end

execute 'unarchive_fips' do
  cwd  ::File.dirname(src_filepath)
  command <<-EOH
    tar zxf #{::File.basename(src_filepath)} -C #{::File.dirname(src_filepath)}
  EOH
  not_if { ::File.directory?(src_dirpath) }
end

execute 'compile_fips_source' do
  cwd     src_dirpath
  command <<-EOH
        ./config "--prefix=#{node['openssl_fips']['fips']['prefix']}" && make && make install
  EOH
  not_if { ::File.directory?(node['openssl_fips']['fips']['prefix']) }
end

src_dirpath  = "#{Chef::Config['file_cache_path'] || '/tmp'}/openssl-#{node['openssl_fips']['openssl']['version']}"
src_filepath  = "#{src_dirpath}.tar.gz"
remote_file node['openssl_fips']['openssl']['url'] do
  source   node['openssl_fips']['openssl']['url']
  checksum node['openssl_fips']['openssl']['checksum']
  path     src_filepath
  backup   false
end

execute 'unarchive_openssl' do
  cwd     ::File.dirname(src_filepath)
  command "tar zxf #{::File.basename(src_filepath)} -C #{::File.dirname(src_filepath)}"
  not_if  { ::File.directory?(src_dirpath) }
end

cnf_patch_file = '/tmp/fips_mode.patch'
cookbook_file 'fips_mode.patch' do
  path cnf_patch_file
end

configure_flags = node['openssl_fips']['openssl']['configure_flags'].map { |x| x }
configure_flags << "--prefix=#{node['openssl_fips']['openssl']['prefix']}"
configure_flags << "fips" << "--with-fipsdir=#{node['openssl_fips']['fips']['prefix']}"

execute 'compile_openssl_source' do
  cwd  src_dirpath
  command <<-EOH
    patch apps/openssl.cnf < #{cnf_patch_file}
    ./config #{configure_flags.join(' ')} && make && make install
  EOH
  not_if { ::File.directory?("#{node['openssl_fips']['openssl']['prefix']}/ssl/certs") }
end

# update ld.so.conf
file '/etc/ld.so.conf.d/openssl-fips.conf' do
  mode     '0444'
  content  "#{node['openssl_fips']['openssl']['prefix']}/ssl/lib"
  notifies :run, 'execute[ldconfig]'
end

execute 'ldconfig'
#
#profile_file = '/etc/profile.d/openssl.sh'
#cookbook_file 'openssl.sh' do
#  mode '0644'
#  path profile_file
#end
