export PATH="$coreutils/bin:$gnutar/bin:$gzip/bin:$patchelf/bin"

tar xvfz "$src"
mv Portier-Broker-* "$out"

patchelf \
  --set-interpreter "$glibc/lib/ld-linux-x86-64.so.2" \
  --set-rpath "$openssl/lib" \
  "$out/portier-broker"
