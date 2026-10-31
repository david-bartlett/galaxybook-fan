# galaxybook-fan - rpm (Fedora). Built by packaging/rpm/build.sh, which passes
# gbver (VERSION), rel (Release) and prescript (packaging/pre-script.sh's
# output: the Book 5 check, and replacing a copy installed with install.sh).
%{!?gbver:     %global gbver 0}
%{!?rel:       %global rel 1}
%{!?prescript: %global prescript /dev/null}

%global libdir_gb  %{_prefix}/lib/galaxybook-fan
%global unbind_svc galaxybook-acpi-fan-unbind.service
%global user_timer samsung-galaxybook-fan-user-check.timer
%global update_timer galaxybook-fan-update-check.timer
%{!?_unitdir:       %global _unitdir       %{_prefix}/lib/systemd/system}
%{!?_userunitdir:   %global _userunitdir   %{_prefix}/lib/systemd/user}
%{!?_presetdir:     %global _presetdir     %{_prefix}/lib/systemd/system-preset}
%{!?_userpresetdir: %global _userpresetdir %{_prefix}/lib/systemd/user-preset}
%global debug_package %{nil}
# No %changelog (CHANGELOG.md is the record): don't take the build date from it
%global source_date_epoch_from_changelog 0

Name:           galaxybook-fan
Version:        %{gbver}
# No %{?dist}: noarch with nothing tied to a Fedora release, so one file
# (galaxybook-fan-X.Y.Z-N.noarch.rpm) serves Fedora 44 and 45
Release:        %{rel}
Summary:        Fan speed for the Samsung Galaxy Book 5 (DKMS module)
License:        GPL-2.0-only
URL:            https://github.com/david-bartlett/galaxybook-fan
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

BuildRequires:  systemd-rpm-macros
Requires:       dkms
Requires:       kernel-devel-matched
Requires:       make
Requires:       gcc
Requires:       acpica-tools
Requires:       python3
Requires:       kmod
Requires:       polkit
Requires:       libnotify
Requires:       systemd
Requires:       curl
Recommends:     mokutil
Recommends:     xdg-utils

%description
Fan speed reporting for the Samsung Galaxy Book 5 on Linux. Samsung's fan
status method (_FST) is broken on Linux, so the stock acpi-fan driver can't
read the fan. galaxybook_fan is a small DKMS hwmon module that reads the same
EC field and applies the firmware's own table. Its config is made by DKMS from
this laptop's DSDT before every build. Galaxy Book 5 only.
Command: galaxybook-fan status | check | rebuild | test-native

%prep
%setup -q

%build

%install
bash packaging/install-files.sh %{buildroot}
install -d %{buildroot}%{_presetdir} %{buildroot}%{_userpresetdir}
echo "enable %{unbind_svc}" > %{buildroot}%{_presetdir}/80-%{name}.preset
printf 'enable %%s\nenable %%s\n' %{user_timer} %{update_timer} > %{buildroot}%{_userpresetdir}/80-%{name}.preset

# Bash: the removal of an install.sh copy is the same code uninstall.sh runs.
# build.sh writes it (first install only) with every % doubled, as -f expands
# macros in the file.
%pre -p /bin/bash -f %{prescript}

%post
bash %{libdir_gb}/package-scripts.sh configure || :

%preun
if [ "$1" -eq 0 ]; then
    bash %{libdir_gb}/package-scripts.sh remove || :
fi

%postun
systemctl daemon-reload >/dev/null 2>&1 || :

%files
%license LICENSE
%doc README.md CHANGELOG.md
/usr/src/%{name}-%{version}/
%{libdir_gb}/
%{_bindir}/galaxybook-fan
%{_unitdir}/%{unbind_svc}
%{_unitdir}/samsung-galaxybook-fan-monitor.service
%{_userunitdir}/samsung-galaxybook-fan-user-check.service
%{_userunitdir}/galaxybook-fan-update-check.service
%{_userunitdir}/%{update_timer}
%{_userunitdir}/%{user_timer}
%{_userunitdir}/galaxybook-fan-session.target
%{_presetdir}/80-%{name}.preset
%{_userpresetdir}/80-%{name}.preset
%{_datadir}/polkit-1/rules.d/49-samsung-galaxybook-fan-monitor.rules
%{_prefix}/lib/dracut/dracut.conf.d/galaxybook-fan.conf
%config(noreplace) %{_sysconfdir}/modules-load.d/galaxybook_fan.conf
%config(noreplace) %{_sysconfdir}/xdg/autostart/galaxybook-fan-session.desktop
