Name: safirbu
Version: 0.21
Release: 1%{?dist}
Summary: Solution for Automatic Full Incremental Remote Backup on Unix

BuildArch: %{_arch}

License: SAFIRBU License
URL: https://github.com/DomAsProgrammer
Source0: https://github.com/DomAsProgrammer/%{name}/raw/refs/heads/main/%{name}-%{version}.tar.xz

BuildRequires: perl
BuildRequires: tar
BuildRequires: bash
BuildRequires: xz
BuildRequires: curl
BuildRequires: openssl-devel
BuildRequires: make

# du & nice
Requires: (coreutils or coreutils-single)

# find
Requires: findutils

# ionice
Requires: util-linux-core

# rsync
Requires: rsync

%global debug_package %{nil}

%description
Safirbu is a professional config file based wrapper around rsync
to create backups using the hardlink function to reduce required
space by hardlinking unchanged files. It also uses du, wc, and
find to collect statistics of the made backups, if used.
It is mainly a file backup solution.
Its strength is especially the use of every-day programs on
client side: The most basic setup is rsync, ssh and a pre-shared
key, so the backup server can access it without human
interference.

%prep
%autosetup -n %{name}-%{version}
./configure -b -i $RPM_BUILD_ROOT
./s/Bootstrap.sh

%build
make build

%install
rm -rf $RPM_BUILD_ROOT
# Expected folders from base installation
mkdir -p $RPM_BUILD_ROOT/usr/sbin
mkdir -p $RPM_BUILD_ROOT/etc/tmpfiles.d
mkdir -p $RPM_BUILD_ROOT/etc/logrotate.d
mkdir -p $RPM_BUILD_ROOT/etc/bash_completion.d
mkdir -p $RPM_BUILD_ROOT/usr/share/man/man5/
mkdir -p $RPM_BUILD_ROOT/usr/share/man/man8/
make install

%files
%license LICENCE.md
%doc README
%doc man/safirbu.5.xz
%doc man/safirbu.8.xz
%config(noreplace) /etc/safirbu/config
%config(noreplace) /etc/logrotate.d/safirbu
%config(noreplace) /etc/tmpfiles.d/safirbu.conf
/etc/bash_completion.d/safirbu
/usr/sbin/safirbu
/usr/share/man/man5/safirbu-config.5.gz
/usr/share/man/man8/safirbu.8.gz
/usr/share/safirbu/Infrastructure.sql
/usr/share/safirbu/template.job
%dir /etc/safirbu/
%dir /etc/safirbu/excludes
%dir /etc/safirbu/includes
%dir /etc/safirbu/jobs
%dir /var/lock/safirbu.d
%dir /var/lib/safirbu/
%dir /var/lib/safirbu/backup
%dir /var/log/safirbu/
%dir /var/log/safirbu/jobs

%changelog
* Sat Jul 05 2025 Dominik Bernhardt <domasprogrammer@gmail.com> - 0.21
- Simple improvements on download and build for FreeBSD.
* Sun Mar 30 2025 Dominik Bernhardt <domasprogrammer@gmail.com> - 0.20
- Inital build of public beta version.
