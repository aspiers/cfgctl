PORTVERSION  = svn
MASTER_SITES = 
PORTNAME     = crm114-$(PORTVERSION)
CRMVER	     = $(PORTNAME)-$(CRMNICK)
TARGZ        = $(CRMVER).src.tar.gz
DISTFILES    = $(TARGZ)
NO_CONFIGURE = 1
TRE_PREFIX   = $(HOME)
# Can do it this way too now:
MAKE_INSTALL_OPTIONS = prefix=$(INSTALL_DIR)

include ~/lib/port.mk

do-prep:
	tar zxvf $(TARGZ)
	[ -d "$(BUILD_DIR)" ] && rm -rf $(BUILD_DIR)
	mv $(CRMVER).src $(BUILD_DIR)

post-configure:
	@echo "Tweaking Makefile ..."
	@perl -pi.bak -e 's!^(prefix\??=).*!$$1$(INSTALL_DIR)!; \
		          s!^(LDFLAGS \+= -static)!#$$1!; \
			  s!^(CFLAGS \+= )(.+)!$$1$$2\n$$1 -I$(TRE_PREFIX)/include\nLDFLAGS += -L$(TRE_PREFIX)/lib -Wl,-rpath,$(TRE_PREFIX)/lib!; \
	    ' $(BUILD_DIR)/Makefile

pre-install:
	[ -d "$(INSTALL_DIR)/bin" ] || mkdir "$(INSTALL_DIR)/bin"
