#!/usr/bin/env bash
# Install Apache JMeter 5.6.3 + Plugins Manager + the plugins this assessment uses.
# Usage: ./install_jmeter.sh [install_dir]   (default: ~/tools)
set -euo pipefail
VER=5.6.3
SHA512=5978a1a35edb5a7d428e270564ff49d2b1b257a65e17a759d259a9283fc17093e522fe46f474a043864aea6910683486340706d745fcdf3db1505fd71e689083
DEST=${1:-$HOME/tools}
HOME_DIR="$DEST/apache-jmeter-$VER"
mkdir -p "$DEST"

if [ ! -x "$HOME_DIR/bin/jmeter" ]; then
  echo ">> Downloading JMeter $VER"
  curl -fL -o "$DEST/apache-jmeter-$VER.tgz" "https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-$VER.tgz"
  echo ">> Verifying SHA-512"
  echo "$SHA512  $DEST/apache-jmeter-$VER.tgz" | shasum -a 512 -c -
  tar -xzf "$DEST/apache-jmeter-$VER.tgz" -C "$DEST"
  rm "$DEST/apache-jmeter-$VER.tgz"
fi

echo ">> Plugins Manager + command-line runner"
curl -fsSL -o "$HOME_DIR/lib/ext/jmeter-plugins-manager-1.10.jar" https://repo1.maven.org/maven2/kg/apc/jmeter-plugins-manager/1.10/jmeter-plugins-manager-1.10.jar
curl -fsSL -o "$HOME_DIR/lib/cmdrunner-2.3.jar" https://repo1.maven.org/maven2/kg/apc/cmdrunner/2.3/cmdrunner-2.3.jar
java -cp "$HOME_DIR/lib/ext/jmeter-plugins-manager-1.10.jar" org.jmeterplugins.repository.PluginManagerCMDInstaller

echo ">> Installing plugins: Custom Thread Groups (Concurrency TG) + Dummy Sampler"
"$HOME_DIR/bin/PluginsManagerCMD.sh" install jpgc-casutg,jpgc-dummy

echo ">> Done. Add to your shell:  export PATH=\"$HOME_DIR/bin:\$PATH\""
"$HOME_DIR/bin/jmeter" --version 2>/dev/null | tail -n 3 || true
