echo $ARCH
if [ "$ARCH" = "AARCH64" ]
then
  docker run --rm --privileged multiarch/qemu-user-static:register --reset
  docker build -t asdf-arm64 . -f Dockerfile.aarch64
else
  echo $ARCH
  dub test --arch=$ARCH --build=unittest$CONF
  cd benchmarks/sajson ; dub --build=release-nobounds --compiler=ldmd2 ; cd ../..
fi
