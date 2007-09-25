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

include ~/etc/ports.conf

default: install
all: download prep patch configure build install
force-all: clean-status all

setup:
	@mkdir -p $(status)

#######################################################
#          Empty pre-* and post-* targets             #
#######################################################
STAGES = pre post
NAMES = download prep patch configure build install package clean

ALL_TARGETS = $(foreach stage,$(STAGES),$(addprefix $(stage)-,$(NAMES)))

.PHONY: $(ALL_TARGETS) $(addprefix do-,$(NAMES))


#######################################################
#                Download targets                     #
#######################################################
force-download: 
	@echo $(DISTFILES) $(PATCHFILES) | xargs -r rm
	@$(MAKE) download

download: setup pre-download $(DISTFILES) $(PATCHFILES) post-download

$(DISTFILES) $(PATCHFILES):
	@for k in ${MASTER_SITES}; do \
		echo -n "===> Downloading $@ from $$k ... "; \
		wget -P ./ ${WGET_OPTIONS} $$k/$@; \
		if [ -f $@ ]; then \
			echo "Success"; \
			break; \
		else \
			echo "Failed, trying next site."; \
		fi; \
	done; 
	@if [ -f $@ ]; then :; else \
		echo "Sorry, unable to download $@."; \
	fi; 


#######################################################
#                 Prepare targets                     #
#######################################################
force-prep:
	@rm $(status)/prep
	@$(MAKE) prep

prep: download $(status)/prep 

$(status)/prep: 
	@$(MAKE) prep-message checksums pre-prep do-prep post-prep
	@touch $(status)/prep

pre-prep:
	@[ -d "$(BUILD_DIR)" ] || mkdir -p "$(BUILD_DIR)"

prep-message:
	@echo "===> Preparing ${PORTNAME}"

#######################################################
#                  Patch targets                      #
#######################################################
force-patch:
	@rm $(status)/patch
	@$(MAKE) patch

patch: prep $(status)/patch

$(status)/patch:
	@$(MAKE) patch-message pre-patch do-patch post-patch
	@touch $(status)/patch

patch-message:
	@echo "===>  Patching ${PORTNAME}"

ifndef NO_PATCH
do-patch: 
	@for i in $(patsubst %.bz2,%,${PATCHFILES}); do \
		cd ${BUILD_DIR} && patch ${PATCH_OPTIONS} ../$$i; \
	done
endif

#######################################################
#               Configure targets                     #
#######################################################
force-configure:
	@-rm $(status)/configure
	@$(MAKE) configure

configure: patch $(status)/configure

$(status)/configure:
	@$(MAKE) configure-message pre-configure do-configure post-configure
	@touch $(status)/configure

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
	@rm $(status)/build
	@$(MAKE) build

build: configure $(status)/build

$(status)/build:
	@$(MAKE) build-message pre-build do-build post-build
	@touch $(status)/build

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
	@touch $(status)/install

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

checksums:
ifndef NO_CLEAN
	@-md5sum --check md5
endif

md5: download
	@echo -n "" > md5
	@for k in ${DISTFILES} ${PATCHFILES}; do \
		md5sum -b $$k >> md5;\
	done

uninstall: FIXME

# There are a whole load more show-* targets included from ports.conf above.
show-distfiles:
	@echo "$(DISTFILES)"
