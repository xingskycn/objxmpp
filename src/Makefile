include ../extra.mk

SHARED_LIB = ${OBJXMPP_SHARED_LIB}
STATIC_LIB = ${OBJXMPP_STATIC_LIB}
LIB_MAJOR = 0
LIB_MINOR = 0

SRCS = XMPPAuthenticator.m	\
       XMPPCallback.m		\
       XMPPConnection.m		\
       XMPPContact.m		\
       XMPPContactManager.m	\
       XMPPDiscoEntity.m	\
       XMPPDiscoIdentity.m	\
       XMPPDiscoNode.m		\
       XMPPExceptions.m		\
       XMPPEXTERNALAuth.m	\
       XMPPIQ.m			\
       XMPPJID.m		\
       XMPPFileStorage.m	\
       XMPPMessage.m		\
       XMPPMulticastDelegate.m	\
       XMPPPLAINAuth.m		\
       XMPPPresence.m		\
       XMPPRoster.m		\
       XMPPRosterItem.m		\
       XMPPSCRAMAuth.m		\
       XMPPSRVLookup.m		\
       XMPPStanza.m		\
       XMPPStreamManagement.m	\
       XMPPXMLElementBuilder.m

INCLUDES = ${SRCS:.m=.h}	\
	   namespaces.h		\
	   ObjXMPP.h		\
	   XMPPStorage.h

include ../buildsys.mk

CPPFLAGS += -I.. -DHAVE_CONFIG_H
LD = ${OBJC}
