# FROM INFORMATION
#
# Going to use Fedora 43 :)
FROM quay.io/fedora/fedora-bootc:43

# PREP
#
# Create skel dirs for default user config
# Create initial /var/roothome directory so that packages can be installed correctly.
RUN mkdir -p /var/roothome && \
    mkdir -p /etc/skel/.config/systemd/user && \
    mkdir -p /etc/skel/.local/bin && \
    mkdir -p /etc/skel/.config/xfce4 && \
    mkdir -p /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml


# INSTALL PACKAGES
#
# Install whatever packages you'd like to be have by default in your "base" image! Ideally install anything that's "non-flatpak" and "non-containerized" here... such 
# as hardware support, multimedia, network management, etc.
RUN dnf install -y \
  @container-management \
  @xfce-desktop \
  @hardware-support \
  @multimedia \
  @networkmanager-submodules \
  xfce4-whiskermenu-plugin \
  xfce4-pulseaudio-plugin \
  lm_sensors \
  pcp \
  pcp-selinux \
  powertop \
  wget \
  unzip \
  patch \
  git \
  curl \
  mirage \
  vlc \
  wireguard-tools && \
  dnf clean all && \
  rm -rf /var/cache/dnf

# VISUAL STUDIO CODE FOR DEVELOPMENT
# 
# You can change this to whatever editor you like, but I prefer VS Code.
# The reason for installing it is that using it through Flatpak is NOT OFFICIAL or recommended.
# The official VS Code is available as a .rpm package, so we can install it directly
RUN curl -L "https://code.visualstudio.com/sha/download?build=stable&os=linux-rpm-x64" -o vscode.rpm && \
    dnf install -y ./vscode.rpm && \
    rm -f vscode.rpm && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# FLATPAK APPLICATIONS
#
# Install Flatpak applications that you want to be available by default in your "base" image

# First make sure we add flathub as a remote repository
RUN flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Install the applications that you want to be available by default in your "base" image.
RUN flatpak install -y flathub org.mozilla.firefox && \
    flatpak install -y flathub io.podman_desktop.PodmanDesktop 


# SYSTEMD SERVICES
#
# Make sure the target is graphical when booting
RUN systemctl set-default graphical.target

# Enable SSD trimming service
RUN systemctl enable fstrim.timer

# TIMEZONE
#
# I'm (near) Toronto, so set the timezone to America/Toronto, change it to whatever you'd like!
RUN ln -s /usr/share/zoneinfo/America/Toronto /etc/localtime

# INSTALL INITIAL THEME
#
# Install the "classic" bluecurve theme for Fedora for XFCE
# by running their installation script.
# patch the script to skip the user input prompts / confirmations.
RUN git clone https://github.com/neeeeow/Bluecurve.git && \
    cd Bluecurve && \
    sed -i '/read -p.*user_input/ a user_input=y' install.sh && \
    sed -i '/\[\[ \$user_input =~/d' install.sh && \
    chmod +x install.sh && \
    bash -x install.sh


# INSTALL BLUECURVE THEME GLOBALLY
#
# TODO: Maybe update it in case 2.10.0 directory path changes... right now it's hardcoded. Update this in the future.
RUN mkdir -p \
      /usr/share/themes \
      /usr/share/icons \
      /usr/share/fonts/luxi \
      /usr/lib/gtk-2.0/2.10.0/engines && \
    cp -r /root/.themes/* /usr/share/themes/ && \
    cp -r /root/.icons/* /usr/share/icons/ && \
    cp /root/.gtk-2.0/engines/libbluecurve.so /usr/lib/gtk-2.0/2.10.0/engines/ && \
    cp /root/.local/share/fonts/*.ttf /usr/share/fonts/luxi/ && \
    fc-cache -fv

# SET DEFAULT FONTS AND THEMES GLOBALLY
#
# Create a default settings file and make sure it defaults to the bluecurve theme
# Do the same with Font.
# NOTE: We do this **after** installing Bluecurve / XFCE theme so that it has all the other appropriate settings / folder naming schemes. Rather than copying it from /etc.
# Set system-wide fonts to Luxi Sans (regular) and Luxi Mono (monospace)
RUN mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml && \
    printf '%s\n' \
      '<?xml version="1.0" encoding="UTF-8"?>' \
      '<channel name="xsettings" version="1.0">' \
      '  <property name="Net" type="empty">' \
      '    <property name="ThemeName" type="string" value="Bluecurve"/>' \
      '    <property name="IconThemeName" type="string" value="Bluecurve"/>' \
      '  </property>' \
      '  <property name="Gtk" type="empty">' \
      '    <property name="FontName" type="string" value="Luxi Sans 10"/>' \
      '    <property name="MonospaceFontName" type="string" value="Luxi Mono 10"/>' \
      '  </property>' \
      '  <property name="Xft" type="empty">' \
      '    <property name="DPI" type="int" value="100"/>' \
      '    <property name="Antialias" type="int" value="1"/>' \
      '    <property name="Hinting" type="int" value="1"/>' \
      '    <property name="HintStyle" type="string" value="hintslight"/>' \
      '    <property name="RGBA" type="string" value="none"/>' \
      '  </property>' \
      '</channel>' \
      > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml

# XFCE PANEL LAYOUT, WALLPAPER AND KEY SHORTCUTS.
#
# Setup the "Classic" panel layout for XFCE that imitates the old RHEL / Fedora layout
# 
# Why a systemd unit + script? Well, this is only able to be ran AFTER the user logs in, as XFCE4 components need to be running for the panel + wallpaper to be set.
RUN curl -L https://raw.githubusercontent.com/bluebootsy/docs/refs/heads/main/panel/retro-xfce4-fedora-core-panel.tar.bz2 -o /usr/share/xfce4-panel-profiles/retro-xfce4-fedora-core-panel.tar.bz2
RUN curl -L https://raw.githubusercontent.com/bluebootsy/docs/refs/heads/main/img/og-wallpaper.png -o /usr/share/backgrounds/og-wallpaper.png

RUN chmod 777 /usr/share/xfce4-panel-profiles/retro-xfce4-fedora-core-panel.tar.bz2 && \
    chmod 777 /usr/share/backgrounds/og-wallpaper.png

RUN printf '%s\n' \
  '#!/bin/bash' \
  '' \
  'FLAG="$HOME/.config/.panel_restored"' \
  'if [ -f "$FLAG" ]; then' \
  '  exit 0' \
  'fi' \
  '' \
  '# Wait for XFCE components to start' \
  'while ! pgrep -x xfce4-panel >/dev/null || ! pgrep -x xfdesktop >/dev/null; do' \
  '  sleep 1' \
  'done' \
  '' \
  '# Restore panel layout' \
  'xfce4-panel-profiles load "/usr/share/xfce4-panel-profiles/retro-xfce4-fedora-core-panel.tar.bz2"' \
  '' \
  '# Set wallpaper' \
  'xfconf-query -c xfce4-desktop --create --type string -p /backdrop/screen0/monitoreDP-1/workspace0/last-image -s /usr/share/backgrounds/og-wallpaper.png' \
  '' \
  '# Mark as done' \
  'touch "$FLAG"' \
  > /etc/skel/.local/bin/panel-restore-once.sh && \
  chmod +x /etc/skel/.local/bin/panel-restore-once.sh


# SYSTEMD SERVICE FOR XFCE PANEL RESTORE
#
# This is ONLY ran once, as it checks if .config/.panel_restored file exists
# if it does not, it'll run the (above) script to ensure the panel layout is restored & wallpaper is set.
RUN mkdir -p /etc/systemd/user && \
    printf '%s\n' \
      '[Unit]' \
      'Description=Restore XFCE Panel Layout Once' \
      'After=graphical-session.target' \
      '' \
      '[Service]' \
      'Type=oneshot' \
      'ExecStart=%h/.local/bin/panel-restore-once.sh' \
      'RemainAfterExit=true' \
      '' \
      '[Install]' \
      'WantedBy=default.target' \
      > /etc/systemd/user/xfce-panel-restore.service && \
    mkdir -p /etc/systemd/user/default.target.wants && \
    ln -sf ../xfce-panel-restore.service /etc/systemd/user/default.target.wants/xfce-panel-restore.service

# PANEL ICON SIZE
# 
# Increase the panel size to match all other aspects of the retro theme.
RUN mkdir -p /etc/xdg/xfce4/panel && \
    echo '[Panel]' > /etc/xdg/xfce4/panel/panels.xml && \
    echo 'IconSize=36' >> /etc/xdg/xfce4/panel/panels.xml

# LOGIN SCREEN SETUP
# 
# Installs LightDM and the GTK greeter
# and changes it to try to match the original Fedora Core 1 login screen.
RUN dnf install -y lightdm lightdm-gtk && \
    systemctl enable lightdm.service && \
    systemctl disable gdm || true && \
    systemctl disable sddm || true
RUN curl -L https://raw.githubusercontent.com/bluebootsy/docs/refs/heads/main/img/login-wallpaper.png -o /usr/share/backgrounds/login-wallpaper.png
RUN mkdir -p /etc/lightdm && \
    printf '%s\n' \
      '[greeter]' \
      'theme-name=Bluecurve' \
      'icon-theme-name=Bluecurve' \
      'font-name=Luxi Sans 10' \
      'xft-antialias=true' \
      'xft-hintstyle=hintslight' \
      'background=/usr/share/backgrounds/login-wallpaper.png' \
      'show-user-image=false' \
      'welcome-message=Blueboots' \
      'indicators=' \
      > /etc/lightdm/lightdm-gtk-greeter.conf

# COPY OVER THEME TO ALL NEW USERS TOO
#
# This is a "just-in-case" measure to ensure that all new users created
# will have the same theme and panel layout.
RUN mkdir -p /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml && \
    cp /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
       /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/

# ENABLE PASSWORDLESS SUDO FOR WHEEL GROUP
#
# Enables this so that within bootc-image-builder you can just provide "wheel" as the group for the user in order to use sudo without a password.
RUN printf "%s\n" \
  "# Enable passwordless sudo for the wheel group" \
  "%wheel        ALL=(ALL)        NOPASSWD: ALL" \
  > /etc/sudoers.d/wheel-nopasswd

# POLKIT RULES FOR RPMS TO AVOID ERRORS AND WARNINGS
#
# Needed to avoid any errors or warnings when using the `rpm-ostree` commands.
RUN printf "%s\n" \
  "polkit.addRule(function(action, subject) {" \
  "    if ((action.id == \"org.projectatomic.rpmostree1.repo-refresh\" ||" \
  "         action.id == \"org.projectatomic.rpmostree1.upgrade\") &&" \
  "        subject.active == true &&" \
  "        subject.local == true) {" \
  "            return polkit.Result.YES;" \
  "    }" \
  "" \
  "    if ((action.id == \"org.projectatomic.rpmostree1.install-uninstall-packages\" ||" \
  "         action.id == \"org.projectatomic.rpmostree1.rollback\" ||" \
  "         action.id == \"org.projectatomic.rpmostree1.reload-daemon\" ||" \
  "         action.id == \"org.projectatomic.rpmostree1.cancel\" ||" \
  "         action.id == \"org.projectatomic.rpmostree1.cleanup\" ||" \
  "         action.id == \"org.projectatomic.rpmostree1.client-management\") &&" \
  "        subject.active == true &&" \
  "        subject.local == true &&" \
  "        subject.isInGroup(\"wheel\")) {" \
  "            return polkit.Result.YES;" \
  "    }" \
  "" \
  "    if ((action.id == \"org.projectatomic.rpmostree1.install-local-packages\" ||" \
  "         action.id == \"org.projectatomic.rpmostree1.override\" ||" \
  "         action.id == \"org.projectatomic.rpmostree1.deploy\" ||" \
  "         action.id == \"org.projectatomic.rpmostree1.rebase\" ||" \
  "         action.id == \"org.projectatomic.rpmostree1.bootconfig\") &&" \
  "        subject.active == true &&" \
  "        subject.local == true &&" \
  "        subject.isInGroup(\"wheel\")) {" \
  "            return polkit.Result.AUTH_ADMIN;" \
  "    }" \
  "});" \
  > /etc/polkit-1/rules.d/org.projectatomic.rpmostree1.rules

# Checking every day is a lot... we should only check (and apply) updates for bootc once a week.
#
RUN mkdir -p /etc/systemd/system/bootc-fetch-apply-updates.timer.d && \
printf "%s\n" \
  "[Timer]" \
  "RandomizedDelaySec=600" \
  "#Apply updates on Saturday at midnight" \
  "OnCalendar=Sat *-*-* 03:00:00" \
  > /etc/systemd/system/bootc-fetch-apply-updates.timer.d/weekly.conf
