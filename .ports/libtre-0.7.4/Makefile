PORTVERSION=   0.7.4
PORTNAME=      libtre-$(PORTVERSION)
#MASTER_SITES=  ${MASTER_GNU_SITE}/autoconf
#DISTFILES=     ${PORTNAME}-${PORTVERSION}.tar.gz
CRMDIR=${HOME}/roaming/mail/crm114/crm114-20061103-BlameDalkey.src
CONFIGURE_COMMAND=$(CRMDIR)/tre-${PORTVERSION}/configure

include ~/lib/port.mk

prep:
	@[ -d "$(BUILD_DIR)" ] || mkdir -p $(BUILD_DIR)

