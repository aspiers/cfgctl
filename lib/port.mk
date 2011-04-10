#  Copyright (C) 2002 Larry Owen
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

# Different types of targets:
#  - stage rules as defined in $(STAGES)
#    + Determine dependency chain between stages - each stage depends
#      on previous stage.
#    + Can be overridden to change dependency chain (remove links).
#    + Can mostly be left alone.
#
#  - $(status)/<stage>
#    + Does the meat of the work for the stage
#    + Determines dependencies except for on other stages
#    + Expected to be overridden by copying from this file
#    + Can depend on "function targets" (see below)
#
#  - Function targets act as helpers to perform common tasks
#    + e.g. wget for downloading sources via wget
#    + take parameters via variables
#    + call like this:
#         target: param1=myvalue
#         target: helper
#
# N.B. No pre/body/post stage targets acting as "hooks" for
# inheritance/overriding - they can be implemented with normal
# dependencies via 
#   foo : pre body post
# I tried them before and they just cluttered up this file.

include ~/etc/ports.conf

# Define a unique namespace for inheritance
PKG=portmk

# Enable inheritance and overriding of $(PKG)-* targets.
# If target 'foo' is defined in a rule in the port, it will use that.
# Otherwise it will use $(PKG)-foo if it's defined in this file.
% :: $(PKG)-*
# This command is required since it's a "match anything" rule:
	@# echo "(inherited $@ from port.mk)"

STAGES = setup download prep patch configure build install package
.PHONY: $(addprefix $(PKG)-,$(STAGES))
.PHONY: $(addprefix $(PKG)-clean-,$(STAGES)) clean
.PHONY: $(addprefix $(PKG)-force-,$(STAGES))

.PHONY: $(PKG)-all force-all
default all: install
force-all: clean all

$(PKG)-setup:
	@mkdir -p $(status)

#######################################################
#                Download targets                     #
#######################################################
force-download: clean-download download
clean-download:
	@rm $(DISTFILES) $(PATCHFILES)

download: setup $(status)/download

$(status)/download: $(DISTFILES) $(PATCHFILES)
	@touch $@

$(DISTFILES) $(PATCHFILES): wget_file=$@
$(DISTFILES) $(PATCHFILES): wget

wget:
	@for k in ${MASTER_SITES}; do \
		echo -n "===> Downloading $(wget_file) from $$k ... "; \
		wget -P ./ $${k%/}/$(wget_file); \
		if [ -f $(wget_file) ]; then \
			echo "Success"; \
			break; \
		else \
			echo "Failed, trying next site."; \
		fi; \
	done; 
	@if [ -f $(wget_file) ]; then :; else \
		echo "Sorry, unable to download $(wget_file)."; \
	fi; 


#######################################################
#                 Prepare targets                     #
#######################################################
force-prep: clean-prep prep
clean-prep:
	@rm -f $(status)/prep

prep: download prep-message $(status)/prep 

prep-message:
	@echo "===> Preparing ${PORTNAME}"

$(status)/prep: create-build-dir
	@touch $@

create-build-dir:
	@[ -d "$(BUILD_DIR)" ] || mkdir -p "$(BUILD_DIR)"

#######################################################
#                  Patch targets                      #
#######################################################
force-patch: clean-patch patch
clean-patch:
	@rm -f $(status)/patch

patch: prep patch-message $(status)/patch

patch-message:
	@echo "===>  Patching ${PORTNAME}"

$(status)/patch:
	@for i in $(patsubst %.bz2,%,${PATCHFILES}); do \
		cd ${BUILD_DIR} && patch ${PATCH_OPTIONS} ../$$i; \
	done
	@touch $@

#######################################################
#               Configure targets                     #
#######################################################
force-configure: clean-configure configure
clean-configure:
	@rm -f $(status)/configure

configure: patch $(status)/configure

$(status)/configure:
	@$(MAKE) configure-message pre-configure do-configure post-configure
	@touch $@

configure-message:
	@echo "===>  Configuring ${PORTNAME}"

ifndef NO_CONFIGURE
do-configure: 
	cd ${BUILD_DIR} && ${CONFIGURE_COMMAND} ${CONFIGURE_OPTIONS} ${CONFIGURE_FLAGS}
endif

#######################################################
#                 Build targets                       #
#######################################################
force-build:
	@rm -f $(status)/build
	@$(MAKE) build

build: configure $(status)/build

$(status)/build:
	@$(MAKE) build-message pre-build do-build post-build
	@touch $@

build-message:
	@echo "===>  Building ${PORTNAME}"

ifndef NO_BUILD
do-build:
	@cd ${BUILD_DIR} && $(MAKE) ${MAKE_OPTIONS} ${MAKE_FLAGS}
endif

#######################################################
#               Install targets                       #
#######################################################
force-install: uninstall install

install: build $(status)/install

$(status)/install:
	@$(MAKE) install-message check-installed pre-install do-install post-install
	@touch $@

install-message:
	@echo "===>  Installing ${PORTNAME}"

pre-install:
	@[ -d "$(INSTALL_DIR)" ] || mkdir -p "$(INSTALL_DIR)"

ifndef NO_INSTALL
do-install: 
	@cd ${BUILD_DIR} && $(MAKE) ${MAKE_INSTALL_OPTIONS} ${INSTALL_FLAGS}
endif

#######################################################
#                 Clean Targets                       #
#######################################################
clean-ports:
ifndef NO_CLEAN
	@rm -rf *.tar
endif

clean-tarball:
ifndef NO_CLEAN
	@rm -rf ${DISTFILES} ${PATCHFILES} 2> /dev/null
endif

clean-status:
	@rm -rf status

clean-source: clean-status
ifndef NO_CLEAN
	@rm -rf ${BUILD_DIR}
endif

clean-install:
	@rm -rf $(INSTALL_DIR)

clean: clean-status
	@if [ -d ${BUILD_DIR} ]; then \
	    cd ${BUILD_DIR} && \
		$(MAKE) clean; \
	fi

real-clean: clean-ports clean-tarball clean-source clean-install clean
distclean: real-clean

#######################################################
#                 Other Targets                       #
#######################################################
versions:
	@rm -f .listing && echo " " && \
	  echo "This port works with ${PORTNAME}-${PORTVERSION}." && \
	  echo " " && \
	  @for k in ${MASTER_SITES}; do \
		  echo "===> Versions at $$k are:"; \
          wget -q -nr $$k/bogusname*; \
          cat .listing; \
	      echo " " && rm -f .listing;\
      done;

check-installed:

uninstall: FIXME

# There are a whole load more show-* targets included from ports.conf above.
show-distfiles:
	@echo "$(DISTFILES)"
