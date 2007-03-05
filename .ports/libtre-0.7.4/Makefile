PORTVERSION   	  = 0.7.4
PORTNAME      	  = libtre-$(PORTVERSION)
CRMVER	      	  = crm114-20061103
CRMNICK	      	  = BlameDalkey
CRM_PORT	  = $(PORTS_DIR)/$(CRMVER)
CRM_SRC		  = $(CRM_PORT)/build
TRE_SRC		  = $(CRM_SRC)/tre-$(PORTVERSION)
CONFIGURE_COMMAND = $(TRE_SRC)/configure

include ~/lib/port.mk

pre-prep:
	@$(MAKE) -C $(CRM_PORT) prep

post-prep:
	@if [ -f "$(TRE_SRC)/config.status" ]; then\
		echo "# Need to make distclean in $(TRE_SRC) ..."; \
		cd "$(TRE_SRC)" && \
		automake && \
		./configure && \
		$(MAKE) distclean; \
	fi

pre-configure:
	@if ! [ -f "$(TRE_SRC)/tests/agrep/Makefile.in" ]; then \
		echo "# Looks like a buggy libtre dist - rebuilding missing tests/agrep/Makefile.in..."; \
		cd "$(TRE_SRC)" && automake; \
	fi
