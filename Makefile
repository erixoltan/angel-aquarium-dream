# Each widget is assembled into build/<name>/ from its Plasma shell (plasma5/<name>/) plus the
# shared parts: a package must be one self-contained directory.
#   cpufish   CPU Angelfish desktop widget, real CPU readings
#   gpufish   GPU Angelfish desktop widget, one GPU's real readings
#   netfish   Network Angelfish desktop widget, all network traffic
#   memfish   Memory Angelfish desktop widget
#   diskfish  Disk Angelfish desktop widget, one drive or all of them
#   preview   the character driven by sliders, for design work
#   iconrender  renders the Add Widgets icons (make icons); not installed with the rest
#   aquarium  Angel Aquarium Dream wallpaper: a tank with one angelfish per component
#   tanktest  dev only: the aquarium's scene in a window, with real readings
PLASMA5 := cpufish gpufish netfish memfish diskfish preview
ICONS := $(HOME)/.local/share/icons/hicolor/256x256/apps
ID_cpufish := com.erikzoltan.cpufish
ID_gpufish := com.erikzoltan.gpufish
ID_netfish := com.erikzoltan.netfish
ID_memfish := com.erikzoltan.memfish
ID_diskfish := com.erikzoltan.diskfish
ID_preview := com.erikzoltan.plasmabackground.preview
ID_iconrender := com.erikzoltan.plasmabackground.iconrender
ID_aquarium := com.erikzoltan.aquarium
ID_tanktest := com.erikzoltan.plasmabackground.tanktest
# A store package can't install an icon into the icon theme, and Plasma 5.27's Add Widgets takes
# only a theme icon name or an absolute path (tested 2026-10-17: a path inside the package
# doesn't work). So store packages name the nearest Breeze icon; the angelfish icons are on the
# store pages, and `make install` installs them for builds from source.
STOREICON_cpufish := cpu
STOREICON_gpufish := video-display
STOREICON_memfish := memory
STOREICON_diskfish := drive-harddisk
STOREICON_netfish := network-wired

.PHONY: dist art icons assemble test test-gpu test-net test-mem test-disk test-tank preview install install-aquarium uninstall restart logs clean

## Rebuild the character art (common/images, common/AngelfishArt.js) from art/src
art:
	python3 tools/build_art.py

## Render the Add Widgets icons (art/icons) from the character: full throttle, halo and wings.
## Runs in plasmawindowed, so it needs the desktop session. Commit the result.
icons: build/iconrender
	sed -i 's|@ICONS@|$(CURDIR)/art/icons|' build/iconrender/contents/ui/IconRender.qml
	kpackagetool5 -t Plasma/Applet -u build/iconrender 2>/dev/null || kpackagetool5 -t Plasma/Applet -i build/iconrender
	rm -f art/icons/*.png
	timeout 8 plasmawindowed $(ID_iconrender); ls art/icons/*.png
	kpackagetool5 -t Plasma/Applet -r $(ID_iconrender)

assemble: $(addprefix build/,$(PLASMA5))

build/%: FORCE
	rm -rf $@
	mkdir -p $@
	cp -r plasma5/$*/. $@/
	cp common/*.qml common/*.js providers/*.qml $@/contents/ui/
	if [ $* = preview ]; then cp dev/Preview.qml $@/contents/ui/; fi
	if [ $* = iconrender ]; then cp dev/IconRender.qml $@/contents/ui/; fi
	cp -r common/images $@/contents/ui/
FORCE:
# the assembled packages are what gets installed; keep them
.PRECIOUS: build/%

# A widget's Add Widgets icon is art/icons/<widget>.png, installed into the user's icon theme
# under the widget's id (its metadata.json "Icon").
install-%: build/%
	kpackagetool5 -t Plasma/Applet -u build/$* 2>/dev/null || kpackagetool5 -t Plasma/Applet -i build/$*
	if [ -f art/icons/$*.png ]; then install -D -m644 art/icons/$*.png $(ICONS)/$(ID_$*).png; touch $(HOME)/.local/share/icons/hicolor; fi

## CPU Angelfish in a window (right-click for settings). QML errors print in this terminal.
test: install-cpufish
	plasmawindowed $(ID_cpufish)

## GPU Angelfish in a window
test-gpu: install-gpufish
	plasmawindowed $(ID_gpufish)

## The aquarium's scene in a window, real readings (the wallpaper itself only shows on the desktop)
test-tank: install-tanktest
	plasmawindowed $(ID_tanktest)

## Install the aquarium wallpaper. It doesn't switch to it: pick "Angel Aquarium Dream" under
## Configure Desktop and Wallpaper. plasmashell caches wallpaper QML: make restart after updating.
install-aquarium: build/aquarium
	kpackagetool5 -t Plasma/Wallpaper -u build/aquarium 2>/dev/null || kpackagetool5 -t Plasma/Wallpaper -i build/aquarium

## Network Angelfish in a window
test-net: install-netfish
	plasmawindowed $(ID_netfish)

## Memory Angelfish in a window
test-mem: install-memfish
	plasmawindowed $(ID_memfish)

## Disk Angelfish in a window
test-disk: install-diskfish
	plasmawindowed $(ID_diskfish)

## The character with sliders, in a window. No Qt 5 qmlscene is installed here, so the
## preview runs as a small widget in plasmawindowed.
preview: install-preview
	plasmawindowed $(ID_preview)

## Install every widget; add the Angelfish widgets to the desktop from "Add Widgets…"
install: $(addprefix install-,$(PLASMA5)) install-aquarium

uninstall:
	-kpackagetool5 -t Plasma/Applet -r $(ID_cpufish)
	-kpackagetool5 -t Plasma/Applet -r $(ID_gpufish)
	-kpackagetool5 -t Plasma/Applet -r $(ID_netfish)
	-kpackagetool5 -t Plasma/Applet -r $(ID_memfish)
	-kpackagetool5 -t Plasma/Applet -r $(ID_diskfish)
	rm -f $(ICONS)/$(ID_cpufish).png $(ICONS)/$(ID_gpufish).png $(ICONS)/$(ID_netfish).png $(ICONS)/$(ID_memfish).png $(ICONS)/$(ID_diskfish).png
	-kpackagetool5 -t Plasma/Applet -r $(ID_preview)
	-kpackagetool5 -t Plasma/Applet -r $(ID_tanktest)
	-kpackagetool5 -t Plasma/Wallpaper -r $(ID_aquarium)

## Restart plasmashell so the real desktop picks up changes
restart:
	systemctl --user restart plasma-plasmashell

## Follow plasmashell logs (QML errors from desktop widgets show up here)
logs:
	journalctl --user -f -t plasmashell

## Packages for the KDE Store, in dist/: the aquarium wallpaper (.zip) and each widget
## (.plasmoid; both are zips with metadata.json at the top). Each carries the licence; a widget's
## icon becomes its STOREICON (see above).
dist: build/aquarium $(addprefix build/,$(filter-out preview,$(PLASMA5)))
	rm -rf dist; mkdir -p dist
	$(foreach w,$(filter-out preview,$(PLASMA5)),sed -i 's|"Icon": "$(ID_$(w))"|"Icon": "$(STOREICON_$(w))"|' build/$(w)/metadata.json;)
	for p in aquarium $(filter-out preview,$(PLASMA5)); do \
		cp LICENSE build/$$p/; \
		n=$$(python3 -c "import json,sys; k=json.load(open(sys.argv[1]))['KPlugin']; print(k['Id'] + '-' + k['Version'])" build/$$p/metadata.json); \
		ext=plasmoid; [ $$p = aquarium ] && ext=zip; \
		(cd build/$$p && zip -qr -X ../../dist/$$n.$$ext .); \
	done
	ls -l dist

clean:
	rm -rf build dist
