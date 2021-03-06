/*
 * Copyright (c) 2013, Florian Zeitz <florob@babelmonkeys.de>
 *
 * https://webkeks.org/git/?p=objxmpp.git
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

#import "XMPPDiscoEntity.h"
#import "XMPPDiscoIdentity.h"
#import "XMPPIQ.h"
#import "namespaces.h"

@implementation XMPPDiscoEntity
+ discoEntityWithConnection: (XMPPConnection*)connection
{
	return [[[self alloc] initWithConnection: connection] autorelease];
}

+ discoEntityWithConnection: (XMPPConnection*)connection
		   capsNode: (OFString*)capsNode
{
	return [[[self alloc] initWithConnection: connection
					capsNode: capsNode] autorelease];
}

- initWithConnection: (XMPPConnection*)connection
{
	return [self initWithConnection: connection
			       capsNode: nil];
}

- initWithConnection: (XMPPConnection*)connection
	    capsNode: (OFString*)capsNode
{
	self = [super initWithJID: [connection JID]
			     node: nil];

	@try {
		_discoNodes = [OFMutableDictionary new];
		_connection = connection;
		_capsNode = [capsNode copy];

		[_connection addDelegate: self];
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (void)dealloc
{
	[_connection removeDelegate: self];
	[_discoNodes release];

	[super dealloc];
}

- (OFDictionary*)discoNodes;
{
	OF_GETTER(_discoNodes, YES);
}

- (void)addDiscoNode: (XMPPDiscoNode*)node
{
	[_discoNodes setObject: node
			forKey: [node node]];
}

- (OFString*)capsNode
{
	OF_GETTER(_capsNode, YES);
}

- (OFString*)capsHash
{
	OFMutableString *caps = [OFMutableString string];
	OFEnumerator *enumerator;
	XMPPDiscoIdentity *identity;
	OFString *feature;

	enumerator = [_identities objectEnumerator];
	while ((identity = [enumerator nextObject]) != nil)
		[caps appendFormat: @"%@/%@//%@<", [identity category],
		    [identity type], [identity name]];

	enumerator = [_features objectEnumerator];
	while ((feature = [enumerator nextObject]) != nil)
		[caps appendFormat: @"%@<", feature];

	return [caps SHA1Hash];
}

- (BOOL)connection: (XMPPConnection*)connection
      didReceiveIQ: (XMPPIQ*)IQ
{
	if (![[IQ to] isEqual: _JID])
		return NO;

	OFXMLElement *query = [IQ elementForName: @"query"
				       namespace: XMPP_NS_DISCO_ITEMS];

	if (query != nil) {
		OFString *node =
		    [[query attributeForName: @"node"] stringValue];
		if (node == nil)
			return [self XMPP_handleItemsIQ: IQ
					     connection: connection];

		XMPPDiscoNode *responder = [_discoNodes objectForKey: node];
		if (responder != nil)
			return [responder XMPP_handleItemsIQ: IQ
						  connection: connection];

		return NO;
	}

	query = [IQ elementForName: @"query"
			 namespace: XMPP_NS_DISCO_INFO];

	if (query != nil) {
		OFString *node =
		    [[query attributeForName: @"node"] stringValue];

		if (node == nil)
			return [self XMPP_handleInfoIQ: IQ
					    connection: connection];

		OFString *capsNode = [_capsNode stringByAppendingFormat: @"#%@",
					 [self capsHash]];
		if ([capsNode isEqual: node])
			return [self XMPP_handleInfoIQ: IQ
					    connection: connection];

		XMPPDiscoNode *responder = [_discoNodes objectForKey: node];
		if (responder != nil)
			return [responder XMPP_handleInfoIQ: IQ
						 connection: connection];

		return NO;
	}

	return NO;
}
@end
