/*
 * Copyright (c) 2010, 2011, Jonathan Schleifer <js@webkeks.org>
 * Copyright (c) 2011, Florian Zeitz <florob@babelmonkeys.de>
 *
 * https://webkeks.org/hg/objxmpp/
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice is present in all copies.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#define XMPP_CONNECTION_M

#include <assert.h>

#include <stringprep.h>
#include <idna.h>

#import <ObjOpenSSL/SSLSocket.h>

#import "XMPPConnection.h"
#import "XMPPSCRAMAuth.h"
#import "XMPPPLAINAuth.h"
#import "XMPPStanza.h"
#import "XMPPJID.h"
#import "XMPPIQ.h"
#import "XMPPMessage.h"
#import "XMPPPresence.h"
#import "XMPPRoster.h"
#import "XMPPRosterItem.h"
#import "XMPPExceptions.h"

@implementation XMPPConnection
+ connection
{
	return [[[self alloc] init] autorelease];
}

- init
{
	self = [super init];

	@try {
		sock = [[OFTCPSocket alloc] init];
		parser = [[OFXMLParser alloc] init];
		elementBuilder = [[OFXMLElementBuilder alloc] init];

		port = 5222;

		[parser setDelegate: self];
		[elementBuilder setDelegate: self];

		roster = [[XMPPRoster alloc] initWithConnection: self];
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (void)dealloc
{
	[sock release];
	[parser release];
	[elementBuilder release];
	[username release];
	[password release];
	[server release];
	[resource release];
	[JID release];
	[delegate release];
	[authModule release];
	[bindID release];
	[sessionID release];
	[rosterID release];
	[roster release];

	[super dealloc];
}

- (void)setUsername: (OFString*)username_
{
	OFString *old = username;
	char *node;
	Stringprep_rc rc;

	if ((rc = stringprep_profile([username_ cString], &node,
	    "SASLprep", 0)) != STRINGPREP_OK)
		@throw [XMPPStringPrepFailedException newWithClass: isa
							connection: self
							   profile: @"SASLprep"
							    string: username_];

	@try {
		username = [[OFString alloc] initWithCString: node];
	} @finally {
		free(node);
	}

	[old release];
}

- (OFString*)username
{
	return [[username copy] autorelease];
}

- (void)setResource: (OFString*)resource_
{
	OFString *old = resource;
	char *res;
	Stringprep_rc rc;

	if ((rc = stringprep_profile([resource_ cString], &res,
	    "Resourceprep", 0)) != STRINGPREP_OK)
		@throw [XMPPStringPrepFailedException
		    newWithClass: isa
		      connection: self
			 profile: @"Resourceprep"
			  string: resource_];

	@try {
		resource = [[OFString alloc] initWithCString: res];
	} @finally {
		free(res);
	}

	[old release];
}

- (OFString*)resource
{
	return [[resource copy] autorelease];
}

- (void)setServer: (OFString*)server_
{
	OFString *old = server;
	char *srv;
	Idna_rc rc;

	if ((rc = idna_to_ascii_8z([server_ cString],
	    &srv, IDNA_USE_STD3_ASCII_RULES)) != IDNA_SUCCESS)
		@throw [XMPPIDNATranslationFailedException
		    newWithClass: isa
		      connection: self
		       operation: @"ToASCII"
			  string: server_];

	@try {
		server = [[OFString alloc] initWithCString: srv];
	} @finally {
		free(srv);
	}

	[old release];
}

- (OFString*)server
{
	return [[server copy] autorelease];
}

- (void)setPassword: (OFString*)password_
{
	OFString *old = password;
	char *pass;
	Stringprep_rc rc;

	if ((rc = stringprep_profile([password_ cString], &pass,
	    "SASLprep", 0)) != STRINGPREP_OK)
		@throw [XMPPStringPrepFailedException newWithClass: isa
							connection: self
							   profile: @"SASLprep"
							    string: password_];

	@try {
		password = [[OFString alloc] initWithCString: pass];
	} @finally {
		free(pass);
	}

	[old release];
}

- (OFString*)password
{
	return [[password copy] autorelease];
}

- (void)connect
{
	OFAutoreleasePool *pool = [[OFAutoreleasePool alloc] init];

	[sock connectToHost: server
		     onPort: port];
	[self XMPP_startStream];

	[pool release];
}

- (void)handleConnection
{
	char buffer[512];

	for (;;) {
		size_t length = [sock readNBytes: 512
				      intoBuffer: buffer];

		if (length < 1 && [delegate respondsToSelector:
		    @selector(connectionWasClosed:)])
			[delegate connectionWasClosed: self];

		[parser parseBuffer: buffer
			 withLength: length];
	}
}

- (void)parseBuffer: (const char*)buffer
	 withLength: (size_t)length
{
	if (length < 1 && [delegate respondsToSelector:
	    @selector(connectionWasClosed:)])
		[delegate connectionWasClosed: self];

	[parser parseBuffer: buffer
		 withLength: length];
}

- (OFTCPSocket*)socket
{
	return [[sock retain] autorelease];
}

- (void)sendStanza: (OFXMLElement*)element
{
	of_log(@"Out: %@", element);
	[sock writeString: [element XMLString]];
}

- (OFString*)generateStanzaID
{
	return [OFString stringWithFormat: @"objxmpp_%u", lastID++];
}

-    (void)parser: (OFXMLParser*)p
  didStartElement: (OFString*)name
       withPrefix: (OFString*)prefix
	namespace: (OFString*)ns
       attributes: (OFArray*)attrs
{
	OFAutoreleasePool *pool = [[OFAutoreleasePool alloc] init];
	OFEnumerator *enumerator;
	OFXMLAttribute *attr;

	if (![name isEqual: @"stream"] || ![prefix isEqual: @"stream"] ||
	    ![ns isEqual: XMPP_NS_STREAM]) {
		of_log(@"Did not get expected stream start!");
		assert(0);
	}

	enumerator = [attrs objectEnumerator];
	while ((attr = [enumerator nextObject]) != nil) {
		if ([[attr name] isEqual: @"from"] &&
		    ![[attr stringValue] isEqual: server]) {
			of_log(@"Got invalid from in stream start!");
			assert(0);
		}
	}

	[parser setDelegate: elementBuilder];

	[pool release];
}

-    (void)parser: (OFXMLParser*)p
    didEndElement: (OFString*)name
       withPrefix: (OFString*)prefix
	namespace: (OFString*)ns
       attributes: (OFArray*)attrs
{
	if (![name isEqual: @"stream"] || ![prefix isEqual: @"stream"] ||
	    ![ns isEqual: XMPP_NS_STREAM]) {
		of_log(@"Did not get expected stream end!");
		assert(0);
	}
}

- (void)elementBuilder: (OFXMLElementBuilder*)builder
       didBuildElement: (OFXMLElement*)element
{
	OFAutoreleasePool *pool = [[OFAutoreleasePool alloc] init];

	[element setDefaultNamespace: XMPP_NS_CLIENT];
	[element setPrefix: @"stream"
	      forNamespace: XMPP_NS_STREAM];

	of_log(@"In:  %@", element);

	if ([[element namespace] isEqual: XMPP_NS_CLIENT])
		[self XMPP_handleStanza: element];

	if ([[element namespace] isEqual: XMPP_NS_STREAM])
		[self XMPP_handleStream: element];

	if ([[element namespace] isEqual: XMPP_NS_STARTTLS])
		[self XMPP_handleTLS: element];

	if ([[element namespace] isEqual: XMPP_NS_SASL])
		[self XMPP_handleSASL: element];

	[pool release];
}

- (void)XMPP_startStream
{
	[sock writeFormat: @"<?xml version='1.0'?>\n"
			   @"<stream:stream to='%@' "
			   @"xmlns='" XMPP_NS_CLIENT @"' "
			   @"xmlns:stream='" XMPP_NS_STREAM @"' "
			   @"version='1.0'>", server];
}

- (void)XMPP_handleStanza: (OFXMLElement*)element
{
	if ([[element name] isEqual: @"iq"]) {
		[self XMPP_handleIQ: [XMPPIQ stanzaWithElement: element]];
		return;
	}

	if ([[element name] isEqual: @"message"]) {
		[self XMPP_handleMessage:
		    [XMPPMessage stanzaWithElement: element]];
		return;
	}

	if ([[element name] isEqual: @"presence"]) {
		[self XMPP_handlePresence:
		    [XMPPPresence stanzaWithElement: element]];
		return;
	}

	assert(0);
}


- (void)XMPP_handleStream: (OFXMLElement*)element
{
	if ([[element name] isEqual: @"features"]) {
		[self XMPP_handleFeatures: element];
		return;
	}

	if ([[element name] isEqual: @"error"]) {
		OFString *condition, *reason;
		[parser setDelegate: self];
		[sock writeString: @"</stream:stream>"];
		[sock close];

		if ([element elementForName: @"bad-format"
				  namespace: XMPP_NS_XMPP_STREAM])
			condition = @"bad-format";
		else if ([element elementForName: @"bad-namespace-prefix"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"bad-namespace-prefix";
		else if ([element elementForName: @"conflict"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"conflict";
		else if ([element elementForName: @"connection-timeout"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"connection-timeout";
		else if ([element elementForName: @"host-gone"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"host-gone";
		else if ([element elementForName: @"host-unknown"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"host-unknown";
		else if ([element elementForName: @"improper-addressing"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"improper-addressing";
		else if ([element elementForName: @"internal-server-error"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"internal-server-error";
		else if ([element elementForName: @"invalid-from"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"invalid-from";
		else if ([element elementForName: @"invalid-namespace"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"invalid-namespace";
		else if ([element elementForName: @"invalid-xml"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"invalid-xml";
		else if ([element elementForName: @"not-authorized"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"not-authorized";
		else if ([element elementForName: @"not-well-formed"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"not-well-formed";
		else if ([element elementForName: @"policy-violation"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"policy-violation";
		else if ([element elementForName: @"remote-connection-failed"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"remote-connection-failed";
		else if ([element elementForName: @"reset"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"reset";
		else if ([element elementForName: @"resource-constraint"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"resource-constraint";
		else if ([element elementForName: @"restricted-xml"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"restricted-xml";
		else if ([element elementForName: @"see-other-host"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"see-other-host";
		else if ([element elementForName: @"system-shutdown"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"system-shutdown";
		else if ([element elementForName: @"undefined-condition"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"undefined-condition";
		else if ([element elementForName: @"unsupported-encoding"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"unsupported-encoding";
		else if ([element elementForName: @"unsupported-feature"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"unsupported-feature";
		else if ([element elementForName: @"unsupported-stanza-type"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"unsupported-stanza-type";
		else if ([element elementForName: @"unsupported-version"
				       namespace: XMPP_NS_XMPP_STREAM])
			condition = @"unsupported-version";
		else
			condition = @"undefined";

		reason = [[element
		    elementForName: @"text"
			 namespace: XMPP_NS_XMPP_STREAM] stringValue];

		@throw [XMPPStreamErrorException newWithClass: isa
						   connection: self
						    condition: condition
						       reason: reason];
		return;
	}

	assert(0);
}

- (void)XMPP_handleTLS: (OFXMLElement*)element
{
	if ([[element name] isEqual: @"proceed"]) {
		/* FIXME: Catch errors here */
		SSLSocket *newSock;

		if ([delegate respondsToSelector:
		    @selector(connectionWillUpgradeToTLS:)])
			[delegate connectionWillUpgradeToTLS: self];

		newSock = [[SSLSocket alloc] initWithSocket: sock];
		[sock release];
		sock = newSock;

		if ([delegate respondsToSelector:
		    @selector(connectionDidUpgradeToTLS:)])
			[delegate connectionDidUpgradeToTLS: self];

		/* Stream restart */
		[parser setDelegate: self];
		[self XMPP_startStream];
		return;
	}

	if ([[element name] isEqual: @"failure"])
		/* TODO: Find/create an exception to throw here */
		@throw [OFException newWithClass: isa];

	assert(0);
}

- (void)XMPP_handleSASL: (OFXMLElement*)element
{
	if ([[element name] isEqual: @"challenge"]) {
		OFXMLElement *responseTag;
		OFDataArray *challenge = [OFDataArray
		    dataArrayWithBase64EncodedString: [element stringValue]];
		OFDataArray *response = [authModule
		    calculateResponseWithChallenge: challenge];

		responseTag = [OFXMLElement  elementWithName: @"response"
						   namespace: XMPP_NS_SASL];
		[responseTag addChild: [OFXMLElement elementWithCharacters:
		    [response stringByBase64Encoding]]];

		[self sendStanza: responseTag];
		return;
	}

	if ([[element name] isEqual: @"success"]) {
		[authModule parseServerFinalMessage: [OFDataArray
		    dataArrayWithBase64EncodedString: [element stringValue]]];

		if ([delegate respondsToSelector:
		    @selector(connectionWasAuthenticated:)])
			[delegate connectionWasAuthenticated: self];

		/* Stream restart */
		[parser setDelegate: self];
		[self XMPP_startStream];
		return;
	}

	if ([[element name] isEqual: @"failure"]) {
		of_log(@"Auth failed!");
		// FIXME: Do more parsing/handling
		@throw [XMPPAuthFailedException
		    newWithClass: isa
		      connection: self
			  reason: [element XMLString]];
	}

	assert(0);
}

- (void)XMPP_handleIQ: (XMPPIQ*)iq
{
	BOOL handled = NO;

	if ([[iq ID] isEqual: bindID]) {
		[self XMPP_handleResourceBind: iq];
		return;
	}

	if ([[iq ID] isEqual: sessionID]) {
		[self XMPP_handleSession: iq];
		return;
	}

	if ([iq elementForName: @"query"
		     namespace: XMPP_NS_ROSTER]) {
		[self XMPP_handleRoster: iq];
		return;
	}

	if ([delegate respondsToSelector: @selector(connection:didReceiveIQ:)])
		handled = [delegate connection: self
				  didReceiveIQ: iq];

	if (!handled && ![[iq type] isEqual: @"error"]
		     && ![[iq type] isEqual: @"result"]) {
		XMPPJID *from = [iq from];
		XMPPJID *to = [iq to];
		OFXMLElement *error;

		[iq setType: @"error"];
		[iq setTo: from];
		[iq setFrom: to];

		error = [OFXMLElement elementWithName: @"error"];
		[error addAttributeWithName: @"type"
				stringValue: @"cancel"];
		[error addChild:
		    [OFXMLElement elementWithName: @"service-unavailable"
					namespace: XMPP_NS_STANZAS]];
		[iq addChild: error];

		[self sendStanza: iq];
	}
}

- (void)XMPP_handleMessage: (XMPPMessage*)message
{
	if ([delegate respondsToSelector:
	     @selector(connection:didReceiveMessage:)])
		[delegate connection: self
		   didReceiveMessage: message];
}

- (void)XMPP_handlePresence: (XMPPPresence*)presence
{
	if ([delegate respondsToSelector:
	     @selector(connection:didReceivePresence:)])
		[delegate connection: self
		  didReceivePresence: presence];
}

- (void)XMPP_handleFeatures: (OFXMLElement*)element
{
	OFXMLElement *starttls = [element elementForName: @"starttls"
					       namespace: XMPP_NS_STARTTLS];
	OFXMLElement *bind = [element elementForName: @"bind"
					   namespace: XMPP_NS_BIND];
	OFXMLElement *session = [element elementForName: @"session"
					      namespace: XMPP_NS_SESSION];
	OFXMLElement *mechs = [element elementForName: @"mechanisms"
					    namespace: XMPP_NS_SASL];
	OFMutableArray *mechanisms = [OFMutableArray array];

	if (starttls != nil) {
		[self sendStanza:
		    [OFXMLElement elementWithName: @"starttls"
					namespace: XMPP_NS_STARTTLS]];
		return;
	}

	if (mechs != nil) {
		OFEnumerator *enumerator;
		OFXMLElement *mech;

		enumerator = [[mechs children] objectEnumerator];
		while ((mech = [enumerator nextObject]) != nil)
			[mechanisms addObject: [mech stringValue]];

		if ([mechanisms containsObject: @"SCRAM-SHA-1"]) {
			authModule = [[XMPPSCRAMAuth alloc]
			    initWithAuthcid: username
				   password: password
				       hash: [OFSHA1Hash class]];
			[self XMPP_sendAuth: @"SCRAM-SHA-1"];
			return;
		}

		if ([mechanisms containsObject: @"PLAIN"]) {
			authModule = [[XMPPPLAINAuth alloc]
			    initWithAuthcid: username
				   password: password];
			[self XMPP_sendAuth: @"PLAIN"];
			return;
		}

		assert(0);
	}

	if (session != nil)
		needsSession = YES;

	if (bind != nil) {
		[self XMPP_sendResourceBind];
		return;
	}

	assert(0);
}

- (void)XMPP_sendAuth: (OFString*)authName
{
	OFXMLElement *authTag;

	authTag = [OFXMLElement elementWithName: @"auth"
				      namespace: XMPP_NS_SASL];
	[authTag addAttributeWithName: @"mechanism"
			  stringValue: authName];
	[authTag addChild: [OFXMLElement elementWithCharacters:
	    [[authModule clientFirstMessage] stringByBase64Encoding]]];

	[self sendStanza: authTag];
}

- (void)XMPP_sendResourceBind
{
	XMPPIQ *iq;
	OFXMLElement *bind;

	bindID = [[self generateStanzaID] retain];
	iq = [XMPPIQ IQWithType: @"set"
			     ID: bindID];

	bind = [OFXMLElement elementWithName: @"bind"
				   namespace: XMPP_NS_BIND];

	if (resource != nil)
		[bind addChild: [OFXMLElement elementWithName: @"resource"
						  stringValue: resource]];

	[iq addChild: bind];

	[self sendStanza: iq];
}

- (void)XMPP_handleResourceBind: (XMPPIQ*)iq
{
	OFXMLElement *bindElement;
	OFXMLElement *jidElement;

	assert([[iq type] isEqual: @"result"]);

	bindElement = [iq elementForName: @"bind"
			       namespace: XMPP_NS_BIND];

	assert(bindElement != nil);

	jidElement = [bindElement elementForName: @"jid"
				       namespace: XMPP_NS_BIND];
	JID = [[XMPPJID alloc] initWithString: [jidElement stringValue]];

	[bindID release];
	bindID = nil;

	if (needsSession) {
		[self XMPP_sendSession];
		return;
	}

	if ([delegate respondsToSelector: @selector(connection:wasBoundToJID:)])
		[delegate connection: self
		       wasBoundToJID: JID];
}

- (void)XMPP_sendSession
{
	XMPPIQ *iq;

	sessionID = [[self generateStanzaID] retain];
	iq = [XMPPIQ IQWithType: @"set"
			     ID: sessionID];
	[iq addChild: [OFXMLElement elementWithName: @"session"
					  namespace: XMPP_NS_SESSION]];
	[self sendStanza: iq];
}

- (void)XMPP_handleSession: (XMPPIQ*)iq
{
	if (![[iq type] isEqual: @"result"])
		assert(0);

	if ([delegate respondsToSelector: @selector(connection:wasBoundToJID:)])
		[delegate connection: self
		       wasBoundToJID: JID];

	[sessionID release];
	sessionID = nil;
}

- (void)requestRoster
{
	XMPPIQ *iq;

	if (rosterID != nil)
		assert(0);

	rosterID = [[self generateStanzaID] retain];
	iq = [XMPPIQ IQWithType: @"get"
			     ID: rosterID];
	[iq addChild: [OFXMLElement elementWithName: @"query"
					  namespace: XMPP_NS_ROSTER]];
	[self sendStanza: iq];
}

- (void)XMPP_handleRoster: (XMPPIQ*)iq
{
	OFXMLElement *rosterElement;
	OFXMLElement *element;
	XMPPRosterItem *rosterItem = nil;
	OFString *subscription;
	OFEnumerator *enumerator;
	BOOL isPush = ![[iq ID] isEqual: rosterID];

	rosterElement = [iq elementForName: @"query"
				 namespace: XMPP_NS_ROSTER];

	if (isPush)
		assert([[iq type] isEqual: @"set"]);
	else
		assert([[iq type] isEqual: @"result"]);

	enumerator = [[rosterElement children] objectEnumerator];
	while ((element = [enumerator nextObject]) != nil) {
		OFMutableArray *groups = [OFMutableArray array];
		OFEnumerator *groupEnumerator;
		OFXMLElement *groupElement;

		if (![[element name] isEqual: @"item"] ||
		    ![[element namespace] isEqual: XMPP_NS_ROSTER])
			continue;

		rosterItem = [XMPPRosterItem rosterItem];
		[rosterItem setJID: [XMPPJID JIDWithString:
		    [[element attributeForName: @"jid"] stringValue]]];
		[rosterItem setName:
		    [[element attributeForName: @"name"] stringValue]];

		subscription = [[element attributeForName:
		    @"subscription"] stringValue];

		if (![subscription isEqual: @"none"] &&
		    ![subscription isEqual: @"to"] &&
		    ![subscription isEqual: @"from"] &&
		    ![subscription isEqual: @"both"] &&
		    (![subscription isEqual: @"remove"] || !isPush))
			subscription = @"none";

		[rosterItem setSubscription: subscription];

		groupEnumerator = [[element
		    elementsForName: @"group"
			  namespace: XMPP_NS_ROSTER] objectEnumerator];
		while ((groupElement = [groupEnumerator nextObject]) != nil)
			[groups addObject: [groupElement stringValue]];

		if ([groups count] > 0)
			[rosterItem setGroups: groups];

		if ([subscription isEqual: @"remove"])
			[roster XMPP_deleteRosterItem: rosterItem];
		else
			[roster XMPP_addRosterItem: rosterItem];

		if (isPush && [delegate respondsToSelector:
		    @selector(connection:didReceiveRosterItem:)])
			[delegate connection:self
			didReceiveRosterItem: rosterItem];
	}

	if (isPush) {
		XMPPIQ *response = [XMPPIQ IQWithType: @"result"
						   ID: [iq ID]];
		[response setTo: [iq from]];
		[self sendStanza: response];
	} else {
		if ([delegate respondsToSelector:
		    @selector(connectionDidReceiveRoster:)])
			[delegate connectionDidReceiveRoster: self];

		[rosterID release];
		rosterID = nil;
	}
}

- (XMPPJID*)JID
{
	return [[JID copy] autorelease];
}

- (void)setPort: (uint16_t)port_
{
	port = port_;
}

- (uint16_t)port
{
	return port;
}

- (void)setDelegate: (id <XMPPConnectionDelegate>)delegate_
{
	id old = delegate;
	delegate = [(id)delegate_ retain];
	[old release];
}

- (id <XMPPConnectionDelegate>)delegate
{
	return [[delegate retain] autorelease];
}

- (XMPPRoster*)roster
{
	return [[roster retain] autorelease];
}
@end

@implementation OFObject (XMPPConnectionDelegate)
- (void)connectionWasAuthenticated: (XMPPConnection*)connection
{
}

- (void)connection: (XMPPConnection*)connection
     wasBoundToJID: (XMPPJID*)JID
{
}

- (void)connectionDidReceiveRoster: (XMPPConnection*)connection
{
}

- (BOOL)connection: (XMPPConnection*)connection
      didReceiveIQ: (XMPPIQ*)iq
{
	return NO;
}

-   (void)connection: (XMPPConnection*)connection
  didReceivePresence: (XMPPPresence*)presence
{
}

-  (void)connection: (XMPPConnection*)connection
  didReceiveMessage: (XMPPMessage*)message
{
}

-     (void)connection: (XMPPConnection*)connection
  didReceiveRosterItem: (XMPPRosterItem*)rosterItem
{
}

- (void)connectionWasClosed: (XMPPConnection*)connection
{
}

- (void)connectionWillUpgradeToTLS: (XMPPConnection*)connection
{
}

- (void)connectionDidUpgradeToTLS: (XMPPConnection*)connection
{
}
@end
