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

#import "XMPPConnection.h"
#import "XMPPIQ.h"
#import "XMPPJID.h"
#import "XMPPDiscoNode.h"
#import "XMPPDiscoIdentity.h"
#import "namespaces.h"

@implementation XMPPDiscoNode
+ discoNodeWithJID: (XMPPJID*)JID
	      node: (OFString*)node;
{
	return [[[self alloc] initWithJID: JID
				     node: node] autorelease];
}


+ discoNodeWithJID: (XMPPJID*)JID
	      node: (OFString*)node
	      name: (OFString*)name
{
	return [[[self alloc] initWithJID: JID
				     node: node
				     name: name] autorelease];
}

- initWithJID: (XMPPJID*)JID
	 node: (OFString*)node
{
	return [self initWithJID: JID
			    node: node
			    name: nil];
}

- initWithJID: (XMPPJID*)JID
	 node: (OFString*)node
	 name: (OFString*)name
{
	self = [super init];

	@try {
		if (JID == nil)
			@throw [OFInvalidArgumentException
			    exceptionWithClass: [self class]
				      selector: _cmd];

		_JID = [JID copy];
		_node= [node copy];
		_name = [name copy];
		_identities = [OFSortedList new];
		_features = [OFSortedList new];
		_childNodes = [OFMutableDictionary new];

		[self addFeature: XMPP_NS_DISCO_ITEMS];
		[self addFeature: XMPP_NS_DISCO_INFO];
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (void)dealloc
{
	[_JID release];
	[_node release];
	[_name release];
	[_identities release];
	[_features release];
	[_childNodes release];

	[super dealloc];
}

- (XMPPJID*)JID
{
	OF_GETTER(_JID, YES);
}

- (OFString*)node
{
	OF_GETTER(_node, YES);
}

- (OFString*)name
{
	OF_GETTER(_name, YES);
}

- (OFSortedList*)identities
{
	OF_GETTER(_identities, YES);
}

- (OFSortedList*)features
{
	OF_GETTER(_features, YES);
}

- (OFDictionary*)childNodes
{
	OF_GETTER(_childNodes, YES);
}

- (void)addIdentity: (XMPPDiscoIdentity*)identity
{
	[_identities insertObject: identity];
}

- (void)addFeature: (OFString*)feature
{
	[_features insertObject: feature];
}

- (void)addChildNode: (XMPPDiscoNode*)node
{
	[_childNodes setObject: node
			forKey: [node node]];
}

- (BOOL)XMPP_handleItemsIQ: (XMPPIQ*)IQ
		connection: (XMPPConnection*)connection
{
	XMPPIQ *resultIQ;
	OFXMLElement *response;
	XMPPDiscoNode *child;
	OFEnumerator *enumerator;
	OFXMLElement *query = [IQ elementForName: @"query"
				       namespace: XMPP_NS_DISCO_ITEMS];
	OFString *node = [[query attributeForName: @"node"] stringValue];

	if (!(node == _node) && ![node isEqual: _node])
		return NO;

	resultIQ = [IQ resultIQ];
	response = [OFXMLElement elementWithName: @"query"
				       namespace: XMPP_NS_DISCO_ITEMS];
	[resultIQ addChild: response];

	enumerator = [_childNodes objectEnumerator];
	while ((child = [enumerator nextObject])) {
		OFXMLElement *item =
		    [OFXMLElement elementWithName: @"item"
					namespace: XMPP_NS_DISCO_ITEMS];

		[item addAttributeWithName: @"jid"
			       stringValue: [[child JID] fullJID]];
		if ([child node] != nil)
			[item addAttributeWithName: @"node"
				       stringValue: [child node]];
		if ([child name] != nil)
			[item addAttributeWithName: @"name"
				       stringValue: [child name]];

		[response addChild: item];
	}

	[connection sendStanza: resultIQ];

	return YES;
}

- (BOOL)XMPP_handleInfoIQ: (XMPPIQ*)IQ
	       connection: (XMPPConnection*)connection
{
	XMPPIQ *resultIQ;
	OFXMLElement *response;
	OFEnumerator *enumerator;
	OFString *feature;
	XMPPDiscoIdentity *identity;

	resultIQ = [IQ resultIQ];
	response = [OFXMLElement elementWithName: @"query"
				       namespace: XMPP_NS_DISCO_INFO];
	[resultIQ addChild: response];

	enumerator = [_identities objectEnumerator];
	while ((identity = [enumerator nextObject])) {
		OFXMLElement *identityElement =
		    [OFXMLElement elementWithName: @"identity"
					namespace: XMPP_NS_DISCO_INFO];

		[identityElement addAttributeWithName: @"category"
					  stringValue: [identity category]];
		[identityElement addAttributeWithName: @"type"
					  stringValue: [identity type]];
		if ([identity name] != nil)
			[identityElement addAttributeWithName: @"name"
						  stringValue: [identity name]];

		[response addChild: identityElement];
	}

	enumerator = [_features objectEnumerator];
	while ((feature = [enumerator nextObject])) {
		OFXMLElement *featureElement =
		    [OFXMLElement elementWithName: @"feature"
					namespace: XMPP_NS_DISCO_INFO];
		[featureElement addAttributeWithName: @"var"
					 stringValue: feature];
		[response addChild: featureElement];
	}

	[connection sendStanza: resultIQ];

	return YES;
}
@end
