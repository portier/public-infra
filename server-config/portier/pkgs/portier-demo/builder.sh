source $stdenv/setup

tar xvfz "$src"
mv *demo-rp* "$out"

cd "$out"
python -m compileall -f .

mkdir bin
cat > bin/portier-demo << EOF
#!/bin/sh
exec '$python/bin/python' '$out/server.py' \$@
EOF
chmod a+x bin/portier-demo
