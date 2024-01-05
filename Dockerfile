FROM devkitpro/devkitppc:20220821 AS build

COPY patches /build/patches

WORKDIR /build

RUN apt-get update && apt-get install -y genisoimage nodejs build-essential gcc-arm-none-eabi python3-distutils python3-setuptools && \
	curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && python3 get-pip.py && \
	pip3 install -r patches/scripts/requirements.txt

RUN git clone https://github.com/webhdx/PicoBoot.git && \
	cd PicoBoot; env PICO_SDK_FETCH_FROM_GIT=1 cmake .

FROM build AS build2

COPY . /build
COPY --from=build /build/PicoBoot /build

WORKDIR /build

RUN make -C entry clean && \
	make -C entry && \
	git clone -b force-early-boot --single-branch https://github.com/OffBroadway/gc-boot-tools.git && \
	cd gc-boot-tools && \
	make -C ppc/apploader && \
	make -C mkgbi && \
	ls -l mkgbi/gbi.hdr && \
	cd - && \
	mkdir boot-dir && \
	cp cubeboot/cubeboot.dol boot-dir && \
	genisoimage -R -J -G gc-boot-tools/mkgbi/gbi.hdr -no-emul-boot -b cubeboot.dol -o boot.iso boot-dir

RUN cd PicoBoot && ./process_ipl.py ../entry/entry.dol src/ipl.h && make && \
	cd - ; mkdir -p dist/next && \
	mv ./boot.iso dist/next/boot.iso && \
	mv ./cubeboot/cubeboot.dol dist/next/cubeboot.dol && \
	mv ./PicoBoot/picoboot.uf2 dist/next/cubeboot.uf2 && \
	tar -cJf dist-$(git rev-parse --short HEAD).tar.xz dist/next/

FROM devkitpro/devkitppc:20220821 AS dist

COPY --from=build2 /build/dist-*.tar.xz .


