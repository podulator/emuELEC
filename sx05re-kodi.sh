#!/bin/bash

# This script is based on https://github.com/ToKe79/retroarch-kodi-addon-LibreELEC/blob/master/retroarch-kodi.sh
# It has been adapted to Sx05RE by Shanti Gilbert and modified to install emulationstation and other emulators.

build_it() {
REPO_DIR=""
FORCEUPDATE="yes"

[ -z "$SCRIPT_DIR" ] && SCRIPT_DIR=$(pwd)

# make sure you change these lines to point to your Sx05RE git clone
SX05RE="${SCRIPT_DIR}"
GIT_BRANCH="Sx05RE"

LOG="${SCRIPT_DIR}/sx05re-kodi_`date +%Y%m%d_%H%M%S`.log"

# Exit if not in the right branch 
if [ -d "$SX05RE" ] ; then
	cd "$SX05RE"
	git checkout ${GIT_BRANCH} &>>"$LOG"
		branch=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
	if [ $branch != $GIT_BRANCH ]; then 
	   echo "ERROR: Could not automatically switch branch to $GIT_BRANCH. Please make sure you are in branch $GIT_BRANCH before running this script"
	   echo "Wrong GIT branch, wanted $GIT_BRANCH got $branch" &>>"$LOG"
	   exit 1
   fi 
fi 

[ -z "$DISTRO" ] && DISTRO=Sx05RE
[ -z "$PROJECT" ] && PROJECT=Amlogic
[ -z "$ARCH" ] && ARCH=arm
[ -z "$REPO_DIR" ] && REPO_DIR="${SCRIPT_DIR}/repo"
[ -z "$PROVIDER" ] && PROVIDER="CoreELEC"
[ -z "$VERSION" ] && VERSION=$(cat $SCRIPT_DIR/distributions/$DISTRO/version | grep LIBREELEC_VERSION | grep -oP '"\K[^"\047]+(?=["\047])')

BUILD_SUBDIR="build.${DISTRO}-${PROJECT}.${ARCH}-${VERSION}"
SCRIPT="scripts/build"
PACKAGES_SUBDIR="packages"
PROJECT_DIR="${SCRIPT_DIR}/retroarch_work"
TARGET_DIR="${PROJECT_DIR}/`date +%Y-%m-%d_%H%M%S`"
BASE_NAME="$PROVIDER.$DISTRO"

LIBRETRO_BASE="retroarch retroarch-assets retroarch-overlays core-info common-shaders openal-soft"

    # Get cores from Sx05RE options file
    OPTIONS_FILE="${SCRIPT_DIR}/distributions/${DISTRO}/options"
    [ -f "$OPTIONS_FILE" ] && source "$OPTIONS_FILE" || { echo "$OPTIONS_FILE: not found! Aborting." ; exit 1 ; }
    [ -z "$LIBRETRO_CORES" ] && { echo "LIBRETRO_CORES: empty. Aborting!" ; exit 1 ; }

PKG_EMUS="emulationstation advancemame PPSSPPSDL reicastsa amiberry hatarisa openbor"
PACKAGES_Sx05RE="$PKG_EMUS \
				mpv \
				sx05re \
				empty \
				sixpair \
				joyutils \
				SDL2-git \
				freeimage \
				vlc \
				freetype \
				es-theme-ComicBook \
				bash \
				libretro-bash-launcher \
				SDL_GameControllerDB
				libvorbisidec \
				gl4es \
				python-evdev \
				libpng16 \
				mpg123-compat"
				
LIBRETRO_CORES_LITE="fbalpha gambatte genesis-plus-gx mame2003-plus mgba mupen64plus nestopia pcsx_rearmed snes9x stella"

if [ "$1" = "lite" ]; then
  PACKAGES_ALL="$LIBRETRO_CORES_LITE"
 else
  PACKAGES_ALL="$LIBRETRO_CORES"
 fi 

PACKAGES_ALL="$LIBRETRO_BASE $PACKAGES_ALL $PACKAGES_Sx05RE" 
DISABLED_CORES="libretro-database reicast $LIBRETRO_EXTRA_CORES openlara beetle-psx beetle-saturn"

if [ -n "$DISABLED_CORES" ] ; then
	for core in $DISABLED_CORES ; do
		PACKAGES_ALL=$(sed "s/\b$core\b//g" <<< $PACKAGES_ALL)
	done
fi

	ADDON_NAME=${BASE_NAME}.${PROJECT}_${ARCH}
	RA_NAME_SUFFIX=${PROJECT}.${ARCH}

ADDON_NAME="script.sx05re.launcher"
ADDON_DIR="${PROJECT_DIR}/${ADDON_NAME}"

if [ "$1" = "lite" ] ; then
  ARCHIVE_NAME="${ADDON_NAME}-${VERSION}-lite.zip"
else
  ARCHIVE_NAME="${ADDON_NAME}-${VERSION}.zip"
fi

read -d '' message <<EOF
Building Sx05RE KODI add-on for CoreELEC:

DISTRO=${DISTRO}
PROJECT=${PROJECT}
ARCH=${ARCH}
VERSION=${VERSION}
GIT_BRANCH=${GIT_BRANCH}


Working in: ${SCRIPT_DIR}
Temporary project folder: ${TARGET_DIR}

Target zip: ${REPO_DIR}/${ADDON_NAME}/${ARCHIVE_NAME}
EOF

echo "$message"
echo

# make sure the old add-on is deleted
if [ -d ${REPO_DIR} ] && [ "$1" != "lite" ] ; then
echo "Removing old add-on at ${REPO_DIR}"
rm -rf ${REPO_DIR}
fi

if [ -d ${PROJECT_DIR} ] && [ "$1" != "lite" ] ; then
echo "Removing old add-on at ${REPO_DIR}"
rm -rf ${PROJECT_DIR}
fi

# Checks folders
for folder in ${REPO_DIR} ${REPO_DIR}/${ADDON_NAME} ${REPO_DIR}/${ADDON_NAME}/resources ; do
	[ ! -d "$folder" ] && { mkdir -p "$folder" && echo "Created folder '$folder'" || { echo "Could not create folder '$folder'!" ; exit 1 ; } ; } || echo "Folder '$folder' exists."
done
echo

if [ -d "$SX05RE" ] ; then
	cd "$SX05RE"
	echo "Building packages:"
	for package in $PACKAGES_ALL ; do
		echo -ne "\t$package "
			DISTRO=$DISTRO PROJECT=$PROJECT ARCH=$ARCH ./$SCRIPT $package &>>"$LOG"
		if [ $? -eq 0 ] ; then
			echo "(ok)"
		else
			echo "(failed)"
			echo "Error building package '$package'!"
			exit 1
		fi
	done
	echo
	if [ ! -d "$TARGET_DIR" ] ; then
		echo -n "Creating target folder '$TARGET_DIR'..."
		mkdir -p "$TARGET_DIR" &>>"$LOG"
		if [ $? -eq 0 ] ; then
			echo "done."
		else
			echo "failed!"
			echo "Could not create folder '$TARGET_DIR'!"
			exit 1
		fi
	fi
	echo
	echo "Copying packages:"
		for package in $PACKAGES_ALL ; do
			echo -ne "\t$package "
			SRC="$(find ${PACKAGES_SUBDIR} -wholename ${PACKAGES_SUBDIR}/*/${package}/package.mk -print -quit)"
			if [ -f "$SRC" ] ; then
				PKG_VERSION=`cat $SRC | grep -oP 'PKG_VERSION="\K[^"]+'`
			else
				echo "(failed- no package.mk)"
				exit 1
			fi			
			PKG_FOLDER="${BUILD_SUBDIR}/${package}-${PKG_VERSION}/.install_pkg"
			if [ -d "$PKG_FOLDER" ] ; then
				cp -Rf "${PKG_FOLDER}/"* "${TARGET_DIR}/" &>>"$LOG"
				[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
			else
				echo "(skipped - not found or not compatible)"
				echo "skipped $PKG_FOLDER" &>>"$LOG"
				continue
			fi
		done

	echo
else
	echo "Folder '$SX05RE' does not exist! Aborting!" >&2
	exit 1
fi
if [ -f "$ADDON_DIR" ] ; then
	echo -n "Removing previous addon..."
	rm -rf "${ADDON_DIR}" &>>"$LOG"
	[ $? -eq 0 ] && echo "done." || { echo "failed!" ; echo "Error removing folder '${ADDON_DIR}'!" ; exit 1 ; }
	echo
fi
echo -n "Creating addon folder..."
mkdir -p "${ADDON_DIR}" &>>"$LOG"
[ $? -eq 0 ] && echo "done." || { echo "failed!" ; echo "Error creating folder '${ADDON_DIR}'!" ; exit 1 ; }
echo
cd "${ADDON_DIR}"
echo "Creating folder structure..."
for f in config resources bin; do
	echo -ne "\t$f "
	mkdir -p $f &>>"$LOG"
	[ $? -eq 0 ] && echo -e "(ok)" || { echo -e "(failed)" ; exit 1 ; }
done
echo
 if [ "$FORCEUPDATE" == "yes" ]; then
	echo -ne "Creating forceupdate..."
	echo
	touch "${ADDON_DIR}/forceupdate"
	[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
 fi
echo -ne "Moving config files to addon..."
cp -rf "${TARGET_DIR}/usr/config" "${ADDON_DIR}/" &>>"$LOG"
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tretroarch.cfg "
mv -v "${ADDON_DIR}/config/retroarch/retroarch.cfg" "${ADDON_DIR}/config/" &>>"$LOG"
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tcreating empty joypads dir"
mkdir -p "${ADDON_DIR}/resources/joypads" &>>"$LOG"
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tbinaries "
mv -v "${TARGET_DIR}/usr/bin" "${ADDON_DIR}/" &>>"$LOG"
rm -rf "${ADDON_DIR}/bin/assets"
mv -v "${ADDON_DIR}/config/ppsspp/assets" "${ADDON_DIR}/bin" &>>"$LOG"
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tlibraries and cores "
mv -v "${TARGET_DIR}/usr/lib" "${ADDON_DIR}/" &>>"$LOG"
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\taudio filters "
mv -v "${TARGET_DIR}/usr/share/audio_filters" "${ADDON_DIR}/resources/" &>>"$LOG"
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tvideo filters "
mv -v "${TARGET_DIR}/usr/share/video_filters" "${ADDON_DIR}/resources/" &>>"$LOG"
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tshaders "
mv -v "${TARGET_DIR}/usr/share/common-shaders" "${ADDON_DIR}/resources/shaders" &>>"$LOG"
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tremoving unused assets "
rm -rf "${TARGET_DIR}/usr/share/retroarch-assets/branding"
rm -rf "${TARGET_DIR}/usr/share/retroarch-assets/glui"
rm -rf "${TARGET_DIR}/usr/share/retroarch-assets/nuklear"
rm -rf "${TARGET_DIR}/usr/share/retroarch-assets/nxrgui"
rm -rf "${TARGET_DIR}/usr/share/retroarch-assets/ozone"
rm -rf "${TARGET_DIR}/usr/share/retroarch-assets/pkg"
rm -rf "${TARGET_DIR}/usr/share/retroarch-assets/switch"
rm -rf "${TARGET_DIR}/usr/share/retroarch-assets/wallpapers"
rm -rf "${TARGET_DIR}/usr/share/retroarch-assets/zarch"
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tassets "
mv -v "${TARGET_DIR}/usr/share/retroarch-assets" "${ADDON_DIR}/resources/assets" &>>"$LOG"
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\toverlays "
rm -rf "${TARGET_DIR}/usr/share/retroarch-overlays/borders"
rm -rf "${TARGET_DIR}/usr/share/retroarch-overlays/effects"
rm -rf "${TARGET_DIR}/usr/share/retroarch-overlays/gamepads"
rm -rf "${TARGET_DIR}/usr/share/retroarch-overlays/ipad"
rm -rf "${TARGET_DIR}/usr/share/retroarch-overlays/keyboards"
rm -rf "${TARGET_DIR}/usr/share/retroarch-overlays/misc"
mv -v "${TARGET_DIR}/usr/share/retroarch-overlays" "${ADDON_DIR}/resources/overlays" &>>"$LOG"
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tadvacemame Config "
rm -rf "${TARGET_DIR}/usr/share/advance/advmenu.rc"
mv -v "${TARGET_DIR}/usr/share/advance" "${ADDON_DIR}/config" &>>"$LOG"
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tVLC libs "
rm "${ADDON_DIR}/lib/vlc"
mv -v "${TARGET_DIR}/usr/config/vlc" "${ADDON_DIR}/lib/" &>>"$LOG"
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tRemoving unneeded files "
rm "${ADDON_DIR}/bin/startfe.sh"
rm "${ADDON_DIR}/bin/killkodi.sh"
rm "${ADDON_DIR}/bin/emulationstation.sh"
rm "${ADDON_DIR}/bin/emustation-config"
rm "${ADDON_DIR}/bin/clearconfig.sh"
rm "${ADDON_DIR}/bin/reicast.sh"
rm "${ADDON_DIR}/config/autostart.sh"
rm "${ADDON_DIR}/config/smb.conf"
rm -rf "${ADDON_DIR}/config/vlc"
rm -rf "${ADDON_DIR}/config/out123"
rm -rf ${ADDON_DIR}/bin/mpg123-*
rm -rf ${ADDON_DIR}/bin/*png*
rm -rf "${ADDON_DIR}/bin/cvlc"
find ${ADDON_DIR}/lib -maxdepth 1 -type l -exec rm -f {} \;
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo
echo "Creating files..."
echo -ne "\treicast.sh "
read -d '' content <<EOF
#!/bin/sh

#set reicast BIOS dir to point to /storage/roms/bios/dc
if [ ! -L /storage/.local/share/reicast/data ]; then
	mkdir -p /storage/.local/share/reicast 
	rm -rf /storage/.local/share/reicast/data
	ln -s /storage/roms/bios/dc /storage/.local/share/reicast/data
fi

if [ ! -L /storage/.local/share/reicast/mappings ]; then
mkdir -p /storage/.local/share/reicast/
ln -sf /storage/.kodi/addons/${ADDON_NAME}/config/reicast/mappings /storage/.local/share/reicast/mappings
ln -sf /storage/.kodi/addons/${ADDON_NAME}/config/reicast /storage/.config/reicast
fi


# try to automatically set the gamepad in emu.cfg
y=1


for D in \`find /dev/input/by-id/ | grep event-joystick\`; do
  str=\$(ls -la \$D)
  i=\$((\${#str}-1))
  DEVICE=\$(echo "\${str:\$i:1}")
  CFG="/storage/.config/reicast/emu.cfg"
   sed -i -e "s/^evdev_device_id_\$y =.*\$/evdev_device_id_\$y = \$DEVICE/g" \$CFG
   y=\$((y+1))
 if [\$y -lt 4]; then
  break
 fi 
done

/storage/.kodi/addons/${ADDON_NAME}/bin/reicast "\$1"
EOF
echo "$content" > bin/reicast.sh
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
chmod +x bin/reicast.sh
echo -ne "\tsx05re.sh "
read -d '' content <<EOF
#!/bin/sh

. /etc/profile

oe_setup_addon ${ADDON_NAME}

systemd-run \$ADDON_DIR/bin/sx05re.start
EOF
echo "$content" > bin/sx05re.sh
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
chmod +x bin/sx05re.sh
echo -ne "\temustation-config "
read -d '' content <<EOF
#!/bin/sh

/storage/.kodi/addons/${ADDON_NAME}/bin/setres.sh

# Name of the file we need to put in the roms folder in your USB or SDCARD 
ROMFILE="sx05reroms"

# Only run the USB check if the ROMFILE does not exists in /storage/roms, this can help for manually created symlinks or network shares
# or if you want to skip the USB rom mount for whatever reason
if  [ ! -f "/storage/roms/\$ROMFILE" ]; then

# if the file is not present then we look for the file in connected USB media
FULLPATHTOROMS="\$(find /media/*/roms/ -name \$ROMFILE -maxdepth 1)"

if [[ -z "\${FULLPATHTOROMS}" ]]; then
# "can't find the ROMFILE", if the symlink exists, then remove it and restore the backup if it exists

  if [ -L "/storage/roms" ]; then
      rm /storage/roms
     if [ -d "/storage/roms2" ]; then
      mv /storage/roms2 /storage/roms
     fi 
  fi
    else
      # we back up the roms folder just in case
      mv /storage/roms /storage/roms2
      
       # we strip the name of the file.
        PATHTOROMS=\${FULLPATHTOROMS%\$ROMFILE}

	# this might be overkill but we need to double check that there is no symlink to roms folder already
	# only delete the symlink if the ROMFILE is found.
	# We could probably find a better way 
        if  [ -L "/storage/roms" ]; then
         rm /storage/roms
        fi 
    # All the sanity checks have passed, we have a ROMFILE so we create the symlink to the roms in our USB
    ln -sTf \$PATHTOROMS /storage/roms
  fi 
fi 

exit 0
EOF
echo "$content" > bin/emustation-config
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
chmod +x bin/emustation-config
echo -ne "\tes_input.cfg "
rm config/emulationstation/es_input.cfg
read -d '' content <<EOF
<?xml version="1.0"?>
<inputList>
  <inputAction type="onfinish">
    <command>/storage/.kodi/addons/${ADDON_NAME}/bin/bash /storage/.emulationstation/scripts/inputconfiguration.sh</command>
  </inputAction>
  <inputConfig type="joystick" deviceName="Sony PLAYSTATION(R)3 Controller">
	<input name="a" type="button" id="13" value="1" />
	<input name="b" type="button" id="14" value="1" />
	<input name="down" type="button" id="6" value="1" />
	<input name="hotkeyenable" type="button" id="16" value="1" />
	<input name="left" type="button" id="7" value="1" />
	<input name="leftanalogdown" type="axis" id="1" value="1" />
	<input name="leftanalogleft" type="axis" id="0" value="-1" />
	<input name="leftanalogright" type="axis" id="0" value="1" />
	<input name="leftanalogup" type="axis" id="1" value="-1" />
	<input name="leftshoulder" type="button" id="10" value="1" />
	<input name="leftthumb" type="button" id="1" value="1" />
	<input name="lefttrigger" type="button" id="8" value="1" />
	<input name="right" type="button" id="5" value="1" />
	<input name="rightanalogdown" type="axis" id="3" value="1" />
	<input name="rightanalogleft" type="axis" id="2" value="-1" />
	<input name="rightanalogright" type="axis" id="2" value="1" />
	<input name="rightanalogup" type="axis" id="3" value="-1" />
	<input name="rightshoulder" type="button" id="11" value="1" />
	<input name="rightthumb" type="button" id="2" value="1" />
	<input name="righttrigger" type="button" id="9" value="1" />
	<input name="select" type="button" id="0" value="1" />
	<input name="start" type="button" id="3" value="1" />
	<input name="up" type="button" id="4" value="1" />
	<input name="x" type="button" id="12" value="1" />
	<input name="y" type="button" id="15" value="1" />
</inputConfig>
</inputList>
EOF
echo "$content" > config/emulationstation/es_input.cfg
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tPS3 Gamepad Workaround "
cp "${SCRIPT_DIR}/packages/sx05re/sx05re/gamepads/Sony PLAYSTATION(R)3 Controller.cfg"  resources/joypads/
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tsx05re.start "
read -d '' content <<EOF
#!/bin/sh

. /etc/profile

oe_setup_addon ${ADDON_NAME}

PATH="\$ADDON_DIR/bin:\$PATH"
LD_LIBRARY_PATH="\$ADDON_DIR/lib:\$LD_LIBRARY_PATH"
RA_CONFIG_DIR="/storage/.config/retroarch/"
RA_CONFIG_FILE="\$RA_CONFIG_DIR/retroarch.cfg"
RA_CONFIG_SUBDIRS="savestates savefiles remappings playlists system thumbnails"
RA_EXE="\$ADDON_DIR/bin/retroarch"
ROMS_FOLDER="/storage/roms"
DOWNLOADS="downloads"
RA_PARAMS="--config=\$RA_CONFIG_FILE --menu"
LOGFILE="/storage/retroarch.log"

# external/usb rom mounting
sh \$ADDON_DIR/bin/emustation-config

 if [ \$ra_es -eq 1 ] ; then
   RA_EXE="\$ADDON_DIR/bin/emulationstation"
   RA_PARAMS=""
   LOGFILE="/storage/emulationstation.log"
 fi

[ ! -d "\$RA_CONFIG_DIR" ] && mkdir -p "\$RA_CONFIG_DIR"
  
 if [ ! -d "\$ROMS_FOLDER" ] && [ ! -L "\$ROMS_FOLDER" ]; then
    mkdir -p "\$ROMS_FOLDER"
    
     all_roms="downloads,amiga,atari2600,atari5200,atari7800,atarilynx,bios,c64,dreamcast,fba,fds,gamegear,gb,gba,gbc,mame,mame-advmame,mastersystem,megadrive,msx,n64,neogeo,nes,pc,pcengine,psp,psx,scummvm,sega32x,segacd,snes,videopac,zxspectrum" 
 
     for romfolder in \$(echo \$all_roms | tr "," " "); do
        mkdir -p "\$ROMS_FOLDER/\$romfolder"
     done
  fi
 [ ! -d "\$ROMS_FOLDER/\$DOWNLOADS" ] && mkdir -p "\$ROMS_FOLDER/\$DOWNLOADS"

for subdir in \$RA_CONFIG_SUBDIRS ; do
	[ ! -d "\$RA_CONFIG_DIR/\$subdir" ] && mkdir -p "\$RA_CONFIG_DIR/\$subdir"
done

if [ ! -f "\$RA_CONFIG_FILE" ]; then
	if [ -f "\$ADDON_DIR/config/retroarch.cfg" ]; then
		cp "\$ADDON_DIR/config/retroarch.cfg" "\$RA_CONFIG_FILE"
	fi
fi

# create symlinks to libraries
# ln -sf libxkbcommon.so.0.0.0 \$ADDON_DIR/lib/libxkbcommon.so
# ln -sf libxkbcommon.so.0.0.0 \$ADDON_DIR/lib/libxkbcommon.so.0
# ln -sf libvdpau.so.1.0.0 \$ADDON_DIR/lib/libvdpau.so
# ln -sf libvdpau.so.1.0.0 \$ADDON_DIR/lib/libvdpau.so.1
# ln -sf libvdpau_trace.so.1.0.0 \$ADDON_DIR/lib/vdpau/libvdpau_trace.so
# ln -sf libvdpau_trace.so.1.0.0 \$ADDON_DIR/lib/vdpau/libvdpau_trace.so.1
ln -sf libopenal.so.1.18.2 \$ADDON_DIR/lib/libopenal.so.1
ln -sf libSDL2-2.0.so.0.9.0 \$ADDON_DIR/lib/libSDL2-2.0.so.0
ln -sf libfreeimage-3.18.0.so \$ADDON_DIR/lib/libfreeimage.so.3
ln -sf libvlc.so.5.6.0 \$ADDON_DIR/lib/libvlc.so.5
ln -sf libvlccore.so.9.0.0 \$ADDON_DIR/lib/libvlccore.so.9
ln -sf libdrm.so.2.4.0 \$ADDON_DIR/lib/libdrm.so.2
ln -sf libexif.so.12.3.3 \$ADDON_DIR/lib/libexif.so.12
ln -sf libvorbisidec.so.1.0.3 \$ADDON_DIR/lib/libvorbisidec.so.1
ln -sf libpng16.so.16.36.0 \$ADDON_DIR/lib/libpng16.so.16
ln -sf libmpg123.so.0.44.8 \$ADDON_DIR/lib/libmpg123.so.0
ln -sf libout123.so.0.2.2 \$ADDON_DIR/lib/libout123.so.0

# delete symlinks to avoid doubles

if [ -L /storage/.emulationstation ]; then
rm /storage/.emulationstation
fi 

if [ -L /tmp/joypads ]; then
rm /tmp/joypads
fi

mkdir -p /storage/.local/lib/

ln -sTf \$ADDON_DIR/resources/joypads/ /tmp/joypads
ln -sTf \$ADDON_DIR/lib/python2.7 /storage/.local/lib/python2.7

#  Check if configuration for ES is copied to storage
if [ ! -e "/storage/.emulationstation" ]; then
#ln -sf \$ADDON_DIR/config/emulationstation /storage/.emulationstation
mkdir /storage/.emulationstation
cp -rf \$ADDON_DIR/config/emulationstation/* /storage/.emulationstation
fi

if [ -f "\$ADDON_DIR/forceupdate" ]; then
cp -rf \$ADDON_DIR/config/emulationstation/* /storage/.emulationstation
cp -rf "\$ADDON_DIR/config/retroarch.cfg" "\$RA_CONFIG_FILE"
rm "\$ADDON_DIR/forceupdate"
fi

# Make sure all scripts are executable
chmod +x /storage/.emulationstation/scripts/*.sh
chmod +x \$ADDON_DIR/bin/*

[ \$ra_verbose -eq 1 ] && RA_PARAMS="--verbose \$RA_PARAMS"

if [ "\$ra_stop_kodi" -eq 1 ] ; then
	systemctl stop kodi
	if [ \$ra_log -eq 1 ] ; then
		\$RA_EXE \$RA_PARAMS >\$LOGFILE 2>&1
	else
		\$RA_EXE \$RA_PARAMS
	fi
	systemctl start kodi
else
	pgrep kodi.bin | xargs kill -SIGSTOP
	if [ \$ra_log -eq 1 ] ; then
		\$RA_EXE \$RA_PARAMS >\$LOGFILE 2>&1
	else
		\$RA_EXE \$RA_PARAMS
	fi
	pgrep kodi.bin | xargs kill -SIGCONT
fi

exit 0
EOF
echo "$content" > bin/sx05re.start
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
chmod +x bin/sx05re.start
echo -ne "\taddon.xml "
read -d '' addon <<EOF
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<addon id="${ADDON_NAME}" name="Sx05RE (${VERSION})" version="${VERSION}" provider-name="${PROVIDER}">
	<requires>
		<import addon="xbmc.python" version="2.1.0"/>
	</requires>
	<extension point="xbmc.python.pluginsource" library="default.py">
		<provides>executable</provides>
	</extension>
	<extension point="xbmc.addon.metadata">
		<summary lang="en">Sx05RE addon. Provides binary, cores and basic settings to launch it</summary>
		<description lang="en">Sx05RE addon is based on ToKe79 Retroarch/Lakka addon. Provides binary, cores and basic settings to launch Sx05RE. </description>
		<disclaimer lang="en">This is an unofficial add-on. Please don't ask for support in CoreELEC,Lakka or ToKe79 github, forums or irc channels.</disclaimer>
		<platform>linux</platform>
		<assets>
			<icon>resources/icon.png</icon>
			<fanart>resources/fanart.png</fanart>
		</assets>
	</extension>
</addon>
EOF
echo "$addon" > addon.xml
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tdefault.py "
read -d '' content <<EOF
import xbmc, xbmcgui, xbmcplugin, xbmcaddon
import os
import util

dialog = xbmcgui.Dialog()
dialog.notification('Sx05RE', 'Launching....', xbmcgui.NOTIFICATION_INFO, 5000)

ADDON_ID = '${ADDON_NAME}'

addon = xbmcaddon.Addon(id=ADDON_ID)
addon_dir = xbmc.translatePath( addon.getAddonInfo('path') )
addonfolder = addon.getAddonInfo('path')

icon    = addonfolder + 'resources/icon.png'
fanart  = addonfolder + 'resources/fanart.png'

util.runRetroarchMenu()
EOF
echo "$content" > default.py
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tutil.py "
read -d '' content <<EOF
import os, xbmc, xbmcaddon

ADDON_ID = '${ADDON_NAME}'
BIN_FOLDER="bin"
RETROARCH_EXEC="sx05re.sh"

addon = xbmcaddon.Addon(id=ADDON_ID)

def runRetroarchMenu():
	addon_dir = xbmc.translatePath( addon.getAddonInfo('path') )
	bin_folder = os.path.join(addon_dir,BIN_FOLDER)
	retroarch_exe = os.path.join(bin_folder,RETROARCH_EXEC)
	os.system(retroarch_exe)
EOF
echo "$content" > util.py
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tsettings.xml "
read -d '' content <<EOF
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<settings>
	<category label="General">
		<setting id="ra_stop_kodi" label="Stop KODI (free memory) before launching Sx05RE" type="enum" default="1" values="No|Yes" />
		<setting id="ra_log" label="Logging of Sx05RE output" type="enum" default="0" values="No|Yes" />
		<setting id="ra_verbose" label="Verbose logging (for debugging)" type="enum" default="0" values="No|Yes" />
		<setting id="ra_es" label="Run Emulationstation instead of Retroarch" type="enum" default="1" values="No|Yes" />
	</category>
</settings>
EOF
echo "$content" > resources/settings.xml
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tsettings-default.xml "
read -d '' content <<EOF
<settings>
	<setting id="ra_stop_kodi" value="1" />
	<setting id="ra_log" value="0" />
	<setting id="ra_verbose" value="0" />
	<setting id="ra_es" value="1" />
</settings>
EOF
echo "$content"  > settings-default.xml
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tfanart.png"
cp "${TARGET_DIR}/usr/share/kodi/addons/script.emulationstation.launcher/fanart.png" resources/
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\ticon.png"
cp "${TARGET_DIR}/usr/share/kodi/addons/script.emulationstation.launcher/icon.png" resources/
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tdowloading dldrastic.sh"
wget -O dldrastic.sh https://gist.githubusercontent.com/shantigilbert/f95c44628321f0f4cce4f542a2577950/raw/ 
cp dldrastic.sh config/emulationstation/scripts/dldrastic.sh
rm dldrastic.sh
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo
echo -ne "Setting permissions..."
chmod +x ${ADDON_DIR}/bin/* &>>"$LOG"
chmod +x ${ADDON_DIR}/config/emulationstation/scripts/*.sh &>>"$LOG"
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo
RA_CFG_DIR="\/storage\/\.config\/retroarch"
RA_CORES_DIR="\/storage\/\.kodi\/addons\/${ADDON_NAME}\/lib\/libretro"
RA_RES_DIR="\/storage\/\.kodi\/addons\/${ADDON_NAME}\/resources"

echo -ne "Making modifications to es_systems.cfg..."
CFG="config/emulationstation/es_systems.cfg"
sed -i -e "s/\/usr/\/storage\/.kodi\/addons\/${ADDON_NAME}/" $CFG
sed -i -e "s/\/tmp\/cores/${RA_CORES_DIR}/" $CFG
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }

echo -ne "Making modifications to inputconfiguration.sh..."
CFG="config/emulationstation/scripts/inputconfiguration.sh"
sed -i -e "s/\/usr\/bin\/bash/\/storage\/.kodi\/addons\/${ADDON_NAME}\/bin\/bash/" $CFG
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }

echo -ne "Making modifications to sx05reRunEmu.sh..."
CFG="bin/sx05reRunEmu.sh"
sed -i -e "s/SPLASH=\"\/storage\/.config/SPLASH=\"\/storage\/.kodi\/addons\/${ADDON_NAME}\/config/" $CFG
sed -i -e "s/\/usr/\/storage\/.kodi\/addons\/${ADDON_NAME}/" $CFG
sed -i -e "s/\/tmp\/cores/${RA_CORES_DIR}/" $CFG
sed -i -e 's,\[\[ $arguments != \*"KEEPMUSIC"\* \]\],[ `echo $arguments | grep -c "KEEPMUSIC"` -eq 0 ],g' $CFG
sed -i -e 's,\[\[ $arguments != \*"NOLOG"\* \]\],[ `echo $arguments | grep -c "NOLOG"` -eq 0 ],g' $CFG
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "Making modifications to BGM.sh..."
CFG="config/emulationstation/scripts/bgm.sh"
sed -i -e 's,systemd-run $MUSICPLAYER -r 32000 -Z $BGMPATH,( MPG123_MODDIR="/storage/.kodi/addons/script.sx05re.launcher/lib/mpg123" $MUSICPLAYER -r 32000 -Z $BGMPATH ) \&,g' $CFG
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "Making modifications to advmame.sh..."
CFG="bin/advmame.sh"
sed -i -e "s/\/usr\/share/\/storage\/.kodi\/addons\/${ADDON_NAME}\/config/" $CFG
sed -i -e "s/\/usr\/bin/\/storage\/.kodi\/addons\/${ADDON_NAME}\/bin/" $CFG
sed -i -e "s/device_alsa_device default/device_alsa_device sdl/" "config/advance/advmame.rc"
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }

echo -ne "Making modifications to ppsspp.sh..."
CFG="bin/ppsspp.sh"
sed -i -e "s|/usr/bin/setres.sh|/storage/.kodi/addons/${ADDON_NAME}/bin/setres.sh|" $CFG
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "Making modifications to openbor.sh..."
CFG="bin/openbor.sh"
sed -i -e "s|/usr/bin/setres.sh|/storage/.kodi/addons/${ADDON_NAME}/bin/setres.sh|" $CFG
sed -i -e "s|/storage/.config/openbor/master.cfg|/storage/.kodi/addons/${ADDON_NAME}/config/openbor/master.cfg|" $CFG
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo "Making modifications to retroarch.cfg..."
CFG="config/retroarch.cfg"
echo -ne "\toverlays "
sed -i "s/\/tmp\/overlays/${RA_RES_DIR}\/overlays/g" $CFG
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tsavefiles "
sed -i "s/\/storage\/savefiles/${RA_CFG_DIR}\/savefiles/g" $CFG
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tsavestates "
sed -i "s/\/storage\/savestates/${RA_CFG_DIR}\/savestates/g" $CFG
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tremappings "
sed -i "s/\/storage\/remappings/${RA_CFG_DIR}\/remappings/g" $CFG
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tplaylists "
sed -i "s/\/storage\/playlists/${RA_CFG_DIR}\/playlists/g" $CFG
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tcores "
sed -i "s/\/tmp\/cores/${RA_CORES_DIR}/g" $CFG
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tsystem "
sed -i "s/\/storage\/system/${RA_CFG_DIR}\/system/g" $CFG
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tassets "
sed -i "s/\/tmp\/assets/${RA_RES_DIR}\/assets/g" $CFG
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tthumbnails "
sed -i "s/\/storage\/thumbnails/${RA_CFG_DIR}\/thumbnails/g" $CFG
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tshaders "
sed -i "s/\/tmp\/shaders/${RA_RES_DIR}\/shaders/g" $CFG
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tvideo_filters "
sed -i "s/\/usr\/share\/video_filters/${RA_RES_DIR}\/video_filters/g" $CFG
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\taudio_filters "
sed -i "s/\/usr\/share\/audio_filters/${RA_RES_DIR}\/audio_filters/g" $CFG
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tretroarch-assets "
sed -i "s/\/usr\/share\/retroarch-assets/${RA_RES_DIR}\/assets/g" $CFG
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tjoypads "
sed -i "s/\/tmp\/joypads/${RA_RES_DIR}\/joypads/g" $CFG
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tdatabase "
sed -i "s/\/tmp\/database/${RA_RES_DIR}\/database/g" $CFG
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo
echo -n "Creating archive..."
cd ..
zip -y -r "${ARCHIVE_NAME}" "${ADDON_NAME}" &>>"$LOG"
[ $? -eq 0 ] && echo "done." || { echo "failed!" ; exit 1 ; }
echo
echo "Creating repository files..."
echo -ne "\tzip "
mv -vf "${ARCHIVE_NAME}" "${REPO_DIR}/${ADDON_NAME}/" &>>"$LOG"
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tsymlink "
if [ "$1" = "lite" ] ; then
ln -vsf "${ARCHIVE_NAME}" "${REPO_DIR}/${ADDON_NAME}/${ADDON_NAME}-lite-LATEST.zip" &>>"$LOG"
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
else
ln -vsf "${ARCHIVE_NAME}" "${REPO_DIR}/${ADDON_NAME}/${ADDON_NAME}-LATEST.zip" &>>"$LOG"
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
fi
echo -ne "\ticon.png "
cp "${TARGET_DIR}/usr/share/kodi/addons/script.emulationstation.launcher/icon.png" "${REPO_DIR}/${ADDON_NAME}/resources/icon.png"
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tfanart.png "
cp "${TARGET_DIR}/usr/share/kodi/addons/script.emulationstation.launcher/fanart.png" "${REPO_DIR}/${ADDON_NAME}/resources/fanart.png"
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\taddon.xml "
echo "$addon" > "${REPO_DIR}/${ADDON_NAME}/addon.xml"
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo
echo "Cleaning up..."
cd "${SCRIPT_DIR}"
echo -ne "\tproject folder "
rm -vrf "${PROJECT_DIR}" &>>"$LOG"
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo -ne "\tlog file "
rm -rf "$LOG"
[ $? -eq 0 ] && echo "(ok)" || { echo "(failed)" ; exit 1 ; }
echo
echo "Finished."
echo

} 

build_it 
# build_it "lite"
