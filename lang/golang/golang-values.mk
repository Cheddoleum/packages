#
# Copyright (C) 2018, 2020 Jeffery To
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

ifeq ($(origin GO_INCLUDE_DIR),undefined)
  GO_INCLUDE_DIR:=$(dir $(lastword $(MAKEFILE_LIST)))
endif

include $(GO_INCLUDE_DIR)/golang-version.mk


# Unset environment variables
# There are more magic variables to track down, but ain't nobody got time for that

# From https://golang.org/cmd/go/#hdr-Environment_variables

# General-purpose environment variables:
unexport \
  GCCGO \
  GOARCH \
  GOBIN \
  GOCACHE \
  GODEBUG \
  GOENV \
  GOFLAGS \
  GOOS \
  GOPATH \
  GOROOT \
  GOTMPDIR
# Unmodified:
#   GOPRIVATE
#   GOPROXY
#   GONOPROXY
#   GOSUMDB
#   GONOSUMDB

# Environment variables for use with cgo:
unexport \
  AR \
  CC \
  CGO_ENABLED \
  CGO_CFLAGS   CGO_CFLAGS_ALLOW   CGO_CFLAGS_DISALLOW \
  CGO_CPPFLAGS CGO_CPPFLAGS_ALLOW CGO_CPPFLAGS_DISALLOW \
  CGO_CXXFLAGS CGO_CXXFLAGS_ALLOW CGO_CXXFLAGS_DISALLOW \
  CGO_FFLAGS   CGO_FFLAGS_ALLOW   CGO_FFLAGS_DISALLOW \
  CGO_LDFLAGS  CGO_LDFLAGS_ALLOW  CGO_LDFLAGS_DISALLOW \
  CXX \
  FC
# Unmodified:
#   PKG_CONFIG

# Architecture-specific environment variables:
unexport \
  GOARM \
  GO386 \
  GOMIPS \
  GOMIPS64 \
  GOWASM

# Special-purpose environment variables:
unexport \
  GCCGOTOOLDIR \
  GOROOT_FINAL \
  GO_EXTLINK_ENABLED
# Unmodified:
#   GIT_ALLOW_PROTOCOL

# From https://golang.org/cmd/go/#hdr-Module_support
unexport \
  GO111MODULE

# From https://golang.org/pkg/runtime/#hdr-Environment_Variables
unexport \
  GOGC \
  GOMAXPROCS \
  GORACE \
  GOTRACEBACK

# From https://golang.org/cmd/cgo/#hdr-Using_cgo_with_the_go_command
unexport \
  CC_FOR_TARGET \
  CXX_FOR_TARGET
# Todo:
#   CC_FOR_${GOOS}_${GOARCH}
#   CXX_FOR_${GOOS}_${GOARCH}

# From https://golang.org/doc/install/source#environment
unexport \
  GOHOSTOS \
  GOHOSTARCH \
  GOPPC64

# From https://golang.org/src/make.bash
unexport \
  GO_GCFLAGS \
  GO_LDFLAGS \
  GO_LDSO \
  GO_DISTFLAGS \
  GOBUILDTIMELOGFILE \
  GOROOT_BOOTSTRAP

# From https://golang.org/doc/go1.9#parallel-compile
unexport \
  GO19CONCURRENTCOMPILATION

# From https://golang.org/src/cmd/dist/build.go
unexport \
  BOOT_GO_GCFLAGS \
  BOOT_GO_LDFLAGS

# From https://golang.org/src/cmd/dist/buildtool.go
unexport \
  GOBOOTSTRAP_TOOLEXEC

# From https://golang.org/src/cmd/internal/objabi/util.go
unexport \
  GOEXPERIMENT


# GOOS / GOARCH

go_arch=$(subst \
  aarch64,arm64,$(subst \
  i386,386,$(subst \
  mipsel,mipsle,$(subst \
  mips64el,mips64le,$(subst \
  powerpc64,ppc64,$(subst \
  x86_64,amd64,$(1)))))))

GO_OS:=linux
GO_ARCH:=$(call go_arch,$(ARCH))
GO_OS_ARCH:=$(GO_OS)_$(GO_ARCH)

GO_HOST_OS:=$(call tolower,$(HOST_OS))
GO_HOST_ARCH:=$(call go_arch,$(subst \
  armv6l,arm,$(subst \
  armv7l,arm,$(subst \
  i686,i386,$(HOST_ARCH)))))
GO_HOST_OS_ARCH:=$(GO_HOST_OS)_$(GO_HOST_ARCH)

ifeq ($(GO_OS_ARCH),$(GO_HOST_OS_ARCH))
  GO_HOST_TARGET_SAME:=1
else
  GO_HOST_TARGET_DIFFERENT:=1
endif

ifeq ($(GO_ARCH),386)
  # ensure binaries can run on older CPUs
  GO_386:=387

  # -fno-plt: causes "unexpected GOT reloc for non-dynamic symbol" errors
  GO_CFLAGS_TO_REMOVE:=-fno-plt

else ifeq ($(GO_ARCH),arm)
  GO_TARGET_FPU:=$(word 2,$(subst +,$(space),$(call qstrip,$(CONFIG_CPU_TYPE))))

  # FPU names from https://gcc.gnu.org/onlinedocs/gcc-8.3.0/gcc/ARM-Options.html#index-mfpu-1
  # see also https://github.com/gcc-mirror/gcc/blob/gcc-8_3_0-release/gcc/config/arm/arm-cpus.in
  #
  # Assumptions:
  #
  # * -d16 variants (16 instead of 32 double-precision registers) acceptable
  #   Go doesn't appear to check the HWCAP_VFPv3D16 flag in
  #   https://github.com/golang/go/blob/release-branch.go1.13/src/runtime/os_linux_arm.go
  #
  # * Double-precision required
  #   Based on no evidence(!)
  #   Excludes vfpv3xd, vfpv3xd-fp16, fpv4-sp-d16, fpv5-sp-d16

  GO_ARM_7_FPUS:= \
    vfpv3 vfpv3-fp16 vfpv3-d16 vfpv3-d16-fp16 neon neon-vfpv3 neon-fp16 \
    vfpv4 vfpv4-d16 neon-vfpv4 \
    fpv5-d16 fp-armv8 neon-fp-armv8 crypto-neon-fp-armv8

  GO_ARM_6_FPUS:=vfp vfpv2

  ifneq ($(filter $(GO_TARGET_FPU),$(GO_ARM_7_FPUS)),)
    GO_ARM:=7
  else ifneq ($(filter $(GO_TARGET_FPU),$(GO_ARM_6_FPUS)),)
    GO_ARM:=6
  else
    GO_ARM:=5
  endif

else ifneq ($(filter $(GO_ARCH),mips mipsle),)
  ifeq ($(CONFIG_HAS_FPU),y)
    GO_MIPS:=hardfloat
  else
    GO_MIPS:=softfloat
  endif

  # -mips32r2: conflicts with -march=mips32 set by go
  GO_CFLAGS_TO_REMOVE:=-mips32r2

else ifneq ($(filter $(GO_ARCH),mips64 mips64le),)
  ifeq ($(CONFIG_HAS_FPU),y)
    GO_MIPS64:=hardfloat
  else
    GO_MIPS64:=softfloat
  endif

endif


# Target Go

GO_ARCH_DEPENDS:=@(aarch64||arm||i386||i686||mips||mips64||mips64el||mipsel||powerpc64||x86_64)

GO_TARGET_PREFIX:=/usr
GO_TARGET_VERSION_ID:=$(GO_VERSION_MAJOR_MINOR)
GO_TARGET_ROOT:=$(GO_TARGET_PREFIX)/lib/go-$(GO_TARGET_VERSION_ID)


# ASLR/PIE

GO_PIE_SUPPORTED_OS_ARCH:= \
  android_386 android_amd64 android_arm android_arm64 \
  linux_386   linux_amd64   linux_arm   linux_arm64 \
  \
  darwin_amd64 \
  freebsd_amd64 \
  \
  aix_ppc64 \
  \
  linux_ppc64le linux_s390x

go_pie_install_suffix=$(if $(filter $(1),aix_ppc64),,shared)

ifneq ($(filter $(GO_HOST_OS_ARCH),$(GO_PIE_SUPPORTED_OS_ARCH)),)
  GO_HOST_PIE_SUPPORTED:=1
  GO_HOST_PIE_INSTALL_SUFFIX:=$(call go_pie_install_suffix,$(GO_HOST_OS_ARCH))
endif

ifneq ($(filter $(GO_OS_ARCH),$(GO_PIE_SUPPORTED_OS_ARCH)),)
  GO_TARGET_PIE_SUPPORTED:=1
  GO_TARGET_PIE_INSTALL_SUFFIX:=$(call go_pie_install_suffix,$(GO_OS_ARCH))
endif
