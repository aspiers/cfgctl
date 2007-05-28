PORTVERSION  = 2.0.17
MASTER_SITES = http://www.namazu.org/stable/
PORTNAME     = namazu-$(PORTVERSION)
TARGZ        = $(PORTNAME).tar.gz
DISTFILES    = $(TARGZ)

include ~/lib/port.mk

do-prep:
	tar -C $(PORT_DIR) -zxf $(TARGZ)
	@[ -n "$(BUILD_DIR)" ]
	rm -rf "$(BUILD_DIR)"
	mv "$(PORT_DIR)/$(PORTNAME)" "$(BUILD_DIR)"
#	mv "$(BUILD_DIR)/$(PORTNAME)" "$(BUILD_DIR)"

