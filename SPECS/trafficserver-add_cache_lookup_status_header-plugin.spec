%define _prefix /opt/trafficserver

Summary:	a plugin for Apache Traffic Server to add the cache lookup status to the client response header
Name:		trafficserver-add_cache_lookup_status_header-plugin
Version:	0.1.1
Release:	2%{?dist}
License:	ASL 2.0
Group:		System Environment/Daemons
URL:		https://github.com/hnakamur/%{name}

Source0:	https://github.com/hnakamur/%{name}/archive/%{version}.tar.gz#/%{name}-%{version}.tar.gz

BuildRequires:	trafficserver-devel

%description
This is a Apache Traffic Server plugin to add the cache lookup status to
the client response header.

%prep
%setup -q

%build
%{_prefix}/bin/tsxs -o add_cache_lookup_status_header.so add_cache_lookup_status_header.c

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/%{_libdir}/trafficserver/plugins
install -m 755 add_cache_lookup_status_header.so %{buildroot}/%{_libdir}/trafficserver/plugins/add_cache_lookup_status_header.so

# The clean section  is only needed for EPEL and Fedora < 13
# http://fedoraproject.org/wiki/PackagingGuidelines#.25clean
%clean
rm -rf %{buildroot}

%pre
getent group ats >/dev/null || groupadd -r ats -g 176 &>/dev/null
getent passwd ats >/dev/null || \
useradd -r -u 176 -g ats -d / -s /sbin/nologin \
        -c "Apache Traffic Server" ats &>/dev/null

%files
%defattr(-, ats, ats, -)
%{!?_licensedir:%global license %%doc}
%license LICENSE
%{_libdir}/trafficserver/plugins/*.so

%changelog
* Mon Apr 11 2016 Hiroaki Nakamura <hnakamur@gmail.com> 0.1.1-2
- Change prefix to /opt/trafficserver

* Tue Feb  9 2016 Hiroaki Nakamura <hnakamur@gmail.com> 0.1.1-1
- Version 0.1.1

* Sat Feb  6 2016 Hiroaki Nakamura <hnakamur@gmail.com> 0.1.0-1
- Version 0.1.0
