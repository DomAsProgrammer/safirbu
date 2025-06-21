uriCompilerConfig:=configuration.conf
uriConfigFile:=etc/safirbu/config
uriBaseDir:=$(shell echo "`pwd`")
strBuildName:=$(shell basename "$(uriBaseDir)")
uriWorkDir:=$(shell echo "$(uriBaseDir)/work")
uriBuildDest:=
uriUninstaller:=
uriSafirbuConfig:=
uriLogrotConfig:=
uriTmpdirConfig:=
export INSTALLDIR=
export path_rsync=
export path_nice=
export path_ionice=
export path_du=
export path_find=
export path_wc=
export path_man=
export _PERLBREW_ROOT:=$(uriWorkDir)/perlbrew
strUnamed:=$(shell uname -s)
setBuildDest:=$(eval uriBuildDest=$(shell bash -c '. $(uriCompilerConfig) && echo "$$DEST"' 2> /dev/null))
setInstallDir:=$(eval INSTALLDIR=$(shell bash -c '. $(uriCompilerConfig) && echo "$$INSTALLDIR"' 2> /dev/null))
setPerlbrewRoot:=$(eval _PERLBREW_ROOT=$(shell bash -c '. $(uriCompilerConfig) && echo "$$PERLBREW_ROOT"' 2> /dev/null))
path_rsync:=$(shell which rsync 2> /dev/null)
path_nice:=$(shell which nice 2> /dev/null)
path_ionice:=$(shell which ionice 2> /dev/null)
path_du:=$(shell which du 2> /dev/null)
path_find:=$(shell which find 2> /dev/null)
path_wc:=$(shell which wc 2> /dev/null)
path_man:=$(shell which man 2> /dev/null)
cmdPerlbrew:=$(shell echo ". \"$(_PERLBREW_ROOT)/etc/bashrc\" && perlbrew exec --with perl-5.40.2")

all: bootstrap build test

help:
	@echo -e "Usage:\n\t./configure\t- Apply default config (like ./configure)\n\tmake bootstrap\t- Check, and prepare system, and compiler\n\tmake build\t- Compile safirbu\n\tmake test\t-Run tests\n\tmake install\t- Install safirbu to the set destination" 1>&2
	@exit 1

usage: help

bootstrap: _prep
	@if [ -z '$$(which bash 2> /dev/null)' ] ; then echo 'Missing bash. Please install!' 1>&2 ; exit 1 ; fi
	@if [ -z '$$(which perl 2> /dev/null)' ] ; then echo 'Missing perl. Please install!' 1>&2 ; exit 2 ; fi
	bash 's/Bootstrap.sh'
	@echo -e 'Compiler ready.'
	@sleep 1

_test_compiler: _test_comp_perl _test_comp_libs
	bash -c '$(cmdPerlbrew) t/CheckCompiler.pl'
	bash -c '$(cmdPerlbrew) which pp'

build: _prep _test_compiler
	@# Last check
	bash -c '$(cmdPerlbrew) perl -c bin/safirbu.pl'
	@# Actual build
	@echo -e 'Compiling...'
	bash -c '$(cmdPerlbrew) pp -B -v -c -z 9 -T "$(strBuildName)" -M Net::Ping -M Text::CSV -M Text::CSV_XS -M DBD::SQLite -M Data::Dumper -M utf8 -M Time::Piece -M File::Basename -M POSIX -M Cwd -M Getopt::Long -M Net::OpenSSH:: -M File::Path -M DBI -M Encode -M Time::Local -M Storable -M Net::Domain -M Sys::Hostname -M Log::Log4perl -M String::CRC32 -M IPC::LockTicket -o "$(uriWorkDir)/bin/safirbu" bin/safirbu.pl'
	@echo -e "Built '$(uriWorkDir)/bin/safirbu'.\nBuild succeeded.\nReady to "'`make test`'".\n"
	@sleep 1

_prep:
	@if [ ! -e "$(uriCompilerConfig)" ] ; then\
		echo 'Run `./configure` or `make config` first!' 1>&2 ;\
		exit 1 ;\
		fi
	$(setBuildDest)
	$(setPerlbrewRoot)
	$(setInstallDir)

config:
	@if [ ! -e "$(uriCompilerConfig)" ] ; then\
		./configure ;\
	else\
		echo '`make config` was already ran. Use `make clean` before configuring again.' ;\
		exit 1 ;\
		fi

test: _prep _bintest
	@echo -e "Tests succeeded."
	@echo -e 'Ready to run `'"su -c 'make install'"'`.'"\n"
	@sleep 1

_test_perl:
	bash -c 't/CheckPerl.sh'

_test_comp_perl:
	bash -c '$(cmdPerlbrew) t/CheckPerl.sh'

_test_libs:
	t/CheckLibs.pl

_test_comp_libs:
	bash -c '$(cmdPerlbrew) t/CheckLibs.pl'

_test_bins:
	@if [ -z '$(path_rsync)' ] ; then echo 'Missing rsync. Please install!' 1>&2 ; exit 1 ; fi
	@if [ -z '$(path_du)' ] ; then echo 'Missing du. Please install!' 1>&2 ; exit 2 ; fi
	@if [ -z '$(path_find)' ] ; then echo 'Missing find. Please install!' 1>&2 ; exit 3 ; fi
	@if [ -z '$(path_wc)' ] ; then echo 'Missing wc. Please install!' 1>&2 ; exit 4 ; fi

_bintest: _test_bins
	@if [ ! -e '$(uriWorkDir)/bin/safirbu' ] ; then\
		echo "Nothing compiled yet." 1>&2 ;\
		exit 1 ;\
		fi

_install_files:

# /opt START
ifneq (,$(findstring /opt/,$(uriBuildDest)))

# /opt LINUX START
ifeq ($(strUnamed),Linux) 
	install -d -m 0700 "$(uriBuildDest)"
	install -d "$(uriBuildDest)/bin"
	$(eval uriUninstaller=$(uriBuildDest)/bin/UninstallSafirbu.sh)
	install -Z -d -m 0700 /var/opt/lib/safirbu{,/backup}
	install -Z -d -m 0750 /var/opt/log/safirbu
	install -Z -d -m 0700 /var/opt/log/safirbu/jobs
	install -Z -d -m 0700 /etc/opt/safirbu/{,includes,excludes,jobs}
	install -Z -d -m 0750 /var/lock/safirbu.d
	install -Z -m 0644 man/safirbu.5.xz /usr/local/share/man/man5/safirbu-config.5.xz
	install -Z -m 0644 man/safirbu.8.xz /usr/local/share/man/man8/safirbu.8.xz
	install -Z -m 0600 templates/_usr_share_safirbu_template.job /etc/opt/safirbu/jobs/template.job.new
	install -Z -m 0644 templates/_etc_tmpfiles.d_safirbu.conf /etc/tmpfiles.d/safirbu.conf
	$(eval uriTmpdirConfig=/etc/tmpfiles.d/safirbu.conf)
ifeq (,$(wildcard /etc/opt/safirbu/config))
	install -Z -m 0600 templates/_etc_safirbu_conf /etc/opt/safirbu/config
	$(eval uriSafirbuConfig=/etc/opt/safirbu/config)
	$(eval uriConfigFile=/etc/opt/safirbu/config)
else
	install -Z -m 0600 templates/_etc_safirbu_conf /etc/opt/safirbu/config.new
	$(eval uriConfigFile=/etc/opt/safirbu/config.new)
	@echo -e "WARNING: '/etc/opt/safirbu/config' exists already. Installed as '/etc/opt/safirbu/config.new'." 1>&2
endif
# /opt LINUX END

# /opt FREEBSD START
else ifeq ($(strUnamed),FreeBSD)
	install -d -m 0700 "$(uriBuildDest)"
	install -d "$(uriBuildDest)/bin"
	$(eval uriUninstaller=$(uriBuildDest)/bin/UninstallSafirbu.sh)
	install -d -m 0700 "$(uriBuildDest)/var/lib/safirbu"
	install -d -m 0700 "$(uriBuildDest)/var/lib/safirbu/backup"
	install -d -m 0750 "$(uriBuildDest)/var/log/safirbu"
	install -d -m 0700 "$(uriBuildDest)/var/log/safirbu/jobs"
	install -d -m 0700 "$(uriBuildDest)/etc/safirbu"
	install -d "$(uriBuildDest)/etc/safirbu/excludes"
	install -d "$(uriBuildDest)/etc/safirbu/includes"
	install -d "$(uriBuildDest)/etc/safirbu/jobs"
	install -d -m 0750 "$(uriBuildDest)/var/lock/safirbu.d"
	install -m 0644 man/safirbu.5.xz /usr/local/share/man/man5/safirbu-config.5.xz
	install -m 0644 man/safirbu.8.xz /usr/local/share/man/man8/safirbu.8.xz
	install -m 0600 templates/_usr_share_safirbu_template.job "$(uriBuildDest)/etc/safirbu/jobs/job.template"
ifeq (,$(wildcard $(uriBuildDest)/etc/safirbu/config))
	install -m 0600 templates/_etc_safirbu_conf "$(uriBuildDest)/etc/safirbu/config"
	$(eval uriSafirbuConfig=/etc/opt/safirbu/config)
	$(eval uriConfigFile=$(uriBuildDest)/etc/safirbu/config)
else
	install -m 0600 templates/_etc_safirbu_conf "$(uriBuildDest)/etc/safirbu/config.new"
	$(eval uriConfigFile=$(uriBuildDest)/etc/safirbu/config.new)
	@echo -e "WARNING: '$(uriBuildDest)/etc/safirbu/config.new' exists already. Installed as '$(uriBuildDest)/etc/safirbu/config.new'." 1>&2
endif
endif
# /opt FREEBSD END
# /opt END

# LINUX START
else ifeq ($(uriBuildDest),Linux)
	install -Z -d -m 0700 "$(INSTALLDIR)/var/lib/safirbu/backup
	install -Z -d -m 0750 "$(INSTALLDIR)/var/log/safirbu"{,/jobs}
	install -Z -d -m 0700 "$(INSTALLDIR)/etc/safirbu/"{,excludes,includes,jobs}
#	install -d "$(INSTALLDIR)/etc/logrotate.d"
#	install -d "$(INSTALLDIR)/etc/tmpfiles.d"
#	install -d "$(INSTALLDIR)/etc/bash_completion.d"
#	install -d "$(INSTALLDIR)/usr/share/man/man5/"
#	install -d "$(INSTALLDIR)/usr/share/man/man8/"
	install -Z -d -m 0700 "$(INSTALLDIR)/usr/share/safirbu"
	install -Z -d -m 0750 "$(INSTALLDIR)/var/lock/safirbu.d"
	install -Z -m 0644 man/safirbu.5.xz "$(INSTALLDIR)/usr/share/man/man5/safirbu-config.5.xz"
	install -Z -m 0644 man/safirbu.8.xz "$(INSTALLDIR)/usr/share/man/man8/safirbu.8.xz"
	install -Z -m 0600 templates/_usr_share_safirbu_template.job "$(INSTALLDIR)/usr/share/safirbu/template.job"
	install -Z -m 0600 s/Infrastructure.sql "$(INSTALLDIR)/usr/share/safirbu/Infrastructure.sql"
	install -Z -m 0644 templates/_etc_logrotate.d_safirbu "$(INSTALLDIR)/etc/logrotate.d/safirbu"
	$(eval uriLogrotConfig=$(INSTALLDIR)/etc/logrotate.d/safirbu)
	install -Z -m 0644 templates/_etc_tmpfiles.d_safirbu.conf "$(INSTALLDIR)/etc/tmpfiles.d/safirbu.conf"
	$(eval uriTmpdirConfig=$(INSTALLDIR)/etc/tmpfiles.d/safirbu.conf)
	install -Z -m 0644 templates/_etc_bash_completion.d_safirbu "$(INSTALLDIR)/etc/bash_completion.d/safirbu"
ifeq (,$(INSTALLDIR))
	$(eval uriUninstaller=/usr/bin/UninstallSafirbu.sh)
endif
ifeq (,$(wildcard $(INSTALLDIR)/etc/safirbu/config))
	install -Z -m 0600 templates/_etc_safirbu_conf "$(INSTALLDIR)/etc/safirbu/config"
	$(eval uriSafirbuConfig=$(INSTALLDIR)/etc/safirbu/config)
	$(eval uriConfigFile=$(INSTALLDIR)/etc/safirbu/config)
else
	install -Z -m 0600 templates/_etc_safirbu_conf "$(INSTALLDIR)/etc/safirbu/config.new"
	$(eval uriConfigFile=$(INSTALLDIR)/etc/safirbu/config.new)
	@echo -e "WARNING: '/etc/safirbu/config' exists already. Installed as '/etc/safirbu/config.new'." 1>&2
endif
# LINUX END

# FREEBSD START
else ifeq ($(uriBuildDest),FreeBSD)
	install -d -m 0700 "$(INSTALLDIR)/var/lib/safirbu"
	install -d -m 0700 "$(INSTALLDIR)/var/lib/safirbu/backup"
	install -d -m 0750 "$(INSTALLDIR)/var/log/safirbu"
	install -d -m 0700 "$(INSTALLDIR)/var/log/safirbu/jobs"
	install -d -m 0700 "$(INSTALLDIR)/usr/local/etc/safirbu"
	install -d "$(INSTALLDIR)/usr/local/etc/safirbu/excludes"
	install -d "$(INSTALLDIR)/usr/local/etc/safirbu/includes"
	install -d "$(INSTALLDIR)/usr/local/etc/safirbu/jobs"
	install -d "$(INSTALLDIR)/usr/local/etc/logrotate.d"
	install -d -m 0700 "$(INSTALLDIR)/usr/local/share/safirbu"
	install -d -m 0750 "$(INSTALLDIR)/var/spool/lock/safirbu.d"
	install -d "$(INSTALLDIR)/usr/local/etc/bash_completion.d"
#	install -d "$(INSTALLDIR)/usr/local/share/man/man5"
#	install -d "$(INSTALLDIR)/usr/local/share/man/man8"
	install -m 0644 man/safirbu.5.xz "$(INSTALLDIR)/usr/local/share/man/man5/safirbu-config.5.xz"
	install -m 0644 man/safirbu.8.xz "$(INSTALLDIR)/usr/local/share/man/man8/safirbu.8.xz"
	install -m 0600 templates/_usr_share_safirbu_template.job "$(INSTALLDIR)/usr/local/share/safirbu/template.job"
	install -m 0600 s/Infrastructure.sql "$(INSTALLDIR)/usr/local/share/safirbu/Infrastructure.sql"
	install -m 0644 templates/_etc_logrotate.d_safirbu "$(INSTALLDIR)/usr/local/etc/logrotate.d/safirbu"
	$(eval uriLogrotConfig=$(INSTALLDIR)/usr/local/etc/logrotate.d/safirbu)
	install -m 0644 templates/_etc_bash_completion.d_safirbu "$(INSTALLDIR)/usr/local/etc/bash_completion.d/safirbu"
ifeq (,$(INSTALLDIR))
	$(eval uriUninstaller=/usr/local/bin/UninstallSafirbu.sh)
endif
ifeq (,$(wildcard $(INSTALLDIR)/usr/local/etc/safirbu/config))
	install -m 0600 templates/_etc_safirbu_conf "$(INSTALLDIR)/usr/local/etc/safirbu/config"
	$(eval uriConfigFile=$(INSTALLDIR)/usr/local/etc/safirbu/config)
else
	install -m 0600 templates/_etc_safirbu_conf "$(INSTALLDIR)/usr/local/etc/safirbu/config.new"
	$(eval uriConfigFile=$(INSTALLDIR)/usr/local/etc/safirbu/config.new)
	@echo -e "WARNING: '/usr/local/etc/safirbu/config' exists already. Installed as '/usr/local/etc/safirbu/config.new'." 1>&2
endif
# FREEBSD END

# Free PATH START
else ifneq (,$(uriBuildDest))
	install -d -m 0700 "$(uriBuildDest)"
	install -d "$(uriBuildDest)/bin"
	$(eval uriUninstaller=$(uriBuildDest)/bin/UninstallSafirbu.sh)
	install -d -m 0700 "$(uriBuildDest)/var/lib/safirbu"
	install -d -m 0700 "$(uriBuildDest)/var/lib/safirbu/backup"
	install -d -m 0750 "$(uriBuildDest)/var/log/safirbu"
	install -d -m 0700 "$(uriBuildDest)/var/log/safirbu/jobs"
	install -d -m 0750 "$(uriBuildDest)/var/lock/safirbu.d"
	install -d -m 0700 "$(uriBuildDest)/etc/safirbu"
	install -d "$(uriBuildDest)/etc/safirbu/excludes"
	install -d "$(uriBuildDest)/etc/safirbu/includes"
	install -d "$(uriBuildDest)/etc/safirbu/jobs"
	install -d -m 0750 "$(uriBuildDest)/var/lock/safirbu.d"
	install -d "$(uriBuildDest)/usr/share/man/man5"
	install -d "$(uriBuildDest)/usr/share/man/man8"
	install -m 0644 man/safirbu.5.xz "$(uriBuildDest)/usr/share/man/man5/safirbu-config.5.xz"
	install -m 0644 man/safirbu.8.xz "$(uriBuildDest)/usr/share/man/man8/safirbu.8.xz"
	install -m 0600 templates/_usr_share_safirbu_template.job "$(uriBuildDest)/etc/safirbu/jobs/template.job"
ifeq (,$(wildcard $(uriBuildDest)/etc/safirbu/config))
	install -m 0600 templates/_etc_safirbu_conf "$(uriBuildDest)/etc/safirbu/config"
	$(eval uriSafirbuConfig=$(uriBuildDest)/etc/safirbu/config)
	$(eval uriConfigFile=$(uriBuildDest)/etc/safirbu/config)
else
	install -m 0600 templates/_etc_safirbu_conf "$(uriBuildDest)/etc/safirbu/config.new"
	$(eval uriConfigFile=$(uriBuildDest)/etc/safirbu/config.new)
	@echo -e "WARNING: '$(uriBuildDest)/etc/safirbu/config' exists already. Installed as '$(uriBuildDest)/etc/safirbu/config.new'." 1>&2
endif
# Free PATH END

else
	@echo "DEST is not set." 1>&2
	@exit 20
endif

# Adapt configuration file
ifeq ($(strUnamed),Linux)
	sed -Ei -e 's#%BINRSYNC%#$(path_rsync)#g' \
		-e 's#%BINNICE%#$(path_nice)#g' \
		-e 's#%BINIONICE%#$(path_ionice)#g' \
		-e 's#%BINDU%#$(path_du)#g' \
		-e 's#%BINFIND%#$(path_find)#g' \
		-e 's#%BINWC%#$(path_wc)#g' \
		-e 's#%BINMAN%#$(path_man)#g' \
		"$(uriConfigFile)"
else ifeq ($(strUnamed),FreeBSD)
	sed -Ei '' -e 's#%BINRSYNC%#$(path_rsync)#g' \
		-e 's#%BINNICE%#$(path_nice)#g' \
		-e 's#%BINIONICE%#$(path_ionice)#g' \
		-e 's#%BINDU%#$(path_du)#g' \
		-e 's#%BINFIND%#$(path_find)#g' \
		-e 's#%BINWC%#$(path_wc)#g' \
		-e 's#%BINMAN%#$(path_man)#g' \
		"$(uriConfigFile)"
endif

install: _prep _bintest _install_files
ifeq ($(uriBuildDest),Linux)
#	install -d "$(INSTALLDIR)/usr/sbin"		# DUMMY
	install -m 4500 $(uriWorkDir)/bin/safirbu $(INSTALLDIR)/usr/sbin/safirbu
else ifeq ($(uriBuildDest),FreeBSD)
#	install -d "$(INSTALLDIR)/usr/local/sbin"	# DUMMY
	install -m 4500 $(uriWorkDir)/bin/safirbu $(INSTALLDIR)/usr/local/sbin/safirbu
else 
	install -d -m 0750 "$(uriBuildDest)/sbin"
	install -m 4500 $(uriWorkDir)/bin/safirbu $(uriBuildDest)/sbin/safirbu
endif

# Uninstaller
ifeq (,$(uriUninstaller))
	@# Must wait until now to have the correct file specifications
	"$(_PERLBREW_ROOT)/perls/perl-5.40.2/bin/perl" s/BuildUninstaller.pl "$(uriSafirbuConfig)"
	install -m 4500 "$(uriWorkDir)/UninstallSafirbu.sh" "$(uriUninstaller)"
else
	@echo "Uninstaller not required." >/dev/null
endif
	@echo -e "Installation succeeded.\n"
	@sleep 1

clean:
	rm -rfv "$(uriWorkDir)/bin/safirbu" 
	@echo -e "Cleanup finished.\n"
	@sleep 1

cleanall:
	rm -rfv "work/"
	rm -rfv "$(uriCompilerConfig)"
	@echo -e "Cleanup finished.\n"
	@sleep 1

