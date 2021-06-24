source $stdenv/setup

tar xvfz "$src"
mv *demo-rp* "$out"

cd "$out"
patchShebangs "$out"
python -m compileall -f .

mkdir bin
ln -s $out/server.py bin/portier-demo
