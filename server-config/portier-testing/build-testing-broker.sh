export PATH="$coreutils/bin:$gnutar/bin:$gzip/bin:$unzip/bin"

tar xvfz "$src"
mv Portier-Broker-* "$out"

rm "$out/portier-broker"
unzip "$testsrc" -d "$out"
chmod a+x "$out/portier-broker"
