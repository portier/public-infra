export PATH="$coreutils/bin:$gnutar/bin:$gzip/bin:$patchelf/bin:$unzip/bin"

tar xvfz "$src"
mv Portier-Broker-* "$out"

rm "$out/portier-broker"
unzip "$testsrc" -d "$out"
chmod a+x "$out/portier-broker"

patchelf \
  --set-interpreter "$glibc/lib/ld-linux-x86-64.so.2" \
  --set-rpath "$openssl/lib" \
  "$out/portier-broker"
